import 'package:flutter/foundation.dart';

/// As abas da barra de baixo, sempre nesta ordem (checklist, item 4.4).
enum AbaDoShell { inicio, buscar, consultas, perfil }

/// Qual aba está à vista. Mora acima das telas, e não no shell, para que uma
/// tela aberta por cima dele — a confirmação, o pagamento — possa escolher a
/// aba para onde a pessoa volta: "Ver minhas consultas", "Voltar ao início".
class AbasDoShell extends ChangeNotifier {
  AbaDoShell _aba = AbaDoShell.inicio;

  AbaDoShell get aba => _aba;

  void mostrar(AbaDoShell aba) {
    if (aba == _aba) return;
    _aba = aba;
    notifyListeners();
  }

  /// Uma sessão nova começa no Início. Não avisa ninguém: é chamado quando o
  /// shell nasce, no meio de uma construção, antes de alguém ouvir.
  void recomecar() => _aba = AbaDoShell.inicio;
}
