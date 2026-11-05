import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/forma_de_pagamento.dart';
import 'package:agendamento_clinico/domain/models/plano.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/agendamento/cartao_da_consulta.dart';
import 'package:agendamento_clinico/ui/agendamento/consulta_confirmada_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/resumo_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/resumo_view_model.dart';
import 'package:agendamento_clinico/ui/consultas/regras_de_cancelamento.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_view_model.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:agendamento_clinico/ui/shell/abas_do_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/acessibilidade.dart';
import '../apoio/agenda.dart';
import '../apoio/falsos.dart';

/// Quinta-feira, 15/10/2026, às 14:30, com a versão 9.
final escolhido = horario(3, 15, 14, minuto: 30, versao: 9);
final hoje = DataCivil.naClinica(meioDiaDeQuarta);

const unimed = Plano(id: 3, nome: 'Unimed');
const hapvida = Plano(id: 4, nome: 'Hapvida');

Profissional comFormas(List<FormaDePagamento> formas, {List<Plano> planos = const [unimed, hapvida]}) => Profissional(
  id: timbo.id,
  nome: timbo.nome,
  registroConselho: timbo.registroConselho,
  valorFormatado: timbo.valorFormatado,
  especialidade: timbo.especialidade,
  clinica: timbo.clinica,
  planos: planos,
  formasDePagamento: formas,
);

final asTres = comFormas(const [FormaDePagamento.app, FormaDePagamento.plano, FormaDePagamento.clinica]);

/// A consulta como a API a devolve confirmada na hora.
Consulta confirmadaCom(FormaDePagamento forma, {Plano? plano}) => Consulta(
  id: 60,
  status: StatusDaConsulta.confirmada,
  horarioId: escolhido.id,
  valorFormatado: 'R\$ 250,00',
  formaDePagamento: forma,
  plano: plano,
);

ResumoViewModel resumo(ConsultasFalso consultas, Profissional profissional, {int? planoPreferido}) => ResumoViewModel(
  consultas,
  profissional: profissional,
  horario: escolhido,
  hoje: hoje,
  planoPreferido: planoPreferido,
);

void main() {
  group('a forma, no view model do resumo', () {
    test('quem só aceita o aplicativo: sem pergunta, como na v1', () async {
      final consultas = ConsultasFalso(agendar: [reservaDe(escolhido, expiraEm: meioDiaDeQuarta)]);
      final vm = resumo(consultas, timbo);

      expect(vm.pergunta, isFalse);
      expect(vm.forma, FormaDePagamento.app);
      expect(vm.podeConfirmar, isTrue);
      expect(vm.etapas, 3);

      expect(await vm.confirmar(), isA<Reservada>());
      expect(consultas.formasDosAgendamentos, [(forma: FormaDePagamento.app, planoId: null)]);
    });

    test('com várias formas, nenhuma vem marcada, e não se confirma antes de escolher', () async {
      final consultas = ConsultasFalso();
      final vm = resumo(consultas, asTres);

      expect(vm.pergunta, isTrue);
      expect(vm.forma, isNull);
      expect(vm.podeConfirmar, isFalse);
      expect(vm.etapas, 3, reason: 'o aplicativo é possível');

      expect(await vm.confirmar(), isNull);
      expect(consultas.pedidosDeAgendar, isEmpty);
    });

    test('na clínica: duas etapas, e a consulta confirmada vai à confirmação', () async {
      final consultas = ConsultasFalso(agendar: [confirmadaCom(FormaDePagamento.clinica)]);
      final vm = resumo(consultas, asTres)..escolherForma(FormaDePagamento.clinica);

      expect(vm.etapas, 2);
      expect(vm.podeConfirmar, isTrue);
      expect(await vm.confirmar(), isA<Confirmada>());
      expect(consultas.formasDosAgendamentos, [(forma: FormaDePagamento.clinica, planoId: null)]);
    });

    test('na clínica, o plano do filtro não vai no pedido (a API recusaria o planoId)', () async {
      final consultas = ConsultasFalso(agendar: [confirmadaCom(FormaDePagamento.clinica)]);
      final vm = resumo(consultas, asTres, planoPreferido: 4)..escolherForma(FormaDePagamento.clinica);
      expect(vm.planoId, 4, reason: 'o plano do filtro continua marcado, caso a pessoa volte ao plano');

      await vm.confirmar();

      expect(consultas.formasDosAgendamentos, [(forma: FormaDePagamento.clinica, planoId: null)]);
    });

    test('pelo plano: sem plano escolhido não confirma; com ele, o plano vai no pedido', () async {
      final consultas = ConsultasFalso(agendar: [confirmadaCom(FormaDePagamento.plano, plano: hapvida)]);
      final vm = resumo(consultas, asTres)..escolherForma(FormaDePagamento.plano);

      expect(vm.planoId, isNull);
      expect(vm.podeConfirmar, isFalse);
      vm.escolherPlano(4);
      expect(vm.podeConfirmar, isTrue);

      expect(await vm.confirmar(), isA<Confirmada>());
      expect(consultas.formasDosAgendamentos, [(forma: FormaDePagamento.plano, planoId: 4)]);
    });

    test('o plano do filtro da Busca vem marcado, se o profissional o aceita', () {
      expect(resumo(ConsultasFalso(), asTres, planoPreferido: 4).planoId, 4);
      expect(resumo(ConsultasFalso(), asTres, planoPreferido: 9).planoId, isNull);
    });

    test('com um plano só, ele vem marcado', () {
      final umPlano = comFormas(const [FormaDePagamento.app, FormaDePagamento.plano], planos: const [unimed]);

      expect(resumo(ConsultasFalso(), umPlano).planoId, 3);
    });

    test('sem o aplicativo: duas etapas desde o começo; com uma forma só, ela vem marcada', () {
      final semApp = resumo(ConsultasFalso(), comFormas(const [FormaDePagamento.plano, FormaDePagamento.clinica]));
      expect(semApp.etapas, 2);
      expect(semApp.forma, isNull);

      final soClinica = resumo(ConsultasFalso(), comFormas(const [FormaDePagamento.clinica]));
      expect(soClinica.forma, FormaDePagamento.clinica);
      expect(soClinica.pergunta, isTrue);
    });

    test('o plano sem nenhum plano cadastrado não é oferecido', () {
      final vm = resumo(
        ConsultasFalso(),
        comFormas(const [FormaDePagamento.app, FormaDePagamento.plano, FormaDePagamento.clinica], planos: const []),
      );

      expect(vm.formasOferecidas, [FormaDePagamento.app, FormaDePagamento.clinica]);
      vm.escolherForma(FormaDePagamento.plano);
      expect(vm.forma, isNull);
    });

    test('a recusa da forma mostra a mensagem da API e mantém a escolha; trocar a escolha a apaga', () async {
      const recusa = ErroDaApi(
        status: 422,
        codigo: 'PLANO_NAO_ACEITO',
        mensagem: 'Este profissional não atende por esse plano. Escolha outro plano ou outra forma de pagamento.',
      );
      final consultas = ConsultasFalso(agendar: [recusa]);
      final vm = resumo(consultas, asTres, planoPreferido: 3)..escolherForma(FormaDePagamento.plano);

      expect(await vm.confirmar(), isNull);
      expect(vm.erro, recusa.mensagem);
      expect(vm.forma, FormaDePagamento.plano);
      // Recusa sem resposta perdida: nada a conferir nas consultas.
      expect(consultas.pedidosDeMinhas, isEmpty);

      vm.escolherForma(FormaDePagamento.clinica);
      expect(vm.erro, isNull);
    });

    test(
      'resposta perdida: a consulta confirmada achada nas consultas vai à confirmação, e não ao pagamento',
      () async {
        final achada = Consulta(
          id: 61,
          status: StatusDaConsulta.confirmada,
          horarioId: escolhido.id,
          valorFormatado: 'R\$ 250,00',
          horario: escolhido,
          formaDePagamento: FormaDePagamento.clinica,
        );
        final consultas = ConsultasFalso(
          agendar: [const ErroDaApi.semConexao()],
          minhas: [
            paginaDeConsultas([achada]),
          ],
        );
        final vm = resumo(consultas, asTres)..escolherForma(FormaDePagamento.clinica);

        final desfecho = await vm.confirmar();

        expect(desfecho, isA<Confirmada>().having((c) => c.consulta.id, 'id', 61));
      },
    );
  });

  group('a forma, nas telas', () {
    late List<Object?> desfechos;

    Future<ConsultasFalso> abrir(
      WidgetTester tester,
      ConsultasFalso consultas,
      Profissional profissional, {
      int? planoPreferido,
      Size tela = const Size(411, 1000),
    }) async {
      tester.view.physicalSize = tela;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      desfechos = [];
      final abas = AbasDoShell();
      addTearDown(abas.dispose);
      final sessao = SessaoViewModel(autenticacao: AutenticacaoFalsa(), pacientes: RepositorioDoPacienteFalso());
      addTearDown(sessao.dispose);
      final lembretes = LembretesViewModel(
        notificacoes: NotificacoesFalsas(),
        dispositivos: DispositivosFalso(),
        sessao: sessao,
      )..iniciar();
      addTearDown(lembretes.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<RepositorioDeConsultas>.value(value: consultas),
            Provider<RepositorioDoCatalogo>.value(value: CatalogoFalso()),
            Provider<AbridorDeLinks>.value(value: AbridorDeLinksFalso()),
            ChangeNotifierProvider<AbasDoShell>.value(value: abas),
            ChangeNotifierProvider<LembretesViewModel>.value(value: lembretes),
          ],
          child: MaterialApp(
            theme: temaDoApp(),
            home: Builder(
              builder: (contexto) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () async => desfechos.add(
                      await Navigator.of(contexto).push(
                        rotaDoResumo(
                          profissional,
                          escolhido,
                          hoje: hoje,
                          relogio: () => meioDiaDeQuarta,
                          planoPreferido: planoPreferido,
                        ),
                      ),
                    ),
                    child: const Text('Abrir o resumo'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir o resumo'));
      await tester.pumpAndSettle();
      return consultas;
    }

    FilledButton botao(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));
    const notaDaReserva =
        'Ao confirmar, o horário fica reservado para você por 15 minutos, enquanto você faz o pagamento.';

    testWidgets('quem só aceita o aplicativo vê o resumo de sempre, sem a pergunta', (tester) async {
      await abrir(tester, ConsultasFalso(), timbo);

      expect(find.text('Como você vai pagar?'), findsNothing);
      expect(find.text('Etapa 2 de 3'), findsOneWidget);
      expect(find.text(notaDaReserva), findsOneWidget);
      expect(find.text('Confirmar e ir para o pagamento'), findsOneWidget);
    });

    testWidgets('com várias formas: a pergunta, nada marcado, o botão desativado e sem a nota da reserva', (
      tester,
    ) async {
      await abrir(tester, ConsultasFalso(), asTres);

      expect(find.text('Como você vai pagar?'), findsOneWidget);
      expect(find.text('Pelo aplicativo, agora'), findsOneWidget);
      expect(find.text('Pelo plano de saúde'), findsOneWidget);
      expect(find.text('Na clínica, no dia da consulta'), findsOneWidget);
      expect(find.text('Escolha como pagar'), findsOneWidget);
      expect(botao(tester).onPressed, isNull);
      expect(find.text('Etapa 2 de 3'), findsOneWidget);
      // A lista só constrói o que está perto da vista: até o fim dela, para a
      // ausência da nota valer.
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();
      expect(find.text('Na clínica, no dia da consulta'), findsOneWidget, reason: 'o fim da lista está à vista');
      expect(find.text(notaDaReserva), findsNothing);
      expect(find.text('O pagamento antecipado garante o seu horário.'), findsNothing);
    });

    testWidgets('na clínica, sem a nota da reserva nem o pagamento antecipado', (tester) async {
      await abrir(tester, ConsultasFalso(), asTres);

      await tester.tap(find.text('Na clínica, no dia da consulta'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, -2000));
      await tester.pumpAndSettle();

      expect(find.text('Na clínica, no dia da consulta'), findsOneWidget, reason: 'o fim da lista está à vista');
      expect(find.text(notaDaReserva), findsNothing);
      expect(find.text('O pagamento antecipado garante o seu horário.'), findsNothing);
    });

    testWidgets('escolher o aplicativo traz a nota da reserva e o pagamento antecipado', (tester) async {
      await abrir(tester, ConsultasFalso(), asTres);

      await tester.tap(find.text('Pelo aplicativo, agora'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('O pagamento antecipado garante o seu horário.'), 200);

      expect(find.text(notaDaReserva), findsOneWidget);
      expect(find.text('O pagamento antecipado garante o seu horário.'), findsOneWidget);
      expect(find.text('Confirmar e ir para o pagamento'), findsOneWidget);
    });

    testWidgets('na clínica: "Etapa 2 de 2", "Confirmar consulta", e a confirmação diz a forma', (tester) async {
      final consultas = await abrir(tester, ConsultasFalso(agendar: [confirmadaCom(FormaDePagamento.clinica)]), asTres);

      await tester.tap(find.text('Na clínica, no dia da consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Etapa 2 de 2'), findsOneWidget);
      await tester.tap(find.text('Confirmar consulta'));
      await tester.pumpAndSettle();

      expect(consultas.formasDosAgendamentos.single.forma, FormaDePagamento.clinica);
      expect(find.byType(ConsultaConfirmadaScreen), findsOneWidget);
      expect(find.text('O pagamento é feito na clínica, no dia da consulta.'), findsOneWidget);
      expect(find.text('Recebemos a confirmação do pagamento.'), findsNothing);
      // Na clínica, o valor é o que a pessoa vai pagar lá: ele fica.
      expect(find.text('Valor da consulta'), findsOneWidget);
    });

    testWidgets('pelo plano: os planos aparecem, o do filtro já marcado, e a confirmação diz qual', (tester) async {
      final consultas = await abrir(
        tester,
        ConsultasFalso(agendar: [confirmadaCom(FormaDePagamento.plano, plano: hapvida)]),
        asTres,
        planoPreferido: 4,
      );

      expect(find.text('Valor da consulta'), findsOneWidget, reason: 'antes de escolher, o valor aparece');
      await tester.tap(find.text('Pelo plano de saúde'));
      await tester.pumpAndSettle();
      expect(find.text('Qual o seu plano?'), findsOneWidget);
      expect(find.text('Unimed'), findsOneWidget);
      expect(find.text('Confirmar consulta'), findsOneWidget);
      // Pelo plano, a consulta é acertada com o plano, na clínica: sem valor.
      expect(find.text('Valor da consulta'), findsNothing);
      await tester.tap(find.text('Confirmar consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Valor da consulta'), findsNothing);

      expect(consultas.formasDosAgendamentos.single, (forma: FormaDePagamento.plano, planoId: 4));
      expect(
        find.text('Pagamento pelo plano Hapvida: a clínica confere o plano no dia. Leve a carteirinha.'),
        findsOneWidget,
      );
    });

    testWidgets('pelo plano, sem plano marcado, o botão pede o plano', (tester) async {
      await abrir(tester, ConsultasFalso(), asTres);

      await tester.tap(find.text('Pelo plano de saúde'));
      await tester.pumpAndSettle();

      expect(find.text('Escolha o plano'), findsOneWidget);
      expect(botao(tester).onPressed, isNull);
    });

    testWidgets('a recusa aparece acima do botão, e as opções continuam', (tester) async {
      await abrir(
        tester,
        ConsultasFalso(
          agendar: [
            const ErroDaApi(
              status: 422,
              codigo: 'FORMA_DE_PAGAMENTO_NAO_ACEITA',
              mensagem: 'Este profissional não aceita essa forma de pagamento. Escolha outra forma.',
            ),
          ],
        ),
        asTres,
      );

      await tester.tap(find.text('Na clínica, no dia da consulta'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Este profissional não aceita essa forma de pagamento. Escolha outra forma.'), findsOneWidget);
      expect(find.text('Como você vai pagar?'), findsOneWidget);
      expect(find.byType(ConsultaConfirmadaScreen), findsNothing);
    });

    testWidgets('nos quatro aparelhos, com o plano escolhido', (tester) async {
      await abrir(tester, ConsultasFalso(), asTres, planoPreferido: 3);
      await tester.tap(find.text('Pelo plano de saúde'));
      await tester.pumpAndSettle();

      await conferirNosQuatroAparelhos(tester);
    });

    // Etapa 23: os outros estados do Resumo e o que vem depois dele.
    testWidgets('nos quatro aparelhos, sem escolha: as três opções e o botão desativado', (tester) async {
      await abrir(tester, ConsultasFalso(), asTres);

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('nos quatro aparelhos, pelo aplicativo: as opções, a nota da reserva e o pagamento antecipado', (
      tester,
    ) async {
      await abrir(tester, ConsultasFalso(), asTres);
      await tester.tap(find.text('Pelo aplicativo, agora'));
      await tester.pumpAndSettle();

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('nos quatro aparelhos, com a recusa acima do botão', (tester) async {
      await abrir(
        tester,
        ConsultasFalso(agendar: [
          const ErroDaApi(
            status: 422,
            codigo: 'PLANO_NAO_ACEITO',
            mensagem: 'Este profissional não atende por esse plano. Escolha outro plano ou outra forma de pagamento.',
          ),
        ]),
        asTres,
        planoPreferido: 3,
      );
      await tester.tap(find.text('Pelo plano de saúde'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirmar consulta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('não atende por esse plano'), findsOneWidget);

      await conferirNosQuatroAparelhos(tester);
    });

    for (final (nome, forma, opcao, plano) in [
      ('pelo plano', FormaDePagamento.plano, 'Pelo plano de saúde', hapvida),
      ('na clínica', FormaDePagamento.clinica, 'Na clínica, no dia da consulta', null),
    ]) {
      testWidgets('a confirmação $nome, nos quatro aparelhos', (tester) async {
        await abrir(tester, ConsultasFalso(agendar: [confirmadaCom(forma, plano: plano)]), asTres, planoPreferido: 4);
        await tester.tap(find.text(opcao));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Confirmar consulta'));
        await tester.pumpAndSettle();
        expect(find.byType(ConsultaConfirmadaScreen), findsOneWidget);

        await conferirNosQuatroAparelhos(tester);
      });
    }
  });

  group('a forma depois de agendar', () {
    test('a frase da confirmação diz a forma', () {
      expect(textoDaForma(confirmadaCom(FormaDePagamento.app)), 'Recebemos a confirmação do pagamento.');
      expect(
        textoDaForma(confirmadaCom(FormaDePagamento.plano, plano: unimed)),
        'Pagamento pelo plano Unimed: a clínica confere o plano no dia. Leve a carteirinha.',
      );
      expect(
        textoDaForma(confirmadaCom(FormaDePagamento.clinica)),
        'O pagamento é feito na clínica, no dia da consulta.',
      );
    });

    test('o valor do cartão: nenhum pelo plano; o da consulta pelo aplicativo ou na clínica', () {
      expect(valorAMostrar(confirmadaCom(FormaDePagamento.plano, plano: unimed)), isNull);
      expect(valorAMostrar(confirmadaCom(FormaDePagamento.clinica)), 'R\$ 250,00');
      expect(valorAMostrar(confirmadaCom(FormaDePagamento.app)), 'R\$ 250,00');
    });

    testWidgets('o diálogo sem devolução, nos quatro aparelhos', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: Builder(
          builder: (contexto) => Scaffold(
            body: TextButton(
              onPressed: () => unawaited(confirmarCancelamento(contexto, confirmada: true, pagaPeloApp: false)),
              child: const Text('Abrir'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('cancelar uma consulta pelo plano ou na clínica não fala em devolução', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: temaDoApp(),
          home: Builder(
            builder: (contexto) => Scaffold(
              body: TextButton(
                onPressed: () => unawaited(confirmarCancelamento(contexto, confirmada: true, pagaPeloApp: false)),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      expect(find.text(RegraDoCancelamento.horarioLivre), findsOneWidget);
      expect(find.textContaining('devolvido'), findsNothing);
    });
  });
}
