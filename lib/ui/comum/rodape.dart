import 'package:flutter/material.dart';

import 'espaco.dart';

/// Se o rodapé com a ação da tela cabe fixo embaixo dela (checklist, itens
/// 6.1 e 10.8). Com o celular deitado, ou com o texto acima de 130%, ele
/// tomaria a tela quase toda, e vai para o fim da lista, que rola inteira
/// (WCAG 1.4.4 e 1.3.4).
///
/// A altura é a da tela sem as barras do sistema: 480 dp fica entre o celular
/// deitado (perto de 390) e o menor celular em pé (perto de 560). Pela tela, e
/// não pelo espaço que sobra: um teclado ainda fechando não troca o rodapé de
/// lugar no meio da animação.
bool rodapeFixo(BuildContext context) {
  final altura = MediaQuery.sizeOf(context).height - MediaQuery.paddingOf(context).vertical;
  return altura >= alturaParaORodapeFixo && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
}

const alturaParaORodapeFixo = 480.0;

/// O rodapé fixo, na barra de baixo da tela (`Scaffold.bottomNavigationBar`):
/// assim, um aviso que aparece embaixo fica acima dele, e não sobre o botão.
/// Respeita a barra de navegação do Android.
class RodapeDeAcao extends StatelessWidget {
  const RodapeDeAcao({super.key, required this.child, this.decorado = true});

  final Widget child;

  /// Com o fundo branco e o fio em cima, separado da lista; sem, sobre o
  /// fundo da tela, como na confirmação.
  final bool decorado;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: decorado
          ? BoxDecoration(
              color: cores.surfaceContainerLowest,
              border: Border(top: BorderSide(color: cores.outlineVariant)),
            )
          : const BoxDecoration(),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(Espaco.medio),
          // A barra de baixo oferece a altura da tela toda: a coluna encolhida
          // dá ao conteúdo altura livre, e ele fica do tamanho que tem — como
          // quando o rodapé vinha embaixo da lista.
          child: Column(mainAxisSize: MainAxisSize.min, children: [child]),
        ),
      ),
    );
  }
}
