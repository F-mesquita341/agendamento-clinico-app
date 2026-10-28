import 'dart:async';

import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/data/services/servico_de_notificacoes.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_view_model.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/falsos.dart';

/// Os lembretes: a permissão, o registro do aparelho na API e os toques.
void main() {
  late AutenticacaoFalsa autenticacao;
  late NotificacoesFalsas notificacoes;
  late DispositivosFalso dispositivos;
  late RepositorioDoPacienteFalso pacientes;
  late SessaoViewModel sessao;
  late LembretesViewModel lembretes;

  /// O aplicativo ligado como em `main.dart`: "Sair da conta" passa pelos
  /// lembretes antes de sair do provedor.
  void montar({Duration teto = const Duration(seconds: 15)}) {
    sessao = SessaoViewModel(
      autenticacao: autenticacao,
      pacientes: pacientes,
      antesDeSair: () => lembretes.antesDeSair(),
    )..iniciar();
    lembretes = LembretesViewModel(
      notificacoes: notificacoes,
      dispositivos: dispositivos,
      sessao: sessao,
      tetoDaSaida: teto,
    )..iniciar();
  }

  setUp(() {
    autenticacao = AutenticacaoFalsa();
    notificacoes = NotificacoesFalsas();
    dispositivos = DispositivosFalso();
    pacientes = RepositorioDoPacienteFalso(meu: [pacienteDeTeste(), pacienteDeTeste()]);
  });

  Future<void> entrar([UsuarioDaSessao usuario = ana]) async {
    autenticacao.emitir(usuario);
    await pumpEventQueue();
  }

  group('ao entrar', () {
    test('com a permissão: registra o aparelho com o token, e os lembretes ficam ativados', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();

      await entrar();

      expect(dispositivos.registros, ['token-fcm-de-teste']);
      expect(lembretes.estado, EstadoDosLembretes.ativados);
      expect(lembretes.permitidas, isTrue);
    });

    test('sem a permissão: não registra, apaga o token, e os lembretes ficam desativados', () async {
      montar();

      await entrar();

      expect(dispositivos.registros, isEmpty);
      expect(notificacoes.tokensApagados, 1);
      expect(lembretes.estado, EstadoDosLembretes.desativados);
    });

    test('só a transição conta: o perfil atualizado não lê a permissão nem o token de novo', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await entrar();
      final leituras = notificacoes.leiturasDaPermissao;

      sessao.perfilAtualizado(pacienteDeTeste(nome: 'Ana Lima Sá'));
      await pumpEventQueue();

      expect(notificacoes.leiturasDaPermissao, leituras);
      expect(notificacoes.pedidosDeToken, 1);
      expect(dispositivos.registros, hasLength(1));
    });

    test('abrir sem sessão apaga o token: refaz a limpeza de uma saída que falhou', () async {
      montar();

      autenticacao.emitir(null);
      await pumpEventQueue();

      expect(notificacoes.tokensApagados, 1);
      expect(dispositivos.registros, isEmpty);
    });

    test('o registro que falha deixa os lembretes em falha, sem relatar defeito', () async {
      final relatados = <FlutterErrorDetails>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = relatados.add;
      addTearDown(() => FlutterError.onError = anterior);
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [const ErroDaApi.semConexao(), 12]);
      montar();

      await entrar();
      expect(lembretes.estado, EstadoDosLembretes.falhou);

      lembretes.tentarDeNovo();
      expect(lembretes.estado, EstadoDosLembretes.ativando);
      await pumpEventQueue();
      expect(lembretes.estado, EstadoDosLembretes.ativados);
      expect(relatados, isEmpty);
    });

    test('a permissão que não se consegue ler conta como negada: nada vai para a API', () async {
      notificacoes
        ..permitido = true
        ..erroDaPermissao = const FalhaDasNotificacoes('sem a atividade');
      montar();

      await entrar();

      expect(lembretes.permitidas, isFalse);
      expect(dispositivos.registros, isEmpty);
      expect(lembretes.estado, EstadoDosLembretes.desativados);
    });

    test('sem o Google Play (o FCM não dá o token): falha, sem relatar defeito', () async {
      final relatados = <FlutterErrorDetails>[];
      final anterior = FlutterError.onError;
      FlutterError.onError = relatados.add;
      addTearDown(() => FlutterError.onError = anterior);
      notificacoes
        ..permitido = true
        ..erroDoToken = const FalhaDasNotificacoes('SERVICE_NOT_AVAILABLE');
      montar();

      await entrar();

      expect(lembretes.estado, EstadoDosLembretes.falhou);
      expect(dispositivos.registros, isEmpty);
      expect(relatados, isEmpty);
    });
  });

  group('de volta ao aplicativo', () {
    test('com a permissão e o mesmo token: não registra de novo', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await entrar();

      lembretes.aoVoltarAoAplicativo();
      await pumpEventQueue();

      expect(dispositivos.registros, hasLength(1));
      expect(lembretes.estado, EstadoDosLembretes.ativados);
    });

    test('a permissão revogada nas configurações: o aparelho sai da API e o token é apagado', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12], revogar: [null]);
      montar();
      await entrar();

      notificacoes.permitido = false;
      lembretes.aoVoltarAoAplicativo();
      await pumpEventQueue();

      expect(dispositivos.revogacoes, [12]);
      expect(notificacoes.tokensApagados, 1);
      expect(lembretes.estado, EstadoDosLembretes.desativados);
    });

    test('a permissão dada nas configurações: registra', () async {
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await entrar();

      notificacoes.permitido = true;
      lembretes.aoVoltarAoAplicativo();
      await pumpEventQueue();

      expect(dispositivos.registros, hasLength(1));
      expect(lembretes.estado, EstadoDosLembretes.ativados);
    });

    test('a fila: a volta da pergunta do sistema e o "ativar" fazem um registro só', () async {
      final resposta = Completer<int>();
      final pergunta = Completer<bool>();
      dispositivos = DispositivosFalso(registrar: [resposta, 13]);
      montar();
      await entrar();

      notificacoes.perguntaNoAr = pergunta;
      final ativacao = lembretes.ativar();
      await pumpEventQueue();
      // A pessoa toca em "Permitir": a pergunta responde, e o aplicativo volta
      // para a frente ao mesmo tempo.
      pergunta.complete(true);
      lembretes.aoVoltarAoAplicativo();
      await pumpEventQueue();
      resposta.complete(12);

      expect(await ativacao, ResultadoDaAtivacao.ativados);
      await pumpEventQueue();
      expect(dispositivos.registros, hasLength(1));
    });
  });

  group('ativar', () {
    test('a pergunta respondida com "Permitir": registra, e ativados', () async {
      notificacoes.concede = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await entrar();

      final ativacao = lembretes.ativar();
      expect(lembretes.estado, EstadoDosLembretes.ativando);

      expect(await ativacao, ResultadoDaAtivacao.ativados);
      expect(notificacoes.perguntas, 1);
      expect(dispositivos.registros, hasLength(1));
      expect(lembretes.estado, EstadoDosLembretes.ativados);
    });

    test('a pergunta respondida com "Não permitir": nada vai para a API', () async {
      montar();
      await entrar();

      expect(await lembretes.ativar(), ResultadoDaAtivacao.negada);
      expect(dispositivos.registros, isEmpty);
      expect(lembretes.estado, EstadoDosLembretes.desativados);
    });

    test('permitido, mas o registro falha: falhou', () async {
      notificacoes.concede = true;
      dispositivos = DispositivosFalso(registrar: [const ErroDaApi.semConexao()]);
      montar();
      await entrar();

      expect(await lembretes.ativar(), ResultadoDaAtivacao.falhou);
      expect(lembretes.estado, EstadoDosLembretes.falhou);
    });
  });

  group('sair da conta', () {
    test('o DELETE vai antes de sair do provedor, com o token da conta ainda valendo', () async {
      final revogacao = Completer<void>();
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12], revogar: [revogacao]);
      montar();
      await entrar();

      final saida = sessao.sair();
      await pumpEventQueue();
      expect(sessao.saindo, isTrue);
      expect(dispositivos.revogacoes, [12]);
      expect(autenticacao.saidas, 0);

      revogacao.complete();
      await saida;
      await pumpEventQueue();
      expect(autenticacao.saidas, 1);
      expect(sessao.saindo, isFalse);
      expect(notificacoes.tokensApagados, 1);
    });

    test('espera o registro no ar e revoga o id que ele devolveu', () async {
      final resposta = Completer<int>();
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [resposta], revogar: [null]);
      montar();
      await entrar();

      final saida = sessao.sair();
      await pumpEventQueue();
      expect(dispositivos.revogacoes, isEmpty);
      expect(autenticacao.saidas, 0);

      resposta.complete(12);
      await saida;
      expect(dispositivos.revogacoes, [12]);
      expect(autenticacao.saidas, 1);
    });

    test('o teto: com a API muda, a pessoa sai mesmo assim, em 15 s', () {
      fakeAsync((tempo) {
        notificacoes.permitido = true;
        dispositivos = DispositivosFalso(registrar: [12], revogar: [Completer<void>()]);
        montar();
        autenticacao.emitir(ana);
        tempo.flushMicrotasks();

        unawaited(sessao.sair());
        tempo.elapse(const Duration(seconds: 14));
        expect(autenticacao.saidas, 0);

        tempo.elapse(const Duration(seconds: 1));
        expect(autenticacao.saidas, 1);
        expect(sessao.estado, EstadoDaSessao.semSessao);
      });
    });

    test('dois toques em "Sair da conta": um DELETE só', () async {
      final revogacao = Completer<void>();
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12], revogar: [revogacao]);
      montar();
      await entrar();

      final primeira = sessao.sair();
      final segunda = sessao.sair();
      revogacao.complete();
      await Future.wait([primeira, segunda]);

      expect(dispositivos.revogacoes, [12]);
      expect(autenticacao.saidas, 1);
    });

    test('a resposta da conta que já saiu é descartada: o id dela não fica para a próxima', () async {
      final respostaDaAna = Completer<int>();
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [respostaDaAna, 21], revogar: [null]);
      montar(teto: Duration.zero);
      await entrar();

      // A API não responde a tempo: a Ana sai pelo teto, e o Bruno entra.
      await sessao.sair();
      notificacoes.tokenAtual = 'token-do-bruno';
      await entrar(bruno);
      respostaDaAna.complete(20);
      await pumpEventQueue();

      expect(dispositivos.registros, ['token-fcm-de-teste', 'token-do-bruno']);
      expect(lembretes.estado, EstadoDosLembretes.ativados);
      // O Bruno sai: o aparelho revogado é o dele, e não o da Ana.
      await sessao.sair();
      expect(dispositivos.revogacoes, [21]);
    });

    test('a revogação que descobre a sessão perdida não deixa o aviso para quem saiu por vontade própria', () async {
      final revogacao = Completer<void>();
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12], revogar: [revogacao]);
      montar();
      await entrar();

      final saida = sessao.sair();
      await pumpEventQueue();
      // Como o ApiClient faz ao ouvir `autenticar`: avisa a sessão perdida, e
      // o erro sobe para quem pediu.
      sessao.sessaoPerdida();
      revogacao.completeError(const ErroDaApi(status: 401, codigo: 'NAO_AUTENTICADO', mensagem: 'Faça login.'));
      await saida;
      await pumpEventQueue();

      expect(sessao.estado, EstadoDaSessao.semSessao);
      expect(sessao.motivoDaSaida, isNull);
    });

    test('sessão perdida: sem DELETE, que já não teria o token da conta; só o token do aparelho sai', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await entrar();

      sessao.sessaoPerdida();
      await pumpEventQueue();

      expect(dispositivos.revogacoes, isEmpty);
      expect(notificacoes.tokensApagados, 1);
    });
  });

  group('a explicação depois do cadastro', () {
    setUp(() => pacientes = RepositorioDoPacienteFalso(meu: [null]));

    Future<void> cadastrar() async {
      await entrar();
      expect(sessao.estado, EstadoDaSessao.semPerfil);
      sessao.perfilCadastrado(pacienteDeTeste());
      await pumpEventQueue();
    }

    test('sem a permissão: a explicação aparece', () async {
      montar();

      await cadastrar();

      expect(lembretes.explicacao, ExplicacaoDosLembretes.mostrar);
    });

    test('com a permissão já dada (Android 12 ou anterior): não aparece, e o aparelho é registrado', () async {
      notificacoes.permitido = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();

      await cadastrar();

      expect(lembretes.explicacao, ExplicacaoDosLembretes.nenhuma);
      expect(dispositivos.registros, hasLength(1));
    });

    test('quem só entra, já com perfil, não vê a explicação', () async {
      pacientes = RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]);
      montar();

      await entrar();

      expect(lembretes.explicacao, ExplicacaoDosLembretes.nenhuma);
    });

    test('a decisão fica: o "Permitir" não tira a tela antes de ela terminar', () async {
      notificacoes.concede = true;
      dispositivos = DispositivosFalso(registrar: [12]);
      montar();
      await cadastrar();

      expect(await lembretes.ativar(), ResultadoDaAtivacao.ativados);
      lembretes.aoVoltarAoAplicativo();
      await pumpEventQueue();
      expect(lembretes.explicacao, ExplicacaoDosLembretes.mostrar);

      lembretes.explicacaoConcluida();
      expect(lembretes.explicacao, ExplicacaoDosLembretes.nenhuma);
    });

    test('a permissão ainda não lida quando o cadastro acaba: decidindo, até a leitura', () async {
      final leitura = Completer<bool>();
      notificacoes.leituraNoAr = leitura;
      montar();

      await cadastrar();
      expect(lembretes.explicacao, ExplicacaoDosLembretes.decidindo);

      leitura.complete(false);
      await pumpEventQueue();
      expect(lembretes.explicacao, ExplicacaoDosLembretes.mostrar);
    });

    test('sair esquece a explicação', () async {
      montar();
      await cadastrar();

      await sessao.sair();

      expect(lembretes.explicacao, ExplicacaoDosLembretes.nenhuma);
    });
  });

  group('os toques', () {
    test('o lembrete que abriu o aplicativo: lido uma vez, e pendente até alguém abrir a consulta', () async {
      notificacoes.toqueInicial = lembreteDaConsulta(90);
      montar();
      await pumpEventQueue();

      expect(notificacoes.leiturasDoToqueInicial, 1);
      expect(lembretes.toquePendente?.consultaId, 90);
      expect(lembretes.consumirToque()?.consultaId, 90);
      expect(lembretes.toquePendente, isNull);
      expect(lembretes.consumirToque(), isNull);

      await entrar();
      await sessao.sair();
      await entrar();
      expect(notificacoes.leiturasDoToqueInicial, 1);
    });

    test('um toque com o aplicativo em segundo plano fica pendente; o último ganha', () async {
      montar();
      await pumpEventQueue();

      notificacoes
        ..tocar(lembreteDaConsulta(90))
        ..tocar(lembreteDaConsulta(91));
      await pumpEventQueue();

      expect(lembretes.consumirToque()?.consultaId, 91);
    });

    test('a mesma mensagem entregue duas vezes não abre a consulta duas vezes', () async {
      montar();
      await pumpEventQueue();

      notificacoes.tocar(lembreteDaConsulta(90, messageId: 'm1'));
      await pumpEventQueue();
      lembretes.consumirToque();
      notificacoes.tocar(lembreteDaConsulta(90, messageId: 'm1'));
      await pumpEventQueue();

      expect(lembretes.toquePendente, isNull);
    });
  });
}
