import '../services/api_client.dart';
import 'leitura_json.dart';

/// Qual versão do termo de consentimento está vigente. Lida da API a cada vez,
/// e não embutida no aplicativo: a troca do termo, que ainda vai acontecer
/// depois do parecer do Comitê de Ética, vale já no pedido seguinte.
abstract interface class RepositorioDoConsentimento {
  Future<String> versaoVigente();
}

class RepositorioDoConsentimentoRemoto implements RepositorioDoConsentimento {
  RepositorioDoConsentimentoRemoto(this._api);

  final ApiClient _api;

  @override
  Future<String> versaoVigente() async {
    // Rota pública: o termo é lido antes do cadastro existir.
    final corpo = await _api.get('/consentimento/termo-vigente', autenticado: false);
    return lerObjeto(corpo, 'termo', (termo) {
      final versao = termo['versao'];
      if (versao is! String || versao.isEmpty) throw const FormatException('versao');
      return versao;
    });
  }
}
