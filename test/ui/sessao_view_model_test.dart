import 'dart:async';
import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/paciente.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../apoio/falsos.dart';

/// A guarda de rota da Etapa 12: de onde o paciente está na conta sai a tela.
void main() {
  late AutenticacaoFalsa autenticacao;

  SessaoViewModel sessao(RepositorioDoPaciente pacientes) =>
      SessaoViewModel(autenticacao: autenticacao, pacientes: pacientes)..iniciar();

  setUp(() => autenticacao = AutenticacaoFalsa());

  test('começa iniciando, até o provedor dizer se há sessão', () {
    expect(sessao(RepositorioDoPacienteFalso()).estado, EstadoDaSessao.iniciando);
  });

  test('sem sessão: tela de entrar', () async {
    final vm = sessao(RepositorioDoPacienteFalso());

    autenticacao.emitir(null);
    await pumpEventQueue();

    expect(vm.estado, EstadoDaSessao.semSessao);
  });

  test('com sessão e perfil: o aplicativo, com o perfil carregado', () async {
    final perfil = pacienteDeTeste();
    final vm = sessao(RepositorioDoPacienteFalso(meu: [perfil]));

    autenticacao.emitir(ana);
    await pumpEventQueue();

    expect(vm.estado, EstadoDaSessao.comPerfil);
    expect(vm.paciente, same(perfil));
    expect(vm.usuario?.uid, ana.uid);
  });

  test('com sessão e sem perfil: termo e cadastro', () async {
    final vm = sessao(RepositorioDoPacienteFalso(meu: [null]));

    autenticacao.emitir(ana);
    await pumpEventQueue();

    expect(vm.estado, EstadoDaSessao.semPerfil);
  });

  test('falha ao carregar o perfil deixa tentar de novo', () async {
    final pacientes = RepositorioDoPacienteFalso(meu: [const ErroDaApi.semConexao(), pacienteDeTeste()]);
    final vm = sessao(pacientes);

    autenticacao.emitir(ana);
    await pumpEventQueue();
    expect(vm.estado, EstadoDaSessao.falhou);
    expect(vm.erro?.codigo, 'SEM_CONEXAO');

    await vm.carregarPerfil();
    expect(vm.estado, EstadoDaSessao.comPerfil);
    expect(pacientes.respostasDeMeu.chamadas, 2);
  });

  test('defeito do aplicativo não deixa a sessão presa carregando, e é relatado', () async {
    final relatados = <FlutterErrorDetails>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = relatados.add;
    addTearDown(() => FlutterError.onError = anterior);

    final vm = sessao(RepositorioDoPacienteFalso(meu: [StateError('defeito de teste')]));
    autenticacao.emitir(ana);
    await pumpEventQueue();

    expect(relatados.single.exception, isA<StateError>());
    expect(vm.estado, EstadoDaSessao.falhou);
    expect(vm.erro?.codigo, 'FALHA_NO_APLICATIVO');
  });

  test('servidor demorando: depois de 4 s carregando o perfil, avisa', () {
    fakeAsync((tempo) {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [Completer<Paciente?>()]));
      autenticacao.emitir(ana);
      tempo.flushMicrotasks();

      tempo.elapse(const Duration(seconds: 3));
      expect(vm.demorando, isFalse);
      tempo.elapse(const Duration(seconds: 2));
      expect(vm.demorando, isTrue);
      expect(vm.estado, EstadoDaSessao.carregandoPerfil);
    });
  });

  test('perfil que chega depois de a conta trocar é descartado', () async {
    final perfilDaAna = Completer<Paciente?>();
    final perfilDoBruno = pacienteDeTeste(nome: 'Bruno Sá', email: 'bruno@exemplo.test');
    final vm = sessao(RepositorioDoPacienteFalso(meu: [perfilDaAna, perfilDoBruno]));

    autenticacao.emitir(ana);
    await pumpEventQueue();
    autenticacao.emitir(null);
    autenticacao.emitir(bruno);
    await pumpEventQueue();
    expect(vm.paciente?.nome, 'Bruno Sá');

    // A resposta da Ana chega atrasada: não pode tomar a sessão do Bruno.
    perfilDaAna.complete(pacienteDeTeste(nome: 'Ana Lima'));
    await pumpEventQueue();

    expect(vm.paciente?.nome, 'Bruno Sá');
    expect(vm.usuario?.uid, bruno.uid);
  });

  test('perfil que chega depois de sair é descartado', () async {
    final perfil = Completer<Paciente?>();
    final vm = sessao(RepositorioDoPacienteFalso(meu: [perfil]));

    autenticacao.emitir(ana);
    await pumpEventQueue();
    await vm.sair();
    await pumpEventQueue();
    perfil.complete(pacienteDeTeste());
    await pumpEventQueue();

    expect(vm.estado, EstadoDaSessao.semSessao);
    expect(vm.paciente, isNull);
  });

  test('o mesmo usuário avisado de novo não recarrega o perfil', () async {
    final pacientes = RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]);
    final vm = sessao(pacientes);

    autenticacao.emitir(ana);
    await pumpEventQueue();
    autenticacao.emitir(ana);
    await pumpEventQueue();

    expect(pacientes.respostasDeMeu.chamadas, 1);
    expect(vm.estado, EstadoDaSessao.comPerfil);
  });

  test('cadastro concluído leva ao aplicativo sem nova carga', () async {
    final pacientes = RepositorioDoPacienteFalso(meu: [null]);
    final vm = sessao(pacientes);
    autenticacao.emitir(ana);
    await pumpEventQueue();

    vm.perfilCadastrado(pacienteDeTeste());

    expect(vm.estado, EstadoDaSessao.comPerfil);
    expect(pacientes.respostasDeMeu.chamadas, 1);
  });

  group('falhas do provedor', () {
    late List<FlutterErrorDetails> relatados;

    setUp(() {
      relatados = [];
      final anterior = FlutterError.onError;
      FlutterError.onError = relatados.add;
      addTearDown(() => FlutterError.onError = anterior);
    });

    test('sair que falha no provedor é relatado, e não escapa como erro solto', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]));
      autenticacao.emitir(ana);
      await pumpEventQueue();
      autenticacao.erroAoSair = StateError('provedor fora do ar');

      await vm.sair();

      expect(relatados.single.exception, isA<StateError>());
    });

    test('sessão perdida com saída que falha: relatada, e a tela já está na entrada', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]));
      autenticacao.emitir(ana);
      await pumpEventQueue();
      autenticacao.erroAoSair = StateError('provedor fora do ar');

      vm.sessaoPerdida();
      await pumpEventQueue();

      expect(vm.estado, EstadoDaSessao.semSessao);
      expect(relatados.single.exception, isA<StateError>());
    });

    test('erro no fluxo de mudanças de sessão é relatado, e a sessão continua ouvindo', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]));

      autenticacao.emitirErro(StateError('fluxo com defeito'));
      await pumpEventQueue();
      autenticacao.emitir(ana);
      await pumpEventQueue();

      expect(relatados.single.exception, isA<StateError>());
      expect(vm.estado, EstadoDaSessao.comPerfil);
    });
  });

  group('sessão perdida', () {
    test('vai para a tela de entrar já, com o motivo, e encerra a sessão no provedor', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]));
      autenticacao.emitir(ana);
      await pumpEventQueue();

      vm.sessaoPerdida();

      expect(vm.estado, EstadoDaSessao.semSessao);
      expect(vm.paciente, isNull);
      expect(vm.motivoDaSaida, 'Sua sessão terminou. Entre de novo para continuar.');
      await pumpEventQueue();
      expect(autenticacao.saidas, 1);
      // O provedor confirma a saída; o motivo continua na tela.
      expect(vm.motivoDaSaida, isNotNull);
    });

    test('o motivo some quando a pessoa entra de novo', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste(), pacienteDeTeste()]));
      autenticacao.emitir(ana);
      await pumpEventQueue();
      vm.sessaoPerdida();
      await pumpEventQueue();

      autenticacao.emitir(ana);
      await pumpEventQueue();

      expect(vm.motivoDaSaida, isNull);
      expect(vm.estado, EstadoDaSessao.comPerfil);
    });

    test('sair por vontade própria não mostra motivo', () async {
      final vm = sessao(RepositorioDoPacienteFalso(meu: [pacienteDeTeste()]));
      autenticacao.emitir(ana);
      await pumpEventQueue();

      await vm.sair();
      await pumpEventQueue();

      expect(vm.estado, EstadoDaSessao.semSessao);
      expect(vm.motivoDaSaida, isNull);
    });

    test('ponta a ponta: a API diz autenticar, e o paciente volta à tela de entrar', () async {
      late final SessaoViewModel vm;
      final api = ApiClient(
        cliente: MockClient((_) async => http.Response.bytes(
              utf8.encode(jsonEncode({
                'erro': {'codigo': 'NAO_AUTENTICADO', 'mensagem': 'Faça login.', 'acao': 'autenticar'},
              })),
              401,
            )),
        base: Uri.parse('https://api.exemplo.test'),
        token: autenticacao.token,
        aoPerderSessao: () => vm.sessaoPerdida(),
      );
      vm = sessao(RepositorioDoPacienteRemoto(api));

      autenticacao.emitir(ana);
      await pumpEventQueue();

      expect(vm.estado, EstadoDaSessao.semSessao);
      expect(vm.motivoDaSaida, isNotNull);
      expect(autenticacao.saidas, 1);
    });
  });
}
