import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_paciente.dart';
import '../../data/services/servico_de_autenticacao.dart';
import '../../data/services/traducoes_da_autenticacao.dart' show sessaoEncerrada;
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/paciente.dart';
import '../comum/defeitos.dart';

/// Onde o paciente está, do ponto de vista da conta. É daqui que a raiz do
/// aplicativo decide a tela — a guarda de rota da Etapa 12:
///
///   sem sessão ............ entrar
///   com sessão, sem perfil  termo e cadastro
///   com sessão e perfil ... o aplicativo
enum EstadoDaSessao { iniciando, semSessao, carregandoPerfil, semPerfil, comPerfil, falhou }

class SessaoViewModel extends ChangeNotifier {
  SessaoViewModel({
    required ServicoDeAutenticacao autenticacao,
    required RepositorioDoPaciente pacientes,
    this.esperaAteAvisar = const Duration(seconds: 4),
  })  : _autenticacao = autenticacao,
        _pacientes = pacientes;

  final ServicoDeAutenticacao _autenticacao;
  final RepositorioDoPaciente _pacientes;

  /// Depois deste tempo carregando o perfil, a tela avisa que o servidor está
  /// demorando — o mesmo aviso da Etapa 11.
  final Duration esperaAteAvisar;

  EstadoDaSessao _estado = EstadoDaSessao.iniciando;
  UsuarioDaSessao? _usuario;
  Paciente? _paciente;
  ErroDaApi? _erro;
  String? _motivoDaSaida;

  /// Cada sessão e cada carga do perfil ganham um número novo. Resposta que
  /// chega com número velho — de uma conta que já saiu, ou de uma carga que
  /// outra substituiu — é descartada: sem isso, o perfil de uma pessoa
  /// poderia aparecer na sessão de outra.
  int _geracao = 0;

  StreamSubscription<UsuarioDaSessao?>? _inscricao;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  EstadoDaSessao get estado => _estado;
  UsuarioDaSessao? get usuario => _usuario;
  Paciente? get paciente => _paciente;

  /// Por que a carga do perfil falhou.
  ErroDaApi? get erro => _erro;
  bool get demorando => _aviso.demorando;

  /// Por que a sessão terminou sem a pessoa pedir — a tela de entrar mostra.
  String? get motivoDaSaida => _motivoDaSaida;

  void iniciar() {
    _inscricao ??= _autenticacao.mudancas.listen(
      _aoMudarUsuario,
      onError: (Object erro, StackTrace pilha) => relatarDefeito(erro, pilha, 'nas mudanças de sessão do provedor'),
    );
  }

  void _aoMudarUsuario(UsuarioDaSessao? novo) {
    if (novo == null) {
      _encerrar();
      return;
    }
    // O mesmo usuário de novo não muda nada — e recarregar o perfil à toa
    // jogaria a pessoa para fora da tela em que está.
    if (novo.uid == _usuario?.uid) return;
    _usuario = novo;
    _motivoDaSaida = null;
    unawaited(carregarPerfil());
  }

  Future<void> carregarPerfil() async {
    final geracao = ++_geracao;
    _estado = EstadoDaSessao.carregandoPerfil;
    _erro = null;
    _aviso.iniciar();
    _notificar();

    try {
      final paciente = await _pacientes.meu();
      if (geracao != _geracao) return;
      _paciente = paciente;
      _estado = paciente == null ? EstadoDaSessao.semPerfil : EstadoDaSessao.comPerfil;
    } on ErroDaApi catch (erro) {
      if (geracao != _geracao) return;
      _falhar(erro);
    } catch (erro, pilha) {
      if (geracao != _geracao) return;
      relatarDefeito(erro, pilha, 'ao carregar o perfil do paciente');
      _falhar(const ErroDaApi.falhaNoAplicativo());
    } finally {
      if (geracao == _geracao) {
        _aviso.parar();
        _notificar();
      }
    }
  }

  /// O cadastro terminou: o perfil passa a existir sem precisar de nova carga.
  void perfilCadastrado(Paciente paciente) {
    _geracao++;
    _paciente = paciente;
    _estado = EstadoDaSessao.comPerfil;
    _notificar();
  }

  void perfilAtualizado(Paciente paciente) {
    _paciente = paciente;
    _notificar();
  }

  /// A pessoa pediu para sair.
  Future<void> sair() async {
    _motivoDaSaida = null;
    await _sairDoProvedor();
  }

  /// A sessão deixou de valer — a API ou o provedor disseram `autenticar`.
  /// Vai para a tela de entrar já, com o motivo, sem esperar o provedor
  /// confirmar a saída.
  void sessaoPerdida() {
    if (_estado == EstadoDaSessao.semSessao) return;
    _encerrar();
    _motivoDaSaida = sessaoEncerrada.mensagem;
    _notificar();
    unawaited(_sairDoProvedor());
  }

  /// Sair nunca lança: falha do provedor é relatada, e a tela não fica com um
  /// erro solto — quem chamou é um botão, ou um pedido que já falhou.
  Future<void> _sairDoProvedor() async {
    try {
      await _autenticacao.sair();
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao sair da conta no provedor');
    }
  }

  void _encerrar() {
    _geracao++;
    _usuario = null;
    _paciente = null;
    _erro = null;
    _aviso.parar();
    _estado = EstadoDaSessao.semSessao;
    _notificar();
  }

  void _falhar(ErroDaApi erro) {
    _erro = erro;
    _estado = EstadoDaSessao.falhou;
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _aviso.parar();
    unawaited(_inscricao?.cancel());
    super.dispose();
  }
}
