import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../data/services/preferencias_do_aparelho.dart';
import '../../domain/models/cidade.dart';
import '../../domain/models/clinica.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/especialidade.dart';
import '../../domain/models/pagina.dart';
import '../../domain/models/plano.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';
import '../comum/estados_de_carga.dart';
import 'sugestoes.dart';

/// A busca de profissionais: os filtros — a especialidade, o texto, a cidade e
/// o plano —, a lista paginada que eles dão, e o estado de cada pedido.
///
/// A cidade é onde a pessoa está, e não um filtro como os outros: fica
/// guardada no aparelho de uma abertura para outra, e "Limpar filtros" não a
/// tira. Cidades e planos vieram com a versão 2 da API; se as listas não
/// vierem — a API de produção não as tem —, a busca segue sem eles.
class BuscaViewModel extends ChangeNotifier {
  BuscaViewModel(
    this._catalogo, {
    PreferenciasDoAparelho? preferencias,
    this.relogio = DateTime.now,
    this.esperaAteAvisar = const Duration(seconds: 4),
    this.esperaAoDigitar = const Duration(milliseconds: 300),
  }) : _preferencias = preferencias;

  final RepositorioDoCatalogo _catalogo;

  /// Onde a cidade escolhida fica guardada. Sem ele, a escolha vale só
  /// enquanto o aplicativo está aberto.
  final PreferenciasDoAparelho? _preferencias;

  /// O relógio que diz "hoje" e "amanhã" no próximo horário de cada card.
  final DateTime Function() relogio;

  /// Hoje, no calendário da clínica.
  DataCivil get hoje => DataCivil.naClinica(relogio());

  /// Depois deste tempo carregando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  /// Quanto esperar, depois da última tecla, antes de buscar. Sem a espera,
  /// digitar "ana" faria três pedidos, um por letra.
  final Duration esperaAoDigitar;

  EstadoDaCarga _estado = EstadoDaCarga.carregando;
  List<Especialidade>? _especialidades;
  int? _especialidadeId;
  List<Cidade>? _cidades;
  int? _cidadeId;
  List<Plano>? _planos;
  int? _planoId;
  bool _cidadeGuardadaLida = false;
  bool _cidadeEscolhida = false;
  String _texto = '';
  String? _termo;
  List<Profissional> _profissionais = const [];
  final _clinicas = <Clinica>[];
  int _total = 0;
  int _pagina = 1;
  bool _temMais = false;
  bool _mostrandoMais = false;
  bool _atualizando = false;
  ErroDaApi? _erro;
  ErroDaApi? _erroAoAtualizar;
  ErroDaApi? _erroAoMostrarMais;
  Timer? _esperaDoTexto;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  /// Cada busca nova leva um número. A resposta que chega com o número de uma
  /// busca antiga é descartada: sem isso, o resultado de "an" podia chegar
  /// depois e cobrir o de "ana".
  int _busca = 0;

  /// O estado da lista: muda a cada busca nova, e não só na primeira.
  EstadoDaCarga get estado => _estado;

  /// As especialidades para escolher. Vazia até a primeira resposta.
  List<Especialidade> get especialidades => _especialidades ?? const [];

  /// A especialidade escolhida; null é "Todas".
  int? get especialidadeId => _especialidadeId;
  Especialidade? get especialidade => especialidades.where((e) => e.id == _especialidadeId).firstOrNull;

  /// O texto que foi de fato buscado no nome — o digitado, sem os espaços em
  /// volta —, ou null quando ele tem menos de duas letras.
  String? get termo => _termo;

  /// Há uma letra só no campo: a API pede duas, e a tela diz isso.
  /// O texto do campo, como a pessoa digitou — ou vazio, quando outra tela
  /// escolheu a especialidade.
  String get texto => _texto;

  bool get textoCurto => _texto.trim().length == 1;

  /// As cidades para escolher. Vazia até a resposta, ou se ela não veio.
  List<Cidade> get cidades => _cidades ?? const [];

  /// A cidade escolhida, se ela está na lista; null é "Todas as cidades".
  /// Enquanto a lista não vem, a cidade guardada não filtra: a tela não
  /// teria como dizer qual é.
  Cidade? get cidade => cidades.where((c) => c.id == _cidadeId).firstOrNull;

  /// Os planos para escolher. Vazia até a resposta, ou se ela não veio.
  List<Plano> get planos => _planos ?? const [];

  /// O plano escolhido; null é "Qualquer plano".
  Plano? get plano => planos.where((p) => p.id == _planoId).firstOrNull;

  /// A cidade não conta: ela não é filtro, e "Limpar filtros" não a tira.
  bool get temFiltro => _especialidadeId != null || _texto.trim().isNotEmpty || plano != null;

  /// Especialidades que o texto buscado parece procurar, fora a já escolhida.
  List<Especialidade> get sugestoes => [
        for (final sugerida in especialidadesSugeridas(_termo ?? '', especialidades))
          if (sugerida.id != _especialidadeId) sugerida,
      ];

  List<Profissional> get profissionais => _profissionais;

  /// As clínicas dos profissionais que a busca já mostrou, sem repetir: o
  /// Perfil e o "Como funciona" dão o telefone delas (checklist, item 10.3).
  /// A API não tem rota de clínica; ela vem dentro de cada profissional. A
  /// lista só cresce: um filtro depois não apaga a clínica já conhecida.
  List<Clinica> get clinicas => List.unmodifiable(_clinicas);

  /// Quantos profissionais a busca achou ao todo, somando as páginas.
  int get total => _total;
  bool get temMais => _temMais;
  bool get mostrandoMais => _mostrandoMais;

  /// A lista está sendo pedida de novo, com ela na tela.
  bool get atualizando => _atualizando;

  /// Por que a busca falhou.
  ErroDaApi? get erro => _erro;

  /// Por que a última atualização falhou — a lista anterior continua na tela.
  ErroDaApi? get erroAoAtualizar => _erroAoAtualizar;

  /// Por que a página seguinte não veio — as anteriores continuam na tela.
  ErroDaApi? get erroAoMostrarMais => _erroAoMostrarMais;

  bool get demorando => _aviso.demorando;

  /// Busca com os filtros de agora, trocando a lista. É a primeira carga e o
  /// "Tentar de novo". Na primeira, antes de buscar, lê a cidade guardada:
  /// a primeira lista já sai na cidade da pessoa.
  Future<void> carregar() async {
    if (!_cidadeGuardadaLida) {
      _cidadeGuardadaLida = true;
      final guardada = await _lerCidadeGuardada();
      // Se a pessoa escolheu uma cidade enquanto a leitura demorava, vale a
      // escolha dela.
      if (!_cidadeEscolhida) _cidadeId = guardada;
    }
    return _buscar();
  }

  /// A pessoa escolheu a cidade: fica guardada, e a busca recomeça nela.
  void escolherCidade(int? id) {
    _cidadeEscolhida = true;
    if (id == cidade?.id) return;
    _cidadeId = id;
    _guardarCidade(id);
    _buscar();
  }

  void escolherPlano(int? id) {
    if (id == plano?.id) return;
    _planoId = id;
    _buscar();
  }

  /// Pede de novo as listas de cidades e planos que não vieram — a tela chama
  /// ao abrir a escolha. Se a cidade guardada passar a existir na lista, a
  /// busca recomeça nela.
  Future<void> tentarListasDeNovo() async {
    if (_cidades != null && _planos != null) return;
    final antes = cidade?.id;
    await _carregarListas();
    _notificar();
    if (cidade?.id != antes) await _buscar();
  }

  /// O texto do campo mudou. A busca espera a pessoa parar de digitar.
  void aoDigitar(String texto) {
    _texto = texto;
    _esperaDoTexto?.cancel();
    // Com uma letra só, ou só espaços a mais, a busca continua a mesma.
    if (_termoDe(texto) != _termo) _esperaDoTexto = Timer(esperaAoDigitar, _buscar);
    _notificar();
  }

  void escolherEspecialidade(int? id) {
    if (id == _especialidadeId) return;
    _especialidadeId = id;
    _buscar();
  }

  /// Volta a todos os profissionais da cidade: tira a especialidade, o texto
  /// e o plano. Quem mostra o campo de busca o esvazia.
  void limparFiltros() {
    _planoId = null;
    _ficarSoCom(null);
  }

  /// Troca o texto digitado pela especialidade que ele procurava. Quem mostra
  /// o campo de busca o esvazia.
  void aceitarSugestao(Especialidade sugerida) => _ficarSoCom(sugerida.id);

  /// Os profissionais de uma especialidade, escolhida fora da busca — no
  /// Início. O texto digitado sai, para a lista ser a da especialidade toda.
  void mostrarEspecialidade(int especialidadeId) => _ficarSoCom(especialidadeId);

  void _ficarSoCom(int? especialidadeId) {
    _texto = '';
    _especialidadeId = especialidadeId;
    _buscar();
  }

  /// Puxar para atualizar: a primeira página de novo, com a lista na tela. Se
  /// falhar, a lista fica e [erroAoAtualizar] diz por quê.
  ///
  /// A página 1 nova invalida um "mostrar mais" que ainda esteja no ar: a
  /// página seguinte da lista antiga, chegando depois, seria acrescentada à
  /// lista nova (revisão de 19/10). Enquanto atualiza, "mostrar mais" espera.
  Future<void> atualizar() async {
    if (_estado != EstadoDaCarga.pronto) return _buscar();
    final busca = ++_busca;
    _atualizando = true;
    _mostrandoMais = false;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _aviso.esquecerPedidos();
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(1, listas: true));
    if (busca != _busca) return;
    _atualizando = false;
    if (pagina != null) {
      _mostrar(pagina);
    } else {
      _erroAoAtualizar = erro;
    }
    _notificar();
  }

  /// A página seguinte, acrescentada à lista.
  ///
  /// A tela esconde o botão enquanto a página carrega, mas a trava fica aqui:
  /// um segundo pedido da mesma página duplicaria os profissionais na lista, e
  /// um pedido durante uma busca nova levaria a página de uma lista que já saiu.
  Future<void> mostrarMais() async {
    if (_mostrandoMais || _atualizando || !_temMais || _estado != EstadoDaCarga.pronto) return;
    final busca = _busca;
    _mostrandoMais = true;
    _erroAoMostrarMais = null;
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(_pagina + 1));
    if (busca != _busca) return;
    _mostrandoMais = false;
    if (pagina != null) {
      _mostrar(pagina, depois: _profissionais);
    } else {
      _erroAoMostrarMais = erro;
    }
    _notificar();
  }

  Future<void> _buscar() async {
    final busca = ++_busca;
    _esperaDoTexto?.cancel();
    _termo = _termoDe(_texto);
    _estado = EstadoDaCarga.carregando;
    _erro = null;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _mostrandoMais = false;
    _atualizando = false;
    // As respostas das buscas anteriores vão ser descartadas: não contam mais
    // para o aviso de demora.
    _aviso.esquecerPedidos();
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(1, listas: true));
    if (busca != _busca) return;
    if (pagina != null) {
      _mostrar(pagina);
      _estado = EstadoDaCarga.pronto;
    } else {
      _erro = erro;
      _estado = EstadoDaCarga.falhou;
    }
    _notificar();
  }

  /// Pede uma página com os filtros de agora — e, antes, as especialidades, se
  /// ainda não vieram, e, na primeira página, as cidades e os planos que
  /// faltarem. Devolve a página, ou o erro que a tela mostra: nunca lança,
  /// para nenhum pedido deixar a tela presa carregando.
  Future<({Pagina<Profissional>? pagina, ErroDaApi? erro})> _pedir(int numero, {bool listas = false}) async {
    try {
      _especialidades ??= await _catalogo.especialidades();
      if (listas) await _carregarListas();
      // Os filtros são lidos depois das listas: a cidade guardada só filtra
      // se ela estiver na lista de cidades.
      final pagina = await _catalogo.profissionais(
        especialidadeId: _especialidadeId,
        termo: _termo,
        cidadeId: cidade?.id,
        planoId: plano?.id,
        pagina: numero,
      );
      return (pagina: pagina, erro: null);
    } on ErroDaApi catch (erro) {
      return (pagina: null, erro: erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao buscar profissionais');
      return (pagina: null, erro: const ErroDaApi.falhaNoAplicativo());
    }
  }

  /// As cidades e os planos que ainda não vieram. Falhar aqui não falha a
  /// busca: a lista que não veio fica para a próxima vez.
  Future<void> _carregarListas() async {
    if (_cidades == null) {
      _cidades = await _listaOuNada(_catalogo.cidades, 'ao pedir as cidades');
      // A cidade guardada saiu do catálogo: volta a valer "Todas as cidades".
      if (_cidades != null && _cidadeId != null && cidade == null) {
        _cidadeId = null;
        _guardarCidade(null);
      }
    }
    _planos ??= await _listaOuNada(_catalogo.planos, 'ao pedir os planos');
  }

  Future<List<T>?> _listaOuNada<T>(Future<List<T>> Function() pedir, String quando) async {
    try {
      return await pedir();
    } on ErroDaApi {
      return null;
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, quando);
      return null;
    }
  }

  /// A cidade guardada, ou null. Sem conseguir ler, a busca começa em "Todas
  /// as cidades".
  ///
  /// O armazenamento do aparelho falhar não é defeito do aplicativo — como o
  /// serviço de notificações sem o Google Play —: fica no log, e a busca
  /// segue.
  Future<int?> _lerCidadeGuardada() async {
    try {
      return await _preferencias?.cidadeEscolhida();
    } catch (erro) {
      debugPrint('Não deu para ler a cidade guardada: $erro');
      return null;
    }
  }

  /// Guardar a cidade nunca segura a tela: a busca não espera, e uma falha só
  /// faz a escolha não sobreviver a uma nova abertura.
  void _guardarCidade(int? id) {
    final guardando = _preferencias?.guardarCidade(id);
    guardando?.catchError((Object erro) => debugPrint('Não deu para guardar a cidade: $erro'));
  }

  void _mostrar(Pagina<Profissional> pagina, {List<Profissional> depois = const []}) {
    _profissionais = [...depois, ...pagina.itens];
    _pagina = pagina.pagina;
    _total = pagina.total;
    _temMais = pagina.temMais;
    for (final Profissional(:clinica) in pagina.itens) {
      if (clinica == null) continue;
      final conhecida = _clinicas.any((outra) => outra.nome == clinica.nome && outra.telefone == clinica.telefone);
      if (!conhecida) _clinicas.add(clinica);
    }
  }

  static String? _termoDe(String texto) {
    final limpo = texto.trim();
    return limpo.length >= 2 ? limpo : null;
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _esperaDoTexto?.cancel();
    _aviso.parar();
    super.dispose();
  }
}
