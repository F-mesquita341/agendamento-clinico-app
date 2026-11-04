import 'package:shared_preferences/shared_preferences.dart';

import 'preferencias_do_aparelho.dart';

/// As preferências no armazenamento do Android, pelo `shared_preferences`.
/// É o único arquivo que importa o pacote.
///
/// Usa a API assíncrona, que lê do armazenamento a cada vez, sem guardar uma
/// cópia em memória: são duas leituras por abertura, no máximo.
class PreferenciasShared implements PreferenciasDoAparelho {
  PreferenciasShared() : _armazenamento = SharedPreferencesAsync();

  static const _chaveDaCidade = 'cidade';

  final SharedPreferencesAsync _armazenamento;

  @override
  Future<int?> cidadeEscolhida() => _armazenamento.getInt(_chaveDaCidade);

  @override
  Future<void> guardarCidade(int? cidadeId) => cidadeId == null
      ? _armazenamento.remove(_chaveDaCidade)
      : _armazenamento.setInt(_chaveDaCidade, cidadeId);
}
