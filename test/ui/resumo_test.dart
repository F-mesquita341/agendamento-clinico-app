import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/ui/agendamento/resumo_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/resumo_view_model.dart';
import 'package:agendamento_clinico/ui/comum/espaco.dart';
import 'package:agendamento_clinico/ui/comum/textos.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/agenda.dart';
import '../apoio/falsos.dart';

/// Quinta-feira, 15/10/2026, às 14:30: o horário do resumo, com a versão 9.
final escolhido = horario(3, 15, 14, minuto: 30, versao: 9);
final hoje = DataCivil.naClinica(meioDiaDeQuarta);
final prazo = meioDiaDeQuarta.add(const Duration(minutes: 15));
final reservada = reservaDe(escolhido, expiraEm: prazo);

const conflito = ErroDaApi(
  status: 409,
  codigo: 'HORARIO_INDISPONIVEL',
  mensagem: 'Este horário acabou de ser reservado por outro paciente.',
  acao: AcaoSugerida.recarregarHorarios,
);
const sobreposta = ErroDaApi(
  status: 422,
  codigo: 'CONSULTA_SOBREPOSTA',
  mensagem: 'Você já tem uma consulta marcada nesse mesmo horário.',
);
const semConexao = ErroDaApi.semConexao();

ResumoViewModel resumo(ConsultasFalso consultas) =>
    ResumoViewModel(consultas, profissional: timbo, horario: escolhido, hoje: hoje);

/// As consultas da pessoa, numa página só.
Object nenhuma() => paginaDeConsultas([]);

void main() {
  group('resumo, no view model', () {
    test('reserva o horário da grade, com a versão que veio nela, e devolve a consulta', () async {
      final consultas = ConsultasFalso(agendar: [reservada]);

      final desfecho = await resumo(consultas).confirmar();

      expect(consultas.pedidosDeAgendar, [(horarioId: 3, versao: 9)]);
      expect(desfecho, isA<Reservada>().having((r) => r.consulta, 'consulta', same(reservada)));
      expect(consultas.pedidosDeMinhas, isEmpty);
    });

    test('enviando enquanto espera a API, e não depois', () async {
      final resposta = Completer<Consulta>();
      final vm = resumo(ConsultasFalso(agendar: [resposta]));

      final pedido = vm.confirmar();
      expect(vm.enviando, isTrue);

      resposta.complete(reservada);
      await pedido;
      expect(vm.enviando, isFalse);
    });

    test('dois toques, um pedido: o segundo, com o primeiro no ar, não faz nada', () async {
      final resposta = Completer<Consulta>();
      final consultas = ConsultasFalso(agendar: [resposta]);
      final vm = resumo(consultas);

      final primeiro = vm.confirmar();
      final segundo = await vm.confirmar();
      resposta.complete(reservada);

      expect(segundo, isNull);
      expect(await primeiro, isA<Reservada>());
      expect(consultas.pedidosDeAgendar, hasLength(1));
    });

    test('a colisão do lock otimista vira Conflito, com a mensagem da API', () async {
      final consultas = ConsultasFalso(agendar: [conflito]);
      final vm = resumo(consultas);

      final desfecho = await vm.confirmar();

      expect(desfecho, isA<Conflito>().having((c) => c.erro.mensagem, 'mensagem', conflito.mensagem));
      expect(vm.erro, isNull);
      // Ninguém tentou antes: não há reserva da própria pessoa a procurar.
      expect(consultas.pedidosDeMinhas, isEmpty);
    });

    test('a decisão é pela ação, e não pelo código: 409 sem a ação fica no resumo, com a mensagem', () async {
      const semAcao = ErroDaApi(status: 409, codigo: 'OUTRO_CONFLITO', mensagem: 'Outro conflito.');
      final vm = resumo(ConsultasFalso(agendar: [semAcao]));

      expect(await vm.confirmar(), isNull);
      expect(vm.erro, 'Outro conflito.');
    });

    test('e a ação de recarregar, com outro código, é conflito', () async {
      const outroCodigo = ErroDaApi(
        status: 422,
        codigo: 'HORARIO_MUDOU',
        mensagem: 'O horário mudou.',
        acao: AcaoSugerida.recarregarHorarios,
      );

      expect(await resumo(ConsultasFalso(agendar: [outroCodigo])).confirmar(), isA<Conflito>());
    });

    test('recusa sem ação — consulta no mesmo horário — fica no resumo, com a mensagem da API', () async {
      final consultas = ConsultasFalso(agendar: [sobreposta]);
      final vm = resumo(consultas);

      expect(await vm.confirmar(), isNull);
      expect(vm.erro, 'Você já tem uma consulta marcada nesse mesmo horário.');
      // A API recusou: com certeza não reservou, e não há o que conferir.
      expect(consultas.pedidosDeMinhas, isEmpty);
    });

    test('tentar de novo tira a mensagem da recusa anterior enquanto envia', () async {
      final resposta = Completer<Consulta>();
      final vm = resumo(ConsultasFalso(agendar: [sobreposta, resposta]));
      await vm.confirmar();

      final pedido = vm.confirmar();
      expect(vm.erro, isNull);
      resposta.complete(reservada);
      await pedido;
    });

    group('resposta perdida', () {
      test('sem conexão: confere as consultas, e a reserva que está lá segue para o pagamento', () async {
        final naLista = reservaDe(escolhido, expiraEm: prazo, id: 77, comHorario: true);
        final consultas = ConsultasFalso(agendar: [semConexao], minhas: [paginaDeConsultas([naLista])]);

        final desfecho = await resumo(consultas).confirmar();

        expect(desfecho, isA<Reservada>().having((r) => r.consulta.id, 'id', 77));
        expect(consultas.pedidosDeMinhas, [1]);
      });

      test('sem conexão e sem a reserva na lista: o erro original, e o próximo toque confere antes de enviar', () async {
        final consultas = ConsultasFalso(agendar: [semConexao, reservada], minhas: [nenhuma(), nenhuma()]);
        final vm = resumo(consultas);

        expect(await vm.confirmar(), isNull);
        expect(vm.erro, semConexao.mensagem);
        expect(consultas.pedidosDeMinhas, hasLength(1));

        expect(await vm.confirmar(), isA<Reservada>());
        expect(consultas.pedidosDeMinhas, hasLength(2));
        expect(consultas.pedidosDeAgendar, hasLength(2));
      });

      test('o próximo toque que acha a reserva não envia de novo', () async {
        final naLista = reservaDe(escolhido, expiraEm: prazo, comHorario: true);
        final consultas = ConsultasFalso(
          agendar: [semConexao],
          minhas: [semConexao, paginaDeConsultas([naLista])],
        );
        final vm = resumo(consultas);
        await vm.confirmar();

        expect(await vm.confirmar(), isA<Reservada>());
        expect(consultas.pedidosDeAgendar, hasLength(1));
      });

      test('resposta fora do formato e falha no servidor também deixam a dúvida', () async {
        for (final erro in [
          const ErroDaApi.respostaInesperada(200),
          const ErroDaApi(status: 500, codigo: 'ERRO_INTERNO', mensagem: 'Erro interno.'),
        ]) {
          final consultas = ConsultasFalso(agendar: [erro], minhas: [nenhuma()]);

          await resumo(consultas).confirmar();

          expect(consultas.pedidosDeMinhas, [1], reason: erro.codigo);
        }
      });

      test('a consulta cancelada do mesmo horário não é a reserva', () async {
        final cancelada = reservaDe(escolhido, expiraEm: prazo, status: StatusDaConsulta.cancelada, comHorario: true);
        final consultas = ConsultasFalso(agendar: [semConexao], minhas: [paginaDeConsultas([cancelada])]);
        final vm = resumo(consultas);

        expect(await vm.confirmar(), isNull);
        expect(vm.erro, semConexao.mensagem);
      });

      test('a conferência que falha diz que não deu para confirmar', () async {
        final vm = resumo(ConsultasFalso(agendar: [semConexao], minhas: [semConexao]));

        expect(await vm.confirmar(), isNull);
        expect(vm.erro, 'Não foi possível confirmar se o horário foi reservado. ${semConexao.mensagem}');
      });

      test('409 depois da dúvida é conferido: a reserva da própria pessoa não é conflito', () async {
        final naLista = reservaDe(escolhido, expiraEm: prazo, comHorario: true);
        final consultas = ConsultasFalso(
          agendar: [semConexao, conflito],
          minhas: [nenhuma(), nenhuma(), paginaDeConsultas([naLista])],
        );
        final vm = resumo(consultas);
        await vm.confirmar();

        expect(await vm.confirmar(), isA<Reservada>());
        expect(consultas.pedidosDeMinhas, hasLength(3));
      });

      test('409 depois da dúvida, sem a reserva na lista: é conflito', () async {
        final consultas = ConsultasFalso(agendar: [semConexao, conflito], minhas: [nenhuma(), nenhuma(), nenhuma()]);
        final vm = resumo(consultas);
        await vm.confirmar();

        expect(await vm.confirmar(), isA<Conflito>());
      });

      test('olha a página seguinte enquanto a lista ainda está em consultas mais adiante', () async {
        final depois = reservaDe(horario(8, 20, 9), expiraEm: prazo, id: 60, comHorario: true);
        final naLista = reservaDe(escolhido, expiraEm: prazo, comHorario: true);
        final consultas = ConsultasFalso(
          agendar: [semConexao],
          minhas: [
            paginaDeConsultas([depois], paginas: 2),
            paginaDeConsultas([naLista], pagina: 2, paginas: 2),
          ],
        );

        expect(await resumo(consultas).confirmar(), isA<Reservada>());
        expect(consultas.pedidosDeMinhas, [1, 2]);
      });

      test('para quando a lista chega a consultas antes do horário', () async {
        final antes = reservaDe(horario(8, 14, 9), expiraEm: prazo, id: 60, comHorario: true);
        final consultas = ConsultasFalso(agendar: [semConexao], minhas: [paginaDeConsultas([antes], paginas: 9)]);

        await resumo(consultas).confirmar();

        expect(consultas.pedidosDeMinhas, [1]);
      });

      test('e não passa da quinta página', () async {
        final depois = reservaDe(horario(8, 20, 9), expiraEm: prazo, id: 60, comHorario: true);
        final consultas = ConsultasFalso(
          agendar: [semConexao],
          minhas: [for (var p = 1; p <= 9; p++) paginaDeConsultas([depois], pagina: p, paginas: 9)],
        );

        await resumo(consultas).confirmar();

        expect(consultas.pedidosDeMinhas, [1, 2, 3, 4, 5]);
      });
    });

    test('a resposta que chega depois de a tela fechar não avisa ninguém', () async {
      final resposta = Completer<Consulta>();
      final vm = resumo(ConsultasFalso(agendar: [resposta]));

      final pedido = vm.confirmar();
      vm.dispose();
      resposta.complete(reservada);

      expect(await pedido, isA<Reservada>());
    });
  });

  group('resumo, na tela', () {
    late List<Object?> desfechos;

    /// Uma tela por baixo, que abre o resumo e guarda como ele terminou.
    Future<ConsultasFalso> abrir(WidgetTester tester, ConsultasFalso consultas, {Size tela = const Size(411, 900)}) async {
      tester.view.physicalSize = tela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      desfechos = [];
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<RepositorioDeConsultas>.value(value: consultas),
          Provider<RepositorioDoCatalogo>.value(value: CatalogoFalso()),
          Provider<AbridorDeLinks>.value(value: AbridorDeLinksFalso()),
        ],
        child: MaterialApp(
          theme: temaDoApp(),
          home: Builder(
            builder: (contexto) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () async => desfechos.add(await Navigator.of(contexto).push(
                    rotaDoResumo(timbo, escolhido, hoje: hoje, relogio: () => meioDiaDeQuarta),
                  )),
                  child: const Text('Abrir o resumo'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Abrir o resumo'));
      await tester.pumpAndSettle();
      return consultas;
    }

    Finder confirmar() => find.text('Confirmar e ir para o pagamento');

    testWidgets('a etapa, a consulta inteira, a reserva de 15 minutos e o pagamento antecipado', (tester) async {
      await abrir(tester, ConsultasFalso());

      expect(find.text('Resumo da consulta'), findsOneWidget);
      expect(find.text('Etapa 2 de 3'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 14:30'), findsOneWidget);
      expect(find.text('Centro, Quixadá - CE'), findsOneWidget);
      expect(
        find.text('Ao confirmar, o horário fica reservado para você por 15 minutos, enquanto você faz o pagamento.'),
        findsOneWidget,
      );
      expect(find.text('O pagamento antecipado garante o seu horário.'), findsOneWidget);
      expect(confirmar(), findsOneWidget);
      expect(find.textContaining(RegExp('cau[çc][ãa]o', caseSensitive: false)), findsNothing);
    });

    testWidgets('enviando, o botão trava e diz o que está fazendo', (tester) async {
      final resposta = Completer<Consulta>();
      final consultas = await abrir(tester, ConsultasFalso(agendar: [resposta]));

      await tester.tap(confirmar());
      await tester.pump();

      expect(find.text('Reservando o horário…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
      await tester.tap(find.byType(FilledButton), warnIfMissed: false);
      expect(consultas.pedidosDeAgendar, hasLength(1));

      resposta.complete(reservada);
      await tester.pumpAndSettle();
    });

    testWidgets('enviando, voltar fica bloqueado; depois da recusa, volta', (tester) async {
      final resposta = Completer<Consulta>();
      await abrir(tester, ConsultasFalso(agendar: [resposta]));
      await tester.tap(confirmar());
      await tester.pump();

      // O indicador do botão gira sem parar: nada de esperar a tela assentar.
      await tester.pageBack();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resumo da consulta'), findsOneWidget);

      resposta.completeError(sobreposta);
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Resumo da consulta'), findsNothing);
      expect(desfechos, [null]);
    });

    testWidgets('a recusa sem ação aparece acima do botão, com a mensagem da API', (tester) async {
      await abrir(tester, ConsultasFalso(agendar: [sobreposta]));

      await tester.tap(confirmar());
      await tester.pumpAndSettle();

      final aviso = find.text('Você já tem uma consulta marcada nesse mesmo horário.');
      expect(aviso, findsOneWidget);
      expect(tester.getRect(aviso).bottom, lessThan(tester.getRect(confirmar()).top));
      expect(find.text('Resumo da consulta'), findsOneWidget);
    });

    testWidgets('servidor demorando: o aviso aparece, e some com a resposta', (tester) async {
      final resposta = Completer<Consulta>();
      await abrir(tester, ConsultasFalso(agendar: [resposta]));
      await tester.tap(confirmar());
      await tester.pump();

      expect(find.text(Textos.servidorDemorando), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      expect(find.text(Textos.servidorDemorando), findsOneWidget);

      resposta.completeError(sobreposta);
      await tester.pumpAndSettle();
      expect(find.text(Textos.servidorDemorando), findsNothing);
    });

    testWidgets('conflito: o resumo fecha e entrega o conflito a quem o abriu', (tester) async {
      await abrir(tester, ConsultasFalso(agendar: [conflito]));

      await tester.tap(confirmar());
      await tester.pumpAndSettle();

      expect(find.text('Resumo da consulta'), findsNothing);
      expect(desfechos.single, isA<Conflito>());
    });

    testWidgets('reservado: o pagamento abre no lugar do resumo, e voltar dali não leva ao resumo', (tester) async {
      await abrir(tester, ConsultasFalso(agendar: [reservada]));

      await tester.tap(confirmar());
      await tester.pumpAndSettle();

      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.text('Etapa 3 de 3'), findsOneWidget);

      // Sair sem pagar pergunta antes (Etapa 15).
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.text('Resumo da consulta'), findsNothing);
      expect(find.text('Abrir o resumo'), findsOneWidget);
    });

    testWidgets('toque, rótulos e contraste, com e sem a recusa', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrir(tester, ConsultasFalso(agendar: [sobreposta]));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(confirmar());
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('a 200%, numa tela pequena, nada estoura: o botão vai para o fim da lista, com o aviso', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester, ConsultasFalso(agendar: [sobreposta]), tela: const Size(320, 640));

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();
      await tester.tap(confirmar());
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(confirmar().hitTestable(), findsOneWidget);
      // Na fonte dos testes, bem mais larga que a de verdade, os dois não cabem
      // juntos na tela; o que vale é o aviso logo acima do botão, na lista.
      final aviso = tester.getRect(find.text('Você já tem uma consulta marcada nesse mesmo horário.'));
      expect(aviso.bottom, lessThan(tester.getRect(confirmar()).top));
      expect(tester.getRect(confirmar()).top - aviso.bottom, lessThan(Espaco.grande * 2));
    });
  });
}
