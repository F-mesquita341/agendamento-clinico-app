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
    if (corpo is! Map<String, Object?>) throw const FormatException('o corpo não é um objeto.');
    final lista = corpo[chave];
    if (lista is! List<Object?>) throw const FormatException('não veio uma lista.');
    return [
      for (final item in lista)
        if (item is Map<String, Object?>) converter(item) else throw const FormatException('um item não é um objeto.'),
    ];
  } on FormatException catch (erro) {
    throw _foraDoFormato(chave, erro.message);
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
  throw _foraDoFormato(chave, 'a paginação não veio, ou veio fora do formato.');
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
    if (corpo is! Map<String, Object?>) throw const FormatException('o corpo não é um objeto.');
    final objeto = corpo[chave];
    if (objeto is! Map<String, Object?>) throw const FormatException('não veio um objeto.');
    return converter(objeto);
  } on FormatException catch (erro) {
    throw _foraDoFormato(chave, erro.message);
  }
}

/// Para onde vai o registro de resposta fora do formato: o log do aparelho,
/// também na versão de release, que é a dos portões. É um `print`, e não o
/// `debugPrint` do Flutter, porque a camada de dados não depende do Flutter
/// (revisão de 19/10). Os testes trocam o destino por uma lista.
void Function(String mensagem) registrarRespostaForaDoFormato = _noLogDoAparelho;

// ignore: avoid_print
void _noLogDoAparelho(String mensagem) => print(mensagem);

/// Para a tela, resposta fora do formato é só `RESPOSTA_INESPERADA`. No log do
/// aparelho fica qual recurso e por quê: é por ali que uma mudança na API se
/// descobre no portão ou numa sessão. Não é defeito do aplicativo, e por isso
/// não passa por `relatarDefeito`.
ErroDaApi _foraDoFormato(String chave, String motivo) {
  registrarRespostaForaDoFormato('Resposta fora do formato em "$chave": $motivo');
  return const ErroDaApi.respostaInesperada(200);
}
