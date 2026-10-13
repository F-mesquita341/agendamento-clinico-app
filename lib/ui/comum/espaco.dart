/// A escala de espaçamento do aplicativo (checklist, item 4.5). Toda distância
/// entre elementos sai daqui, e não de um número solto na tela: é o que mantém
/// o mesmo ritmo visual de uma tela para outra.
abstract final class Espaco {
  static const double pequeno = 8;
  static const double medio = 16;
  static const double grande = 24;
  static const double maior = 32;

  /// Margem lateral das telas (checklist, item 8.9).
  static const double margem = medio;
}
