import '../../domain/models/erro_da_api.dart';

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
