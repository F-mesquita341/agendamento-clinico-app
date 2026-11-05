import 'package:shared_preferences/shared_preferences.dart';

import 'preferencias_do_aparelho.dart';

/// As preferências no armazenamento do Android, pelo `shared_preferences`.
/// É o único arquivo que importa o pacote.
///
/// Usa a API assíncrona, que lê do armazenamento a cada vez, sem guardar uma
/// cópia em memória: são poucas leituras por abertura.
class PreferenciasShared implements PreferenciasDoAparelho {
  PreferenciasShared() : _armazenamento = SharedPreferencesAsync();

  static const _chaveDaCidade = 'cidade';
  static const _chaveDoPertoDeMim = 'pertoDeMim';

  final SharedPreferencesAsync _armazenamento;

  @override
  Future<int?> cidadeEscolhida() => _armazenamento.getInt(_chaveDaCidade);

  @override
  Future<void> guardarCidade(int? cidadeId) => cidadeId == null
      ? _armazenamento.remove(_chaveDaCidade)
      : _armazenamento.setInt(_chaveDaCidade, cidadeId);

  @override
  Future<bool> pertoDeMim() async => await _armazenamento.getBool(_chaveDoPertoDeMim) ?? false;

  @override
  Future<void> guardarPertoDeMim(bool escolhido) => escolhido
      ? _armazenamento.setBool(_chaveDoPertoDeMim, true)
      : _armazenamento.remove(_chaveDoPertoDeMim);
}
