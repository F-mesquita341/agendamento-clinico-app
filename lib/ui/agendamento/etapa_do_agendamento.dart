import 'package:flutter/material.dart';

import '../comum/espaco.dart';

/// As telas do agendamento: o horário, o resumo e o pagamento.
const etapasDoAgendamento = 3;

/// "Etapa 2 de 3", numa linha sob o título da barra (checklist, item 1.9).
///
/// Embaixo, e não ao lado do título como no modelo: a 200% de fonte, ao lado,
/// ele espremeria o título até cortá-lo. O texto começa onde começa o título,
/// e a barra cresce o quanto ele precisar — a altura é medida com a fonte e a
/// largura de verdade, e não estimada.
PreferredSizeWidget etapaDoAgendamento(BuildContext context, int numero) {
  final tema = Theme.of(context);
  final estilo = tema.textTheme.labelLarge!.copyWith(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: tema.colorScheme.onSurfaceVariant,
  );
  final texto = 'Etapa $numero de $etapasDoAgendamento';
  // Com o botão de voltar, o título começa depois dele.
  final temVoltar = ModalRoute.of(context)?.impliesAppBarDismissal ?? false;
  final inicio = (temVoltar ? kToolbarHeight : 0) + NavigationToolbar.kMiddleSpacing;

  final pintor = TextPainter(
    text: TextSpan(text: texto, style: estilo),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: MediaQuery.sizeOf(context).width - inicio - Espaco.margem);
  final altura = pintor.height + Espaco.pequeno;
  pintor.dispose();

  return PreferredSize(
    preferredSize: Size.fromHeight(altura),
    child: Align(
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: EdgeInsetsDirectional.only(start: inicio, end: Espaco.margem),
        child: Text(texto, style: estilo),
      ),
    ),
  );
}
