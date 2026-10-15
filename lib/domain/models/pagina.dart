/// Uma página de uma listagem da API, com o que é preciso para saber se há
/// mais.
class Pagina<T> {
  const Pagina({required this.itens, required this.pagina, required this.paginas, required this.total});

  final List<T> itens;

  /// O número desta página, a partir de 1.
  final int pagina;

  /// Quantas páginas a listagem tem.
  final int paginas;

  /// Quantos itens a listagem tem ao todo, somando as páginas.
  final int total;

  bool get temMais => pagina < paginas;
}
