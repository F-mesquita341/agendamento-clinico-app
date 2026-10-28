import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_dispositivos.dart';
import '../../data/services/servico_de_notificacoes.dart';
import '../../domain/models/erro_da_api.dart';
import '../comum/defeitos.dart';
import '../sessao/sessao_view_model.dart';

/// Os lembretes, do ponto de vista de quem está com a conta aberta.
enum EstadoDosLembretes {
  /// Ainda não se sabe: a permissão e o registro estão sendo conferidos.
  conferindo,

  /// O sistema não deixa o aplicativo mostrar notificações.
  desativados,

  /// A pessoa pediu para ativar, e o pedido está no ar.
  ativando,

  /// Permitidos, e o aparelho registrado na API nesta sessão.
  ativados,

  /// Permitidos, mas o registro falhou — sem rede, servidor acordando, sem o
  /// Google Play. O aplicativo tenta de novo na volta e na próxima abertura.
  falhou,
}

/// Como terminou o pedido de ativar os lembretes.
enum ResultadoDaAtivacao { ativados, negada, falhou }

/// A tela que explica o lembrete antes da pergunta do sistema (checklist,
/// item 10.5), logo depois do cadastro.
enum ExplicacaoDosLembretes {
  nenhuma,

  /// O cadastro acabou, e a permissão ainda não foi lida: o portão espera,
  /// em vez de mostrar o aplicativo e trocá-lo pela explicação um instante
  /// depois.
  decidindo,
  mostrar,
}

/// O aparelho registrado nesta sessão: de quem é, com que token e o id na API.
typedef _Registro = ({String uid, String token, int id});

/// Os lembretes de consulta: a permissão do sistema, o registro do aparelho
/// na API e os lembretes que chegam.
///
/// A fonte da verdade é a permissão do sistema, junto com a API: nada é
/// guardado no aparelho. O registro é idempotente pelo token, e por isso é
/// refeito a cada abertura — é assim que o id volta depois que o aplicativo
/// fecha.
///
/// Toda operação com o aparelho passa por uma fila, uma de cada vez. Sem ela,
/// a pergunta do sistema, que pausa o aplicativo, faria a volta e o "ativar"
/// registrarem juntos; e um token apagado poderia se misturar com o pedido do
/// token seguinte.
class LembretesViewModel extends ChangeNotifier {
  LembretesViewModel({
    required ServicoDeNotificacoes notificacoes,
    required RepositorioDeDispositivos dispositivos,
    required SessaoViewModel sessao,
    this.tetoDaSaida = const Duration(seconds: 15),
  })  : _notificacoes = notificacoes,
        _dispositivos = dispositivos,
        _sessao = sessao;

  final ServicoDeNotificacoes _notificacoes;
  final RepositorioDeDispositivos _dispositivos;
  final SessaoViewModel _sessao;

  /// Quanto "Sair da conta" espera pela revogação do aparelho. Passado o teto,
  /// a pessoa sai mesmo assim: o token é apagado no aparelho, e a API apaga o
  /// registro na próxima tentativa de envio.
  final Duration tetoDaSaida;

  EstadoDosLembretes _estado = EstadoDosLembretes.conferindo;
  bool? _permitidas;
  _Registro? _registro;
  ExplicacaoDosLembretes _explicacao = ExplicacaoDosLembretes.nenhuma;

  /// Se o token já foi apagado neste processo, sem nenhum pedido de token
  /// depois: apagar de novo só gastaria rede.
  bool _tokenApagado = false;

  Future<void> _fila = Future.value();

  /// O estado e a conta da última mudança da sessão vista: só as transições
  /// contam. O perfil atualizado, o aviso de servidor demorando e o "Saindo…"
  /// também avisam, e cada aviso leria de novo a permissão e o token. O
  /// registro em si não se repete: o mesmo token na mesma conta não vai de novo
  /// à API.
  EstadoDaSessao? _estadoVisto;
  String? _uidVisto;

  LembreteRecebido? _toquePendente;
  final _mensagensAbertas = <String>{};
  StreamSubscription<LembreteRecebido>? _tocados;
  bool _descartado = false;

  EstadoDosLembretes get estado => _estado;

  /// Se o sistema deixa o aplicativo mostrar notificações; null enquanto não
  /// se sabe.
  bool? get permitidas => _permitidas;

  ExplicacaoDosLembretes get explicacao => _explicacao;

  /// O último lembrete tocado, à espera do aplicativo com a conta aberta.
  LembreteRecebido? get toquePendente => _toquePendente;

  /// Os lembretes que chegam com o aplicativo aberto. Quem não está ouvindo
  /// na hora não os recebe.
  Stream<LembreteRecebido> get recebidosComOAppAberto => _notificacoes.lembretesComOAppAberto;

  void iniciar() {
    _sessao.addListener(_aoMudarSessao);
    _tocados = _notificacoes.lembretesTocados.listen(
      _aoTocar,
      onError: (Object erro, StackTrace pilha) => relatarDefeito(erro, pilha, 'nos toques dos lembretes'),
    );
    // Uma vez por processo: o FCM guarda também o último toque com o
    // aplicativo em segundo plano como "mensagem inicial", e o devolveria de
    // novo a quem perguntasse depois.
    unawaited(_lerToqueInicial());
    // A permissão é lida já: quando o cadastro acabar, a explicação decide
    // sem esperar.
    unawaited(_naFila(() async {
      await _lerPermissao();
      _decidirExplicacao();
    }));
    _aoMudarSessao();
  }

  void _aoMudarSessao() {
    final estado = _sessao.estado;
    final uid = _sessao.usuario?.uid;
    final anterior = _estadoVisto;
    if (estado == anterior && uid == _uidVisto) return;
    _estadoVisto = estado;
    _uidVisto = uid;

    switch (estado) {
      case EstadoDaSessao.comPerfil when uid != null:
        if (anterior == EstadoDaSessao.semPerfil) {
          _explicacao = ExplicacaoDosLembretes.decidindo;
          _decidirExplicacao();
          _notificar();
        }
        unawaited(_naFila(() => _sincronizar(uid)));
      case EstadoDaSessao.semSessao:
        // Sem DELETE: depois de "Sair da conta", ele já foi feito antes; numa
        // sessão perdida, o token da conta já não vale. O token do aparelho é
        // apagado — e, se a limpeza da última saída falhou, é refeita aqui,
        // na abertura seguinte.
        _registro = null;
        _explicacao = ExplicacaoDosLembretes.nenhuma;
        _estado = EstadoDosLembretes.conferindo;
        unawaited(_naFila(_apagarToken));
        _notificar();
      default:
        break;
    }
  }

  /// A explicação aparece só se a permissão ainda não foi dada. A decisão é
  /// tomada uma vez: a tela, uma vez aberta, só sai quando termina — se lesse
  /// a permissão ao vivo, sumiria no instante do "Permitir", antes do registro.
  void _decidirExplicacao() {
    final permitidas = _permitidas;
    if (_explicacao != ExplicacaoDosLembretes.decidindo || permitidas == null) return;
    _explicacao = permitidas ? ExplicacaoDosLembretes.nenhuma : ExplicacaoDosLembretes.mostrar;
    _notificar();
  }

  /// A tela da explicação terminou: o aplicativo aparece.
  void explicacaoConcluida() {
    _explicacao = ExplicacaoDosLembretes.nenhuma;
    _notificar();
  }

  /// Pede a permissão do sistema e, se ela vier, registra o aparelho.
  Future<ResultadoDaAtivacao> ativar() {
    _mudar(EstadoDosLembretes.ativando);
    return _naFila(() async {
      final uid = _uidComPerfil;
      if (uid == null) {
        _mudar(EstadoDosLembretes.conferindo);
        return ResultadoDaAtivacao.falhou;
      }
      bool permitidas;
      try {
        permitidas = await _notificacoes.pedirPermissao();
      } on FalhaDasNotificacoes {
        permitidas = false;
      }
      _permitidas = permitidas;
      if (!permitidas) {
        _mudar(EstadoDosLembretes.desativados);
        return ResultadoDaAtivacao.negada;
      }
      return await _registrar(uid) ? ResultadoDaAtivacao.ativados : ResultadoDaAtivacao.falhou;
    });
  }

  /// Depois de uma falha no registro: confere de novo.
  void tentarDeNovo() {
    final uid = _uidComPerfil;
    if (uid == null) return;
    _mudar(EstadoDosLembretes.ativando);
    unawaited(_naFila(() => _sincronizar(uid)));
  }

  /// O aplicativo voltou para a frente: a pessoa pode ter mudado a permissão
  /// nas configurações, ou acabado de responder à pergunta do sistema.
  void aoVoltarAoAplicativo() {
    final uid = _uidComPerfil;
    if (uid == null) return;
    unawaited(_naFila(() => _sincronizar(uid)));
  }

  /// Chamado por "Sair da conta" antes de sair do provedor, enquanto o token
  /// da conta ainda vale: o aparelho sai dos lembretes, como o termo promete.
  /// Espera a fila — um registro no ar termina, e o id passa a ser conhecido —
  /// e faz o DELETE, tudo dentro do [tetoDaSaida]. Nunca lança.
  Future<void> antesDeSair() async {
    final revogacao = _naFila(() async {
      final registro = _registro;
      _registro = null;
      if (registro != null) await _revogar(registro.id);
    });
    await revogacao.timeout(tetoDaSaida, onTimeout: () {});
    // O token também sai do aparelho, sem segurar a saída: o que estiver no ar
    // ou passar do teto fica sem destino.
    unawaited(_naFila(_apagarToken));
  }

  /// Entrega o toque pendente a quem vai abrir a consulta, uma vez só.
  LembreteRecebido? consumirToque() {
    final toque = _toquePendente;
    _toquePendente = null;
    return toque;
  }

  /// O aparelho, de acordo com a permissão: registrado, se ela foi dada; fora
  /// da API, se não foi.
  Future<void> _sincronizar(String uid) async {
    final permitidas = await _lerPermissao();
    if (!_aindaE(uid)) return;
    if (permitidas) {
      await _registrar(uid);
      return;
    }
    // Sem a permissão, o identificador não fica na API (termo, v2): quem
    // revogou nas configurações, com o aplicativo aberto ou fechado.
    final registro = _registro;
    _registro = null;
    if (registro != null) await _revogar(registro.id);
    await _apagarToken();
    _mudar(EstadoDosLembretes.desativados);
  }

  /// Registra o aparelho, a menos que ele já esteja registrado nesta sessão
  /// com o mesmo token. Devolve se os lembretes ficaram ativados.
  Future<bool> _registrar(String uid) async {
    try {
      final token = await _notificacoes.token();
      _tokenApagado = false;
      if (!_aindaE(uid)) return false;
      final registro = _registro;
      if (registro != null && registro.uid == uid && registro.token == token) {
        _mudar(EstadoDosLembretes.ativados);
        return true;
      }
      final id = await _dispositivos.registrar(token);
      // A resposta de uma conta que já saiu é descartada: o id é dela, e não
      // de quem está com o aplicativo agora.
      if (!_aindaE(uid)) return false;
      _registro = (uid: uid, token: token, id: id);
      _mudar(EstadoDosLembretes.ativados);
      return true;
    } on ErroDaApi {
      if (_aindaE(uid)) _mudar(EstadoDosLembretes.falhou);
      return false;
    } on FalhaDasNotificacoes {
      if (_aindaE(uid)) _mudar(EstadoDosLembretes.falhou);
      return false;
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao registrar o aparelho para os lembretes');
      if (_aindaE(uid)) _mudar(EstadoDosLembretes.falhou);
      return false;
    }
  }

  /// Falha ao ler a permissão conta como não permitida: sem saber, o
  /// identificador não vai para a API.
  Future<bool> _lerPermissao() async {
    bool permitidas;
    try {
      permitidas = await _notificacoes.permitidas();
    } on FalhaDasNotificacoes {
      permitidas = false;
    }
    _permitidas = permitidas;
    return permitidas;
  }

  Future<void> _revogar(int id) async {
    try {
      await _dispositivos.revogar(id);
    } on ErroDaApi {
      // Sem rede, ou a sessão já caiu: o token é apagado logo depois, e a API
      // apaga o registro na próxima tentativa de envio.
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao revogar o aparelho dos lembretes');
    }
  }

  Future<void> _apagarToken() async {
    if (_tokenApagado) return;
    try {
      await _notificacoes.apagarToken();
      _tokenApagado = true;
    } on FalhaDasNotificacoes {
      // Sem rede para o FCM: fica para a próxima abertura.
    }
  }

  Future<void> _lerToqueInicial() async {
    try {
      final lembrete = await _notificacoes.lembreteQueAbriuOApp();
      if (lembrete != null) _aoTocar(lembrete);
    } on FalhaDasNotificacoes {
      // Sem o toque inicial, o aplicativo abre no Início, como sempre.
    }
  }

  void _aoTocar(LembreteRecebido lembrete) {
    final mensagem = lembrete.messageId;
    if (mensagem != null && !_mensagensAbertas.add(mensagem)) return;
    _toquePendente = lembrete;
    _notificar();
  }

  String? get _uidComPerfil => _sessao.estado == EstadoDaSessao.comPerfil ? _sessao.usuario?.uid : null;

  bool _aindaE(String uid) => _uidComPerfil == uid;

  /// Põe o trabalho no fim da fila. Um trabalho que falha não trava os
  /// seguintes.
  Future<T> _naFila<T>(Future<T> Function() trabalho) {
    final resultado = _fila.then((_) => trabalho());
    _fila = resultado.then<void>((_) {}, onError: (Object _) {});
    return resultado;
  }

  void _mudar(EstadoDosLembretes estado) {
    _estado = estado;
    _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _sessao.removeListener(_aoMudarSessao);
    unawaited(_tocados?.cancel());
    super.dispose();
  }
}
