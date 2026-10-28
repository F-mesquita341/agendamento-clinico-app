import 'dart:async';
import 'dart:io';

import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_dispositivos.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_consentimento.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/data/services/servico_de_notificacoes.dart';
import 'package:agendamento_clinico/domain/models/checkout.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/dados_do_paciente.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/paciente.dart';
import 'package:agendamento_clinico/domain/models/pagina.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';

/// Respostas de teste numa fila: cada chamada consome a próxima. Pode ser um
/// valor, um erro (Exception ou Error, lançado), ou um Completer que o teste
/// resolve quando quiser — é assim que se simula o servidor demorando.
class Fila {
  Fila(Iterable<Object?> respostas) : _respostas = [...respostas];

  final List<Object?> _respostas;
  int chamadas = 0;

  Future<T> proxima<T>() {
    if (chamadas >= _respostas.length) {
      throw StateError('chamada ${chamadas + 1} sem resposta de teste');
    }
    final resposta = _respostas[chamadas++];
    return switch (resposta) {
      final Completer<T> c => c.future,
      final Exception e => Future.error(e),
      final Error e => Future.error(e),
      _ => Future.value(resposta as T),
    };
  }
}

/// O provedor de identidade em memória. `emitir` faz o papel do Firebase
/// avisando que alguém entrou ou saiu.
class AutenticacaoFalsa implements ServicoDeAutenticacao {
  AutenticacaoFalsa({
    Iterable<Object?> entrar = const [],
    Iterable<Object?> criarConta = const [],
    Iterable<Object?> redefinicao = const [],
  })  : respostasDeEntrar = Fila(entrar),
        respostasDeCriarConta = Fila(criarConta),
        respostasDeRedefinicao = Fila(redefinicao);

  final _mudancas = StreamController<UsuarioDaSessao?>.broadcast();
  final Fila respostasDeEntrar;
  final Fila respostasDeCriarConta;
  final Fila respostasDeRedefinicao;

  final pedidosDeEntrar = <({String email, String senha})>[];
  final pedidosDeCriarConta = <({String email, String senha})>[];
  final pedidosDeRedefinicao = <String>[];
  int saidas = 0;

  /// Se preenchido, `sair` lança este erro em vez de sair.
  Object? erroAoSair;

  void emitir(UsuarioDaSessao? usuario) => _mudancas.add(usuario);

  /// O provedor avisando uma falha no fluxo de mudanças de sessão.
  void emitirErro(Object erro) => _mudancas.addError(erro);

  @override
  Stream<UsuarioDaSessao?> get mudancas => _mudancas.stream;

  @override
  Future<void> entrar({required String email, required String senha}) {
    pedidosDeEntrar.add((email: email, senha: senha));
    return respostasDeEntrar.proxima<void>();
  }

  @override
  Future<void> criarConta({required String email, required String senha}) {
    pedidosDeCriarConta.add((email: email, senha: senha));
    return respostasDeCriarConta.proxima<void>();
  }

  @override
  Future<void> enviarRedefinicaoDeSenha(String email) {
    pedidosDeRedefinicao.add(email);
    return respostasDeRedefinicao.proxima<void>();
  }

  @override
  Future<void> sair() async {
    saidas++;
    if (erroAoSair case final erro?) throw erro;
    // Como o Firebase: sair avisa quem está ouvindo.
    emitir(null);
  }

  @override
  Future<String?> token({bool renovar = false}) async => 'token-de-teste';
}

/// O perfil do paciente em memória. Na fila de `meu`, `null` é "conta sem
/// cadastro".
class RepositorioDoPacienteFalso implements RepositorioDoPaciente {
  RepositorioDoPacienteFalso({
    Iterable<Object?> meu = const [],
    Iterable<Object?> cadastrar = const [],
    Iterable<Object?> atualizar = const [],
  })  : respostasDeMeu = Fila(meu),
        respostasDeCadastrar = Fila(cadastrar),
        respostasDeAtualizar = Fila(atualizar);

  final Fila respostasDeMeu;
  final Fila respostasDeCadastrar;
  final Fila respostasDeAtualizar;
  final cadastros = <({DadosDoPaciente dados, String versaoDoTermo})>[];
  final atualizacoes = <DadosDoPaciente>[];

  @override
  Future<Paciente?> meu() => respostasDeMeu.proxima<Paciente?>();

  @override
  Future<Paciente> cadastrar(DadosDoPaciente dados, {required String versaoDoTermo}) {
    cadastros.add((dados: dados, versaoDoTermo: versaoDoTermo));
    return respostasDeCadastrar.proxima<Paciente>();
  }

  @override
  Future<Paciente> atualizar(DadosDoPaciente dados) {
    atualizacoes.add(dados);
    return respostasDeAtualizar.proxima<Paciente>();
  }
}

/// A versão vigente do termo em memória.
class ConsentimentoFalso implements RepositorioDoConsentimento {
  ConsentimentoFalso(Iterable<Object?> versoes) : respostas = Fila(versoes);

  final Fila respostas;

  @override
  Future<String> versaoVigente() => respostas.proxima<String>();
}

/// O catálogo em memória, com uma fila de respostas para cada pedido e o
/// registro do que foi pedido.
class CatalogoFalso implements RepositorioDoCatalogo {
  CatalogoFalso({
    Iterable<Object?> especialidades = const [],
    Iterable<Object?> profissionais = const [],
    Iterable<Object?> horarios = const [],
  })  : respostasDeEspecialidades = Fila(especialidades),
        respostasDeProfissionais = Fila(profissionais),
        respostasDeHorarios = Fila(horarios);

  final Fila respostasDeEspecialidades;
  final Fila respostasDeProfissionais;
  final Fila respostasDeHorarios;
  final pedidosDeProfissionais = <({int? especialidadeId, String? termo, int pagina})>[];
  final pedidosDeHorarios = <({int profissionalId, DataCivil ate})>[];

  @override
  Future<List<Especialidade>> especialidades() => respostasDeEspecialidades.proxima<List<Especialidade>>();

  @override
  Future<Pagina<Profissional>> profissionais({int? especialidadeId, String? termo, int pagina = 1}) {
    pedidosDeProfissionais.add((especialidadeId: especialidadeId, termo: termo, pagina: pagina));
    return respostasDeProfissionais.proxima<Pagina<Profissional>>();
  }

  @override
  Future<List<Horario>> horarios(int profissionalId, {required DataCivil ate}) {
    pedidosDeHorarios.add((profissionalId: profissionalId, ate: ate));
    return respostasDeHorarios.proxima<List<Horario>>();
  }
}

/// As consultas em memória, com uma fila de respostas para cada pedido e o
/// registro do que foi pedido.
class ConsultasFalso implements RepositorioDeConsultas {
  ConsultasFalso({
    Iterable<Object?> agendar = const [],
    Iterable<Object?> minhas = const [],
    Iterable<Object?> consulta = const [],
    Iterable<Object?> pagar = const [],
    Iterable<Object?> cancelar = const [],
  })  : respostasDeAgendar = Fila(agendar),
        respostasDeMinhas = Fila(minhas),
        respostasDeConsulta = Fila(consulta),
        respostasDePagar = Fila(pagar),
        respostasDeCancelar = Fila(cancelar);

  final Fila respostasDeAgendar;
  final Fila respostasDeMinhas;
  final Fila respostasDeConsulta;
  final Fila respostasDePagar;
  final Fila respostasDeCancelar;
  final pedidosDeAgendar = <({int horarioId, int versao})>[];
  final pedidosDeMinhas = <int>[];
  final pedidosDeConsulta = <int>[];
  final pedidosDePagar = <int>[];
  final pedidosDeCancelar = <int>[];

  @override
  Future<Consulta> agendar({required int horarioId, required int versao}) {
    pedidosDeAgendar.add((horarioId: horarioId, versao: versao));
    return respostasDeAgendar.proxima<Consulta>();
  }

  @override
  Future<Pagina<Consulta>> minhas({int pagina = 1}) {
    pedidosDeMinhas.add(pagina);
    return respostasDeMinhas.proxima<Pagina<Consulta>>();
  }

  @override
  Future<Consulta> consulta(int id) {
    pedidosDeConsulta.add(id);
    return respostasDeConsulta.proxima<Consulta>();
  }

  @override
  Future<Checkout> pagar(int consultaId) {
    pedidosDePagar.add(consultaId);
    return respostasDePagar.proxima<Checkout>();
  }

  @override
  Future<Consulta> cancelar(int id) {
    pedidosDeCancelar.add(id);
    return respostasDeCancelar.proxima<Consulta>();
  }
}

/// O discador e o mapa em memória: registra o que seria aberto, e responde
/// se o aparelho "conseguiu" abrir.
class AbridorDeLinksFalso implements AbridorDeLinks {
  AbridorDeLinksFalso({this.consegue = true});

  /// Se o aparelho "consegue" abrir — o teste pode mudar no meio.
  bool consegue;
  final ligacoes = <String>[];
  final mapas = <String>[];
  final pagamentos = <Uri>[];

  @override
  Future<bool> ligar(String telefone) async {
    ligacoes.add(telefone);
    return consegue;
  }

  @override
  Future<bool> abrirNoMapa(String lugar) async {
    mapas.add(lugar);
    return consegue;
  }

  @override
  Future<bool> abrirPagamento(Uri endereco) async {
    pagamentos.add(endereco);
    return consegue;
  }
}

/// As notificações do aparelho em memória. Sem nada dito, como numa
/// instalação nova no Android 13: sem a permissão, e a pergunta do sistema
/// respondida com "Não permitir".
class NotificacoesFalsas implements ServicoDeNotificacoes {
  NotificacoesFalsas({this.permitido = false, this.concede = false, this.toqueInicial});

  /// O que o sistema diz agora. O teste muda no meio, como a pessoa nas
  /// configurações do Android.
  bool permitido;

  /// A resposta à pergunta do sistema.
  bool concede;

  /// Se preenchidos, a leitura da permissão e a pergunta ficam no ar até o
  /// teste completá-los.
  Completer<bool>? leituraNoAr;
  Completer<bool>? perguntaNoAr;

  String tokenAtual = 'token-fcm-de-teste';

  /// Se preenchidos, `permitidas` e `token` lançam estes erros.
  Object? erroDaPermissao;
  Object? erroDoToken;

  LembreteRecebido? toqueInicial;

  int leiturasDaPermissao = 0;
  int perguntas = 0;
  int pedidosDeToken = 0;
  int tokensApagados = 0;
  int leiturasDoToqueInicial = 0;

  final _tocados = StreamController<LembreteRecebido>.broadcast();
  final _comOAppAberto = StreamController<LembreteRecebido>.broadcast();

  /// A pessoa toca no lembrete, com o aplicativo em segundo plano.
  void tocar(LembreteRecebido lembrete) => _tocados.add(lembrete);

  /// Um lembrete chega com o aplicativo aberto.
  void chegarComOAppAberto(LembreteRecebido lembrete) => _comOAppAberto.add(lembrete);

  @override
  Future<bool> permitidas() async {
    leiturasDaPermissao++;
    if (erroDaPermissao case final erro?) throw erro;
    final leitura = leituraNoAr;
    if (leitura != null) {
      leituraNoAr = null;
      return leitura.future;
    }
    return permitido;
  }

  @override
  Future<bool> pedirPermissao() async {
    perguntas++;
    final pergunta = perguntaNoAr;
    perguntaNoAr = null;
    final resposta = pergunta == null ? concede : await pergunta.future;
    if (resposta) permitido = true;
    return resposta;
  }

  @override
  Future<String> token() async {
    pedidosDeToken++;
    if (erroDoToken case final erro?) throw erro;
    return tokenAtual;
  }

  @override
  Future<void> apagarToken() async => tokensApagados++;

  @override
  Future<LembreteRecebido?> lembreteQueAbriuOApp() async {
    leiturasDoToqueInicial++;
    return toqueInicial;
  }

  @override
  Stream<LembreteRecebido> get lembretesTocados => _tocados.stream;

  @override
  Stream<LembreteRecebido> get lembretesComOAppAberto => _comOAppAberto.stream;
}

/// Os aparelhos na API em memória, com uma fila de respostas para registrar
/// e outra para revogar, e o registro do que foi pedido.
class DispositivosFalso implements RepositorioDeDispositivos {
  DispositivosFalso({Iterable<Object?> registrar = const [], Iterable<Object?> revogar = const []})
      : respostasDeRegistrar = Fila(registrar),
        respostasDeRevogar = Fila(revogar);

  final Fila respostasDeRegistrar;
  final Fila respostasDeRevogar;
  final registros = <String>[];
  final revogacoes = <int>[];

  @override
  Future<int> registrar(String token) {
    registros.add(token);
    return respostasDeRegistrar.proxima<int>();
  }

  @override
  Future<void> revogar(int id) {
    revogacoes.add(id);
    return respostasDeRevogar.proxima<void>();
  }
}

/// Um lembrete da consulta [consultaId], como a API o envia.
LembreteRecebido lembreteDaConsulta(int consultaId, {String? messageId, String? texto}) => LembreteRecebido(
      consultaId: consultaId,
      messageId: messageId ?? 'mensagem-$consultaId',
      texto: texto ?? 'Você tem uma consulta amanhã às 14:30.',
    );

/// Uma página de profissionais; sem mais nada dito, a única.
Pagina<Profissional> paginaDe(List<Profissional> itens, {int pagina = 1, int paginas = 1, int? total}) =>
    Pagina(itens: itens, pagina: pagina, paginas: paginas, total: total ?? itens.length);

/// Uma página de consultas; sem mais nada dito, a única.
Pagina<Consulta> paginaDeConsultas(List<Consulta> itens, {int pagina = 1, int paginas = 1}) =>
    Pagina(itens: itens, pagina: pagina, paginas: paginas, total: itens.length);

/// A consulta que reserva o [horario]: aguardando pagamento, com o prazo
/// [expiraEm], como o agendamento a devolve — sem o horário dentro. Com
/// [comHorario], como as listagens a trazem.
Consulta reservaDe(
  Horario horario, {
  required DateTime expiraEm,
  int id = 50,
  StatusDaConsulta status = StatusDaConsulta.pendentePagamento,
  bool comHorario = false,
}) =>
    Consulta(
      id: id,
      status: status,
      horarioId: horario.id,
      valorFormatado: 'R\$ 250,00',
      reservaExpiraEm: expiraEm,
      horario: comHorario ? horario : null,
    );

/// Lê os arquivos do termo direto do disco, como o aplicativo os lê do pacote.
Future<String> lerDoDisco(String caminho) => Future.value(File(caminho).readAsStringSync());

const ana = UsuarioDaSessao(uid: 'uid-ana', email: 'ana@exemplo.test');
const bruno = UsuarioDaSessao(uid: 'uid-bruno', email: 'bruno@exemplo.test');

Paciente pacienteDeTeste({String nome = 'Ana Lima', String email = 'ana@exemplo.test'}) => Paciente(
      id: 1,
      nome: nome,
      email: email,
      telefone: '88999990000',
      dataNascimento: DataCivil.tentar(1990, 3, 15),
      versaoDoTermo: '2026-09-v2',
      termoAceitoEm: DateTime(2026, 10, 6, 9, 30),
    );
