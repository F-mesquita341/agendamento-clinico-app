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

  group('cor', () {
    // As contas de cada nome do seed, feitas à mão: a soma dos códigos das
    // letras, módulo seis. Uma cor por hashCode, ou sempre a mesma, muda isto.
    test('a mesma para o mesmo nome, e espalhada pelos profissionais do seed', () {
      expect(corDoAvatar('Eduardo Parente Lima'), coresDosAvatares[0]);
      expect(corDoAvatar('Carlos Eduardo Timbó'), coresDosAvatares[1]);
      expect(corDoAvatar('Daniela Rocha Vieira'), coresDosAvatares[3]);
      expect(corDoAvatar('Ana Beatriz Nogueira'), coresDosAvatares[5]);
      expect(corDoAvatar(' Carlos Eduardo Timbó '), corDoAvatar('Carlos Eduardo Timbó'));
    });

    testWidgets('o círculo usa a cor do nome', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: const Scaffold(body: AvatarDeIniciais(nome: 'Daniela Rocha Vieira', tamanho: 56)),
      ));
      expect(tester.widget<CircleAvatar>(find.byType(CircleAvatar)).backgroundColor, coresDosAvatares[3]);
    });
  });
}
