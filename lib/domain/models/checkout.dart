import 'instante.dart';

/// A página de pagamento do Mercado Pago, em ambiente de teste, aberta para
/// uma consulta (TCC, Seção 3.9.5). O aplicativo só a abre: o cartão é
/// digitado lá, e nunca passa por aqui.
///
/// Pedir o pagamento de novo devolve a mesma página enquanto ela estiver
/// aberta — por isso o pedido é seguro de repetir.
class Checkout {
  const Checkout({required this.endereco, required this.valorFormatado, this.expiraEm});

  factory Checkout.fromJson(Map<String, Object?> json) {
    final url = json['checkoutUrl'];
    final valor = json['valorFormatado'];
    final expira = json['expiraEm'];
    if (url is! String || valor is! String) {
      throw const FormatException('Pagamento fora do formato esperado.');
    }
    final endereco = Uri.tryParse(url);
    // Só página segura: é nela que a pessoa digita o cartão. Um endereço sem
    // https, venha de onde vier, não é aberto.
    if (endereco == null || endereco.scheme != 'https' || endereco.host.isEmpty) {
      throw const FormatException('O endereço do pagamento não é uma página https.');
    }
    return Checkout(
      endereco: endereco,
      valorFormatado: valor,
      expiraEm: expira == null ? null : instanteDaApi(expira),
    );
  }

  /// Onde o pagamento é feito.
  final Uri endereco;

  /// "R$ 250,00" — o valor da consulta.
  final String valorFormatado;

  /// O mesmo prazo da reserva: depois dele, a página não aceita mais pagar.
  final DateTime? expiraEm;
}
