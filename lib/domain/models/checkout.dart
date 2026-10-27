/// A página de pagamento do Mercado Pago, em ambiente de teste, aberta para
/// uma consulta (TCC, Seção 3.9.5). O aplicativo só a abre: o cartão é
/// digitado lá, e nunca passa por aqui.
///
/// Pedir o pagamento de novo devolve a mesma página enquanto ela estiver
/// aberta — por isso o pedido é seguro de repetir.
///
/// Só o endereço é lido. O valor e o prazo que a API também manda são os da
/// consulta — o valor congelado ao reservar e o prazo da reserva —, e é de lá
/// que a tela os tira (revisão de 19/10).
class Checkout {
  const Checkout({required this.endereco});

  factory Checkout.fromJson(Map<String, Object?> json) {
    final url = json['checkoutUrl'];
    if (url is! String) throw const FormatException('Pagamento fora do formato esperado.');
    final endereco = Uri.tryParse(url);
    // Só página segura: é nela que a pessoa digita o cartão. Um endereço sem
    // https, venha de onde vier, não é aberto.
    if (endereco == null || endereco.scheme != 'https' || endereco.host.isEmpty) {
      throw const FormatException('O endereço do pagamento não é uma página https.');
    }
    return Checkout(endereco: endereco);
  }

  /// Onde o pagamento é feito.
  final Uri endereco;
}
