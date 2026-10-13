import 'package:flutter/material.dart';

import '../../config/tema.dart';
import 'textos.dart';

/// O nome do aplicativo como marca: "marcaí", com o "í" em âmbar. Para fundos
/// na cor principal — a abertura, a espera inicial.
///
/// É um texto só, e não duas peças lado a lado: o leitor de tela lê o nome
/// inteiro. Com o texto do sistema ampliado, a marca cresce enquanto houver
/// largura e, a partir daí, encolhe para caber — nunca é cortada.
///
/// O contraste das duas cores sobre a cor principal é conferido em
/// test/config/tema_test.dart: a diretriz automática de contraste das telas
/// não sabe avaliar um texto de duas cores.
class Marca extends StatelessWidget {
  const Marca({super.key, required this.tamanho});

  final double tamanho;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text.rich(
        const TextSpan(
          children: [
            TextSpan(text: 'marca'),
            TextSpan(text: 'í', style: TextStyle(color: ambarDaMarca)),
          ],
        ),
        // O nome próprio, como se escreve.
        semanticsLabel: Textos.nomeDoApp,
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: tamanho,
          fontWeight: FontWeight.w800,
          height: 1,
          letterSpacing: -0.04 * tamanho,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }
}
