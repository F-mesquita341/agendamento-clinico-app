import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/comum/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iniciais', () {
    test('primeira letra do primeiro nome e do último', () {
      expect(iniciaisDe('Ana Lima'), 'AL');
      expect(iniciaisDe('Maria de Souza'), 'MS');
    });

    test('um nome só: a primeira letra dele', () {
      expect(iniciaisDe('Ágata'), 'Á');
    });

    test('maiúsculas, mesmo com o nome em minúsculas e espaços sobrando', () {
      expect(iniciaisDe('  joão   pedro  '), 'JP');
    });

    test('sem nome, nada', () {
      expect(iniciaisDe('   '), '');
    });
  });

  testWidgets('com texto a 200%, as iniciais continuam dentro do círculo', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(MaterialApp(
      theme: temaDoApp(),
      home: const Scaffold(body: Center(child: AvatarDeIniciais(nome: 'Ana Lima', tamanho: 64))),
    ));

    // Numa linha só, e sem passar do diâmetro.
    final iniciais = tester.getSize(find.text('AL'));
    expect(iniciais.width, lessThanOrEqualTo(64));
    expect(iniciais.height, lessThan(32));
  });
}
