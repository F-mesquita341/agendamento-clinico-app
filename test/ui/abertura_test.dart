import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/conta/abertura_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio/acessibilidade.dart';

/// A abertura como tela: cabe, rola quando não cabe, e é acessível. Para onde
/// os botões levam está em aplicativo_test.dart, junto do portão da sessão.
Future<void> montar(WidgetTester tester, {Size tela = const Size(412, 892)}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: temaDoApp(), home: const AberturaScreen()));
}

Future<void> alcancar(WidgetTester tester, String rotulo) async {
  final botao = find.ancestor(of: find.text(rotulo), matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
  await tester.scrollUntilVisible(botao, 100, scrollable: find.byType(Scrollable).first);
  expect(botao.hitTestable(), findsOneWidget);
}

void main() {
  testWidgets('num celular em pé, tudo cabe: os dois botões aparecem sem rolar', (tester) async {
    await montar(tester);

    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('Criar conta')).bottom, lessThan(892));
    expect(tester.getRect(find.text('Já tenho conta')).bottom, lessThan(892));
    // E não sobra o que rolar.
    expect(tester.state<ScrollableState>(find.byType(Scrollable).first).position.maxScrollExtent, 0);
  });

  testWidgets('só os dois caminhos: sem aceite implícito e sem entrada por rede social', (tester) async {
    await montar(tester);

    expect(find.byWidgetPredicate((w) => w is ButtonStyleButton), findsNWidgets(2));
    expect(find.textContaining('concorda'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);
  });

  testWidgets('o lembrete chega antes da consulta, sem prometer "um dia antes"', (tester) async {
    await montar(tester);

    // Uma consulta marcada para hoje ou amanhã tem o lembrete em minutos.
    expect(find.textContaining('receba um lembrete antes da consulta'), findsOneWidget);
    expect(find.textContaining('dia antes'), findsNothing);
  });

  testWidgets('nos quatro aparelhos', (tester) async {
    await montar(tester);
    await conferirNosQuatroAparelhos(tester);
  });

  testWidgets('a frase principal é o cabeçalho e dá o nome da tela ao leitor de tela', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);

    final dados = tester.getSemantics(find.text('Sua consulta marcada pelo celular, sem fila e sem ligação.')).getSemanticsData();
    expect(dados.flagsCollection.isHeader, isTrue);
    expect(dados.flagsCollection.namesRoute, isTrue);
    semantica.dispose();
  });

  testWidgets('acessibilidade: toque de 48 dp, rótulos e contraste sobre a cor principal', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('texto ampliado a 200%: nada estoura, e rolando se chega aos dois botões', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await montar(tester, tela: const Size(360, 640));

    expect(tester.takeException(), isNull);
    await alcancar(tester, 'Criar conta');
    await alcancar(tester, 'Já tenho conta');
  });

  testWidgets('aparelho deitado: nada estoura, e rolando se chega aos dois botões', (tester) async {
    await montar(tester, tela: const Size(800, 360));

    expect(tester.takeException(), isNull);
    await alcancar(tester, 'Criar conta');
    await alcancar(tester, 'Já tenho conta');
  });
}
