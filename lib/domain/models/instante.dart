/// A API fala em instantes UTC, no formato ISO 8601; a tela, no horário do
/// aparelho. Toda data que chega da API passa por aqui — e só por aqui —, para
/// que nenhuma tela mostre uma consulta três horas adiantada.
DateTime instanteDaApi(Object? valor) {
  if (valor is! String) {
    throw const FormatException('Instante fora do formato ISO 8601.');
  }
  final instante = DateTime.parse(valor);
  if (!instante.isUtc) {
    // A API sempre manda o "Z" do UTC. Sem ele, o texto seria lido como hora
    // local, e o erro passaria despercebido em qualquer aparelho em UTC-3.
    throw const FormatException('Instante sem fuso: a API sempre manda UTC.');
  }
  return instante.toLocal();
}
