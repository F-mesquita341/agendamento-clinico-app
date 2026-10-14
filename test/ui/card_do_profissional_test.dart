import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/comum/card_do_profissional.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const timbo = Profissional(
  id: 2,
  nome: 'Carlos Eduardo Timbó',
  registroConselho: 'CRM-CE 12345',
  valorFormatado: 'R\$ 250,00',
  especialidade: Especialidade(id: 2, nome: 'Cardiologia'),
);

Future<void> montar(WidgetTester tester, Profissional profissional, {VoidCallback? aoTocar}) async {
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [CardDoProfissional(profissional: profissional, aoTocar: aoTocar ?? () {})],
      ),
    ),
  ));
}

void main() {
  testWidgets('mostra o nome, a especialidade e o valor da consulta', (tester) async {
    await montar(tester, timbo);

    expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    expect(find.text('Cardiologia'), findsOneWidget);
    expect(find.text('Consulta R\$\u00a0250,00', findRichText: true), findsOneWidget);
  });

  testWidgets('o valor é o que a API mandou, e não quebra de linha entre o "R\$" e os números', (tester) async {
    await montar(
      tester,
      const Profissional(id: 9, nome: 'Bia Sá', registroConselho: 'CRP 1', valorFormatado: 'R\$ 1.234,50'),
    );

    expect(find.text('Consulta R\$\u00a01.234,50', findRichText: true), findsOneWidget);
  });

  testWidgets('sem especialidade, o card mostra só o nome e o valor', (tester) async {
    await montar(
      tester,
      const Profissional(id: 9, nome: 'Bia Sá', registroConselho: 'CRP 1', valorFormatado: 'R\$ 180,00'),
    );

    final textos = find.descendant(of: find.byType(CardDoProfissional), matching: find.byType(Text));
    // As iniciais, o nome e o valor: nenhuma linha vazia no lugar da especialidade.
    expect(tester.widgetList<Text>(textos).map((t) => t.data ?? t.textSpan!.toPlainText()), [
      'BS',
      'Bia Sá',
      'Consulta R\$\u00a0180,00',
    ]);
  });

  testWidgets('o card inteiro abre o profissional, e não só o nome', (tester) async {
    var toques = 0;
    await montar(tester, timbo, aoTocar: () => toques++);

    await tester.tap(find.text('Carlos Eduardo Timbó'));
    await tester.tap(find.byIcon(Icons.chevron_right));
    final card = tester.getRect(find.byType(CardDoProfissional));
    await tester.tapAt(card.bottomLeft + const Offset(8, -8));

    expect(toques, 3);
  });

  testWidgets('o leitor de tela lê um botão só: nome, especialidade e valor, sem as iniciais', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, timbo);

    final no = tester.getSemantics(find.text('Carlos Eduardo Timbó')).getSemanticsData();
    expect(no.label, 'Carlos Eduardo Timbó\nCardiologia\nConsulta R\$\u00a0250,00');
    expect(no.flagsCollection.isButton, isTrue);
    expect(no.hasAction(SemanticsAction.tap), isTrue);
    semantica.dispose();
  });

  testWidgets('acessibilidade: toque, rótulo e contraste', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, timbo);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('em tela estreita e com texto a 200%, o nome quebra em linhas e nada estoura', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await montar(tester, timbo);

    expect(tester.takeException(), isNull);
    final card = tester.getRect(find.byType(CardDoProfissional));
    for (final texto in ['Carlos Eduardo Timbó', 'Cardiologia']) {
      final area = tester.getRect(find.text(texto));
      expect(card.contains(area.topLeft) && card.contains(area.bottomRight), isTrue, reason: texto);
    }
    // Mais de uma linha: o nome não foi cortado para caber.
    expect(tester.getSize(find.text('Carlos Eduardo Timbó')).height, greaterThan(34 * 1.25 * 1.5));
  });
}
