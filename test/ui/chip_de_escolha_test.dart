import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/comum/chip_de_escolha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> montar(WidgetTester tester, List<Widget> chips) async {
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(spacing: 8, runSpacing: 8, children: chips),
      ),
    ),
  ));
}

/// A parte do chip que se vê: a cápsula pintada, sem a folga de toque em volta.
Finder capsulaDe(String rotulo) => find.descendant(
      of: find.widgetWithText(ChipDeEscolha, rotulo),
      matching: find.byType(Material),
    );

/// A marca de "certo" que o chip do Material desenha por conta própria: o
/// único traço de caminho que ele risca.
final _desenhaAMarcaDoMaterial = paints
  ..something((metodo, argumentos) =>
      metodo == #drawPath && (argumentos[1] as Paint).style == PaintingStyle.stroke);

void main() {
  testWidgets('o escolhido leva o ícone de marcado, além da cor; os outros, não', (tester) async {
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: false, aoEscolher: () {}),
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    final marca = find.byIcon(Icons.check);
    expect(marca, findsOneWidget);
    expect(find.descendant(of: find.widgetWithText(ChipDeEscolha, 'Cardiologia'), matching: marca), findsOneWidget);
    // Uma marca só: o Material não desenha a dele por cima do ícone.
    expect(find.widgetWithText(ChipDeEscolha, 'Cardiologia'), isNot(_desenhaAMarcaDoMaterial));
  });

  testWidgets('o leitor de tela sabe que é botão e qual está escolhido', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: false, aoEscolher: () {}),
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    final todas = tester.getSemantics(find.widgetWithText(ChipDeEscolha, 'Todas')).getSemanticsData();
    final cardiologia = tester.getSemantics(find.widgetWithText(ChipDeEscolha, 'Cardiologia')).getSemanticsData();
    expect(todas.label, 'Todas');
    expect(todas.flagsCollection.isButton, isTrue);
    expect(todas.flagsCollection.isSelected.toBoolOrNull(), isFalse);
    expect(cardiologia.label, 'Cardiologia');
    expect(cardiologia.flagsCollection.isSelected.toBoolOrNull(), isTrue);
    semantica.dispose();
  });

  testWidgets('tocar avisa quem montou o chip', (tester) async {
    final toques = <String>[];
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: true, aoEscolher: () => toques.add('Todas')),
      ChipDeEscolha(rotulo: 'Pediatria', escolhido: false, aoEscolher: () => toques.add('Pediatria')),
    ]);

    await tester.tap(find.text('Pediatria'));
    await tester.tap(find.text('Todas'));

    expect(toques, ['Pediatria', 'Todas']);
  });

  testWidgets('48 dp de altura à vista, escolhido ou não, e em forma de cápsula', (tester) async {
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: false, aoEscolher: () {}),
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    for (final rotulo in ['Todas', 'Cardiologia']) {
      expect(tester.getSize(capsulaDe(rotulo)).height, 48, reason: rotulo);
      expect(tester.widget<Material>(capsulaDe(rotulo)).shape, isA<StadiumBorder>(), reason: rotulo);
    }
  });

  testWidgets('a borda do chip é a dos campos; a do escolhido, a cor principal', (tester) async {
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: false, aoEscolher: () {}),
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    final cores = temaDoApp().colorScheme;
    BorderSide borda(String rotulo) => (tester.widget<Material>(capsulaDe(rotulo)).shape! as StadiumBorder).side;
    expect(borda('Todas').color, cores.outline);
    expect(borda('Todas').width, 1.5);
    expect(borda('Cardiologia').color, cores.primary);
  });

  testWidgets('acessibilidade: toque, rótulo e contraste, escolhido ou não', (tester) async {
    final semantica = tester.ensureSemantics();
    await montar(tester, [
      ChipDeEscolha(rotulo: 'Todas', escolhido: false, aoEscolher: () {}),
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  testWidgets('com texto a 200%, o chip cresce com o rótulo, que continua inteiro', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await montar(tester, [
      ChipDeEscolha(rotulo: 'Cardiologia', escolhido: true, aoEscolher: () {}),
    ]);

    final capsula = tester.getRect(capsulaDe('Cardiologia'));
    final rotulo = tester.getRect(find.text('Cardiologia'));
    expect(capsula.height, greaterThan(48));
    expect(capsula.contains(rotulo.topLeft) && capsula.contains(rotulo.bottomRight), isTrue);
    expect(tester.takeException(), isNull);
  });
}
