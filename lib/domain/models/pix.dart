import 'dart:convert';
import 'dart:typed_data';

import 'instante.dart';

/// Um pagamento por Pix, em ambiente de teste, aberto para uma consulta: o
/// código "copia e cola", a imagem do QR Code, o prazo e o valor (contrato da
/// versão 2, "Pix"). O aplicativo só mostra e copia; quem confirma é a API.
///
/// Pedir o Pix de novo devolve o mesmo enquanto ele estiver aberto — por isso
/// o pedido é seguro de repetir.
class Pix {
  const Pix({
    required this.copiaECola,
    required this.qrCode,
    required this.expiraEm,
    required this.valorFormatado,
  });

  factory Pix.fromJson(Map<String, Object?> json) {
    final copiaECola = json['copiaECola'];
    final qrCodeBase64 = json['qrCodeBase64'];
    final expiraEm = json['expiraEm'];
    final valorFormatado = json['valorFormatado'];
    if (copiaECola is! String || copiaECola.isEmpty || qrCodeBase64 is! String || valorFormatado is! String) {
      throw const FormatException('Pix fora do formato esperado.');
    }
    return Pix(
      copiaECola: copiaECola,
      qrCode: _imagem(qrCodeBase64),
      expiraEm: instanteDaApi(expiraEm),
      valorFormatado: valorFormatado,
    );
  }

  /// A imagem que não decodifica não impede o pagamento: o "copia e cola"
  /// continua valendo, e a tela mostra só ele.
  static Uint8List? _imagem(String base64) {
    try {
      final bytes = base64Decode(base64);
      return bytes.isEmpty ? null : bytes;
    } on FormatException {
      return null;
    }
  }

  /// O código que a pessoa cola no app do banco.
  final String copiaECola;

  /// O PNG do QR Code, ou null se a API mandou algo que não decodifica.
  final Uint8List? qrCode;

  /// Até quando o Pix vale — o prazo da reserva.
  final DateTime expiraEm;

  /// "R$ 250,00", como a API escreveu.
  final String valorFormatado;
}
