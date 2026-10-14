import 'package:flutter/material.dart';

/// Um chip de uma lista em que se escolhe um só — as especialidades da busca,
/// por exemplo.
///
/// O escolhido leva o ícone de marcado, além da cor: quem não distingue as
/// cores também vê qual é (checklist, item 8.7; WCAG 2.1, critério 1.4.1). A
/// forma e as cores vêm do tema.
class ChipDeEscolha extends StatelessWidget {
  const ChipDeEscolha({super.key, required this.rotulo, required this.escolhido, required this.aoEscolher});

  final String rotulo;
  final bool escolhido;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(rotulo),
      avatar: escolhido ? const Icon(Icons.check) : null,
      // Sem a marca que o Material desenha sozinho: ela viria por cima do ícone.
      showCheckmark: false,
      selected: escolhido,
      onSelected: (_) => aoEscolher(),
    );
  }
}
