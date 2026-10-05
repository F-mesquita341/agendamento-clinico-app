import '../../domain/models/especialidade.dart';
import '../services/api_client.dart';
import 'leitura_json.dart';

/// O catálogo público da clínica: especialidades, e nas próximas etapas os
/// profissionais e a agenda. Interface, para as telas serem testadas com um
/// catálogo em memória, sem rede.
abstract interface class RepositorioDoCatalogo {
  Future<List<Especialidade>> especialidades();
}

class RepositorioDoCatalogoRemoto implements RepositorioDoCatalogo {
  RepositorioDoCatalogoRemoto(this._api);

  final ApiClient _api;

  @override
  Future<List<Especialidade>> especialidades() async {
    // Rota pública: o catálogo é visto antes de entrar na conta.
    final corpo = await _api.get('/especialidades', autenticado: false);
    return lerLista(corpo, 'especialidades', Especialidade.fromJson);
  }
}
