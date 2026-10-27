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
}
