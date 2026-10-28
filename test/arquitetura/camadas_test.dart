import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // As camadas de dados e de domínio são Dart puro: o Flutter fica na de
  // interface (revisão de 19/10, que achou um import do Flutter na leitura do
  // JSON só para registrar resposta fora do formato).
  test('as camadas de dados e de domínio não importam o Flutter', () {
    final comFlutter = [
      for (final pasta in ['lib/data', 'lib/domain'])
        for (final arquivo in Directory(pasta).listSync(recursive: true).whereType<File>())
          if (arquivo.path.endsWith('.dart') && arquivo.readAsStringSync().contains('package:flutter/'))
            arquivo.path.replaceAll(r'\', '/'),
    ];

    expect(comFlutter, isEmpty);
  });

  // Cada pacote do Firebase entra por um adaptador só, atrás de uma interface:
  // o resto do aplicativo é testado sem ele.
  test('só os adaptadores importam os pacotes do Firebase', () {
    const adaptadores = {
      'package:firebase_auth/': 'lib/data/services/autenticacao_firebase.dart',
      'package:firebase_messaging/': 'lib/data/services/notificacoes_firebase.dart',
    };
    final arquivos = [
      for (final arquivo in Directory('lib').listSync(recursive: true).whereType<File>())
        if (arquivo.path.endsWith('.dart')) arquivo,
    ];

    for (final MapEntry(key: pacote, value: adaptador) in adaptadores.entries) {
      final importam = [
        for (final arquivo in arquivos)
          if (arquivo.readAsStringSync().contains(pacote)) arquivo.path.replaceAll(r'\', '/'),
      ];
      expect(importam, [adaptador], reason: pacote);
    }
  });
}
