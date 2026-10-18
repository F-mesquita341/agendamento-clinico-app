import '../../domain/models/consulta.dart';
import '../../domain/models/pagina.dart';
import '../services/api_client.dart';
import 'leitura_json.dart';

/// As consultas do paciente. Interface, para as telas serem testadas com
/// consultas em memória, sem rede.
abstract interface class RepositorioDeConsultas {
  /// Reserva o horário e devolve a consulta, aguardando o pagamento.
  ///
  /// A [versao] é a que veio com o horário na grade. Se outra pessoa reservou
  /// nesse meio-tempo, a versão não confere, e a API recusa com a ação
  /// `recarregar_horarios` (lock otimista; TCC, Seção 3.8.3).
  Future<Consulta> agendar({required int horarioId, required int versao});

  /// As consultas do paciente, uma página por vez, da que acontece mais
  /// adiante para a mais antiga.
  Future<Pagina<Consulta>> minhas({int pagina = 1});
}

/// As consultas vão sempre com o token da conta: são de quem está dentro.
class RepositorioDeConsultasRemoto implements RepositorioDeConsultas {
  RepositorioDeConsultasRemoto(this._api);

  /// Quantas consultas por página — o padrão da API, dito por extenso.
  static const porPagina = 20;

  final ApiClient _api;

  @override
  Future<Consulta> agendar({required int horarioId, required int versao}) async {
    final corpo = await _api.post('/consultas', corpo: {'horarioId': horarioId, 'versao': versao});
    return lerObjeto(corpo, 'consulta', Consulta.fromJson);
  }

  @override
  Future<Pagina<Consulta>> minhas({int pagina = 1}) async {
    final corpo = await _api.get('/consultas', consulta: {'pagina': '$pagina', 'limite': '$porPagina'});
    return lerPagina(corpo, 'consultas', Consulta.fromJson);
  }
}
