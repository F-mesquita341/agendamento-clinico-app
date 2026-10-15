import '../../domain/models/data_civil.dart';
import '../../domain/models/especialidade.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/pagina.dart';
import '../../domain/models/profissional.dart';
import '../services/api_client.dart';
import 'leitura_json.dart';

/// O catálogo público da clínica: especialidades, profissionais e a agenda de
/// cada um. Interface, para as telas serem testadas com um catálogo em
/// memória, sem rede.
abstract interface class RepositorioDoCatalogo {
  Future<List<Especialidade>> especialidades();

  /// Os profissionais que atendem, em ordem de nome, uma página por vez.
  ///
  /// [termo] busca no nome, sem diferenciar acento. A API exige ao menos duas
  /// letras: quem chama é que não manda menos.
  Future<Pagina<Profissional>> profissionais({int? especialidadeId, String? termo, int pagina = 1});

  /// Os horários livres e futuros do profissional, de agora até o começo do
  /// dia [ate], no calendário da clínica. A API não devolve mais que 60 dias.
  Future<List<Horario>> horarios(int profissionalId, {required DataCivil ate});
}

/// O catálogo é público, e o aplicativo o consulta sem o token da conta: o que
/// a pessoa procura — uma especialidade — não precisa ir junto de quem ela é.
class RepositorioDoCatalogoRemoto implements RepositorioDoCatalogo {
  RepositorioDoCatalogoRemoto(this._api);

  final ApiClient _api;

  @override
  Future<List<Especialidade>> especialidades() async {
    final corpo = await _api.get('/especialidades', autenticado: false);
    return lerLista(corpo, 'especialidades', Especialidade.fromJson);
  }

  @override
  Future<Pagina<Profissional>> profissionais({int? especialidadeId, String? termo, int pagina = 1}) async {
    final corpo = await _api.get(
      '/profissionais',
      autenticado: false,
      consulta: {
        'especialidade': ?especialidadeId?.toString(),
        'q': ?termo,
        'pagina': '$pagina',
      },
    );
    return lerPagina(corpo, 'profissionais', Profissional.fromJson);
  }

  @override
  Future<List<Horario>> horarios(int profissionalId, {required DataCivil ate}) async {
    // Data sem hora: a API a lê como meia-noite na clínica.
    final corpo = await _api.get(
      '/profissionais/$profissionalId/horarios',
      autenticado: false,
      consulta: {'ate': ate.paraApi()},
    );
    return lerLista(corpo, 'horarios', Horario.fromJson);
  }
}
