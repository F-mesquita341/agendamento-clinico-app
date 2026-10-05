import 'package:agendamento_clinico/config/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 AA, critério 1.4.3: contraste mínimo de 4,5:1 entre texto e fundo.
/// Conferido aqui para cada par de cores do tema que leva texto.
///
/// O que este teste protege não é a cor de partida: o Material 3 deriva os
/// tons de modo que texto e fundo contrastem com qualquer uma — trocar o
/// verde-azulado por um amarelo-claro não derruba nada aqui, e foi conferido.
/// O risco é sobrescrever uma cor à mão (`copyWith(primary: ...)`) para
/// "acertar a identidade visual": isso derruba o par afetado.
void main() {
  final esquema = temaDoApp().colorScheme;

  test('a fórmula de contraste dá os extremos conhecidos', () {
    expect(razaoDeContraste(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(razaoDeContraste(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  final pares = <String, (Color, Color)>{
    'texto sobre a superfície': (esquema.onSurface, esquema.surface),
    'texto secundário sobre a superfície': (esquema.onSurfaceVariant, esquema.surface),
    'texto sobre a cor principal (botões)': (esquema.onPrimary, esquema.primary),
    'texto sobre o contêiner principal': (esquema.onPrimaryContainer, esquema.primaryContainer),
    'texto sobre o contêiner secundário': (esquema.onSecondaryContainer, esquema.secondaryContainer),
    'texto de erro sobre a superfície': (esquema.error, esquema.surface),
    'texto sobre o contêiner de erro': (esquema.onErrorContainer, esquema.errorContainer),
    'cor principal como texto sobre a superfície (links, botões de texto)': (esquema.primary, esquema.surface),
  };

  for (final MapEntry(key: nome, value: (texto, fundo)) in pares.entries) {
    test('$nome passa de 4,5:1', () {
      expect(razaoDeContraste(texto, fundo), greaterThanOrEqualTo(4.5));
    });
  }

  test('área de toque mínima de 48 dp', () {
    expect(temaDoApp().materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}
