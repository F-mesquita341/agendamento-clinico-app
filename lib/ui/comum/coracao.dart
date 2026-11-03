import 'package:flutter/material.dart';

/// O coração com batimento, símbolo do aplicativo: o mesmo desenho no ícone
/// (gerado a partir deste pintor) e nas primeiras telas. É decoração: um
/// `CustomPaint` sem descrição de semântica não cria nó para o leitor de tela.
class CoracaoComBatimento extends StatelessWidget {
  const CoracaoComBatimento({super.key, required this.tamanho, this.cor = Colors.white});

  final double tamanho;
  final Color cor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(tamanho), painter: PintorDoCoracao(cor));
  }
}

/// Pinta o coração cheio, centrado no espaço que recebe, com a linha do
/// batimento recortada: transparente, e não pintada com a cor do fundo. Assim
/// ela mostra o que está atrás — o verde, no ícone e nas telas — e continua
/// existindo na camada monocromática do ícone, que só olha a transparência.
class PintorDoCoracao extends CustomPainter {
  const PintorDoCoracao(this.cor);

  final Color cor;

  /// O desenho ocupa 100 × 87 unidades: a largura do coração e a altura, da
  /// curva de cima à ponta.
  static const _largura = 100.0;
  static const _altura = 87.0;

  @override
  void paint(Canvas canvas, Size size) {
    final escala = size.shortestSide / _largura;
    canvas
      ..saveLayer(Offset.zero & size, Paint())
      ..translate((size.width - _largura * escala) / 2, (size.height - _altura * escala) / 2 - 3 * escala)
      ..scale(escala);

    final coracao = Path()
      ..moveTo(50, 90)
      ..cubicTo(20, 70, 0, 52, 0, 32)
      ..cubicTo(0, 15, 13, 3, 28, 3)
      ..cubicTo(38, 3, 46, 9, 50, 17)
      ..cubicTo(54, 9, 62, 3, 72, 3)
      ..cubicTo(87, 3, 100, 15, 100, 32)
      ..cubicTo(100, 52, 80, 70, 50, 90)
      ..close();
    canvas.drawPath(coracao, Paint()..color = cor);

    final batimento = Path()
      ..moveTo(-4, 47)
      ..lineTo(28, 47)
      ..lineTo(36, 32)
      ..lineTo(46, 64)
      ..lineTo(56, 24)
      ..lineTo(64, 47)
      ..lineTo(104, 47);
    canvas
      ..drawPath(
        batimento,
        Paint()
          ..blendMode = BlendMode.clear
          ..style = PaintingStyle.stroke
          ..strokeWidth = 7
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(PintorDoCoracao anterior) => anterior.cor != cor;
}
