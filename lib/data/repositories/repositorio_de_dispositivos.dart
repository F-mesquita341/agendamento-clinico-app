import '../../domain/models/erro_da_api.dart';
import '../services/api_client.dart';
import 'leitura_json.dart';

/// Os aparelhos do paciente que recebem o lembrete de consulta. Interface,
/// para o view model dos lembretes ser testado sem rede.
abstract interface class RepositorioDeDispositivos {
  /// Registra o aparelho com este token e devolve o id dele na API. O mesmo
  /// token devolve o mesmo id: é por isso que o aplicativo pode registrar a
  /// cada abertura, sem guardar nada no aparelho.
  Future<int> registrar(String token);

  /// Tira o aparelho dos lembretes. Por id, e não pelo token: o token nunca
  /// vai num endereço.
  Future<void> revogar(int id);
}

class RepositorioDeDispositivosRemoto implements RepositorioDeDispositivos {
  RepositorioDeDispositivosRemoto(this._api);

  final ApiClient _api;

  @override
  Future<int> registrar(String token) async {
    // O corpo é estrito na API: só estes dois campos.
    final corpo = await _api.post('/dispositivos', corpo: {'token': token, 'plataforma': 'android'});
    return lerObjeto(corpo, 'dispositivo', (dispositivo) {
      final id = dispositivo['id'];
      if (id is! int || id <= 0) throw const FormatException('o aparelho veio sem id.');
      return id;
    });
  }

  @override
  Future<void> revogar(int id) async {
    try {
      await _api.delete('/dispositivos/$id');
    } on ErroDaApi catch (erro) {
      // 404 sem ação: o aparelho já não existe, ou já é de outra conta, que
      // entrou neste aparelho depois. Para esta conta, está revogado. O 404 do
      // cadastro que falta vem com a ação, e sobe.
      if (erro.status != 404 || erro.acao != AcaoSugerida.nenhuma) rethrow;
    }
  }
}
