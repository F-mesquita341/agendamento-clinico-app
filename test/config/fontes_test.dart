import 'dart:io';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// A fonte passa por três lugares que precisam concordar: a declaração em
/// pubspec.yaml, os arquivos em assets/fontes e o tema. Quando discordam, o
/// aplicativo não quebra: cai em silêncio na fonte padrão, ou desenha um
/// negrito falso. Por isso a conferência é aqui, e não a olho.
void main() {
  final pubspec = File('pubspec.yaml').readAsStringSync().replaceAll('\r\n', '\n');
  final familia = RegExp(r'^    - family: (.+)$', multiLine: true).firstMatch(pubspec)!.group(1)!.trim();
  // De cada arquivo, o caminho e o peso — 400 quando a declaração não diz.
  final arquivos = [
    for (final achado
        in RegExp(r'^        - asset: (\S+)\n(?:          weight: (\d+)\n)?', multiLine: true).allMatches(pubspec))
      (caminho: achado.group(1)!, peso: int.parse(achado.group(2) ?? '400')),
  ];

  final tema = temaDoApp();
  final textos = tema.textTheme;
  final estilos = <String, TextStyle>{
    'displayLarge': textos.displayLarge!,
    'displayMedium': textos.displayMedium!,
    'displaySmall': textos.displaySmall!,
    'headlineLarge': textos.headlineLarge!,
    'headlineMedium': textos.headlineMedium!,
    'headlineSmall': textos.headlineSmall!,
    'titleLarge': textos.titleLarge!,
    'titleMedium': textos.titleMedium!,
    'titleSmall': textos.titleSmall!,
    'bodyLarge': textos.bodyLarge!,
    'bodyMedium': textos.bodyMedium!,
    'bodySmall': textos.bodySmall!,
    'labelLarge': textos.labelLarge!,
    'labelMedium': textos.labelMedium!,
    'labelSmall': textos.labelSmall!,
    'botão de texto': tema.textButtonTheme.style!.textStyle!.resolve({})!,
  };

  test('a fonte tem os quatro pesos declarados', () {
    expect(arquivos, hasLength(4));
  });

  test('a família declarada é a que o tema usa, em todos os estilos de texto', () {
    expect(familia, familiaDaFonte);
    for (final MapEntry(key: nome, value: estilo) in estilos.entries) {
      expect(estilo.fontFamily, familiaDaFonte, reason: nome);
    }
  });

  // Arquivo ausente o próprio Flutter recusa, ao montar o pacote. O que ele
  // não vê é um arquivo que existe e não é fonte — uma página de erro salva
  // no lugar do download, por exemplo.
  test('cada arquivo declarado é uma fonte TrueType', () {
    for (final arquivo in arquivos) {
      expect(File(arquivo.caminho).readAsBytesSync().take(4), [0, 1, 0, 0], reason: arquivo.caminho);
    }
  });

  test('todo peso que o tema usa tem arquivo próprio', () {
    final declarados = {for (final arquivo in arquivos) arquivo.peso};
    for (final MapEntry(key: nome, value: estilo) in estilos.entries) {
      expect(declarados, contains((estilo.fontWeight ?? FontWeight.w400).value), reason: nome);
    }
  });

  test('a licença acompanha a fonte', () {
    expect(File('assets/fontes/OFL.txt').readAsStringSync(), contains('SIL Open Font License'));
  });
}
