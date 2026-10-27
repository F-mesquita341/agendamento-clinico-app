import '../../domain/models/checkout.dart';
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
  /// adiante para a mais antiga — todos os status, canceladas inclusive. Cada
  /// uma vem com o horário e o profissional.
  Future<Pagina<Consulta>> minhas({int pagina = 1});

  /// A consulta como a API a tem agora, com o horário e o profissional. É por
  /// aqui que o aplicativo sabe se o pagamento foi confirmado: a volta do
  /// checkout não confirma nada (checklist, item 1.5).
  Future<Consulta> consulta(int id);

  /// Abre — ou reaproveita — a página de pagamento da consulta. Pedir de novo
  /// devolve a mesma página enquanto ela estiver aberta.
  Future<Checkout> pagar(int consultaId);

  /// Cancela a consulta, aguardando pagamento ou confirmada. A resposta traz a
  /// consulta sem o horário e sem o profissional: quem a mostra guarda os que
  /// já tinha.
  Future<Consulta> cancelar(int id);
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
    return lerPagina(corpo, 'consultas', _daLista);
  }

  /// Na lista, é com o horário e o profissional que as telas dizem quando, com
  /// quem e onde. Consulta sem um dos dois é resposta fora do formato.
  static Consulta _daLista(Map<String, Object?> json) {
    final consulta = Consulta.fromJson(json);
    if (consulta.horario == null || consulta.profissional == null) {
      throw const FormatException('Consulta da lista sem o horário ou sem o profissional.');
    }
    return consulta;
  }

  @override
  Future<Consulta> consulta(int id) async {
    final corpo = await _api.get('/consultas/$id');
    return lerObjeto(corpo, 'consulta', Consulta.fromJson);
  }

  @override
  Future<Checkout> pagar(int consultaId) async {
    final corpo = await _api.post('/consultas/$consultaId/pagamento');
    return lerObjeto(corpo, 'pagamento', Checkout.fromJson);
  }

  @override
  Future<Consulta> cancelar(int id) async {
    final corpo = await _api.patch('/consultas/$id/cancelamento');
    return lerObjeto(corpo, 'consulta', Consulta.fromJson);
  }
}
