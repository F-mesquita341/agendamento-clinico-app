import 'package:flutter/material.dart';

/// Cor de partida da paleta. O Material 3 deriva dela os pares de cor e texto
/// já com contraste; que cada par usado chega aos 4,5:1 do WCAG 2.1 AA é
/// conferido por teste (test/config/tema_test.dart), e não por olho — é o que
/// avisa se alguma cor for sobrescrita à mão aqui.
const Color corDePartida = Color(0xFF0B6E79);

ThemeData temaDoApp() {
  final esquema = ColorScheme.fromSeed(seedColor: corDePartida);
  return ThemeData(
    colorScheme: esquema,
    // Área de toque mínima de 48 dp — acima dos 44 × 44 px do WCAG 2.1.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
}

/// Razão de contraste do WCAG 2.1 entre duas cores, de 1 a 21.
double razaoDeContraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (clara, escura) = la > lb ? (la, lb) : (lb, la);
  return (clara + 0.05) / (escura + 0.05);
}
