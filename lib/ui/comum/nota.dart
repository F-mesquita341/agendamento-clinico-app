import 'package:flutter/material.dart';

import '../../config/tema.dart';
import 'espaco.dart';

/// Uma informação que faz parte da tela — a reserva de 15 minutos, o prazo
/// para pagar —, com o ícone que a ilustra. Não é o retorno de uma ação (esse
/// é o `Aviso`), e por isso não é anunciada ao aparecer: o leitor de tela a lê
/// na ordem da tela, como o resto.
class Nota extends StatelessWidget {
  const Nota({super.key, required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    // A cor da informação, e não a do contêiner principal, que fica igual à do
    // sucesso com o verde.
    final cores = Theme.of(context).extension<CoresDeRetorno>()!.informacao;
    return Container(
      decoration: BoxDecoration(color: cores.fundo, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(Espaco.medio),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icone, color: cores.texto)),
          const SizedBox(width: Espaco.pequeno + 4),
          Expanded(
            child: Text(texto, style: TextStyle(color: cores.texto, fontSize: 15, height: 1.45)),
          ),
        ],
      ),
    );
  }
}
