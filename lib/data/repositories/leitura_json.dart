import '../../domain/models/erro_da_api.dart';
import '../../domain/models/pagina.dart';

/// Lê uma lista embrulhada no nome do recurso — `{especialidades: [...]}`,
/// `{profissionais: [...]}` —, que é a forma de toda listagem da API.
///
/// Resposta fora desse formato vira `RESPOSTA_INESPERADA`, e não uma exceção
/// de tipo no meio de uma tela.
List<T> lerLista<T>(
  Object? corpo,
  String chave,
  T Function(Map<String, Object?> json) converter,
) {
  try {
    if (corpo is! Map<String, Object?>) throw const FormatException('corpo');
    final lista = corpo[chave];
    if (lista is! List<Object?>) throw FormatException(chave);
    return [
      for (final item in lista)
        if (item is Map<String, Object?>) converter(item) else throw FormatException(chave),
    ];
  } on FormatException {
    throw const ErroDaApi.respostaInesperada(200);
  }
}

/// Lê uma listagem paginada — `{profissionais: [...], paginacao: {pagina,
/// paginas, total}}`. Mesma regra de [lerLista]: formato errado, na lista ou
/// na paginação, vira `RESPOSTA_INESPERADA`.
Pagina<T> lerPagina<T>(
  Object? corpo,
  String chave,
  T Function(Map<String, Object?> json) converter,
) {
  final itens = lerLista(corpo, chave, converter);
  // lerLista já garantiu que o corpo é um objeto.
  final paginacao = (corpo as Map<String, Object?>)['paginacao'];
  if (paginacao is Map<String, Object?>) {
    final pagina = paginacao['pagina'];
    final paginas = paginacao['paginas'];
    final total = paginacao['total'];
    if (pagina is int && paginas is int && total is int) {
      return Pagina(itens: itens, pagina: pagina, paginas: paginas, total: total);
    }
  }
  throw const ErroDaApi.respostaInesperada(200);
}

/// Lê um recurso embrulhado no próprio nome — `{paciente: {...}}` —, que é a
/// forma de toda resposta de um recurso só. Mesma regra de [lerLista]:
/// formato errado vira `RESPOSTA_INESPERADA`.
T lerObjeto<T>(
  Object? corpo,
  String chave,
  T Function(Map<String, Object?> json) converter,
) {
  try {
    if (corpo is! Map<String, Object?>) throw const FormatException('corpo');
    final objeto = corpo[chave];
    if (objeto is! Map<String, Object?>) throw FormatException(chave);
    return converter(objeto);
  } on FormatException {
    throw const ErroDaApi.respostaInesperada(200);
  }
}
