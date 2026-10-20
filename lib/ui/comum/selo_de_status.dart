import 'package:flutter/material.dart';

import '../../config/tema.dart';
import '../../domain/models/consulta.dart';
import 'espaco.dart';

/// O status da consulta num selo com ícone e texto, nunca só cor (checklist,
/// itens 1.7 e 8.7). Os rótulos são os da checklist, na língua do paciente.
class SeloDeStatus extends StatelessWidget {
  const SeloDeStatus({super.key, required this.status, this.motivo});

  final StatusDaConsulta status;

  /// Distingue "Cancelada" de "Reserva expirada".
  final MotivoDoCancelamento? motivo;

  /// O rótulo e o ícone de cada status.
  static (String, IconData) rotuloEIcone(StatusDaConsulta status, MotivoDoCancelamento? motivo) =>
      switch (status) {
        StatusDaConsulta.pendentePagamento => ('Aguardando pagamento', Icons.hourglass_top),
        StatusDaConsulta.confirmada => ('Confirmada', Icons.check_circle_outline),
        StatusDaConsulta.cancelada when motivo == MotivoDoCancelamento.reservaExpirada => (
            'Reserva expirada',
            Icons.timer_off_outlined
          ),
        StatusDaConsulta.cancelada => ('Cancelada', Icons.cancel_outlined),
        StatusDaConsulta.realizada => ('Realizada', Icons.task_alt),
        StatusDaConsulta.naoCompareceu => ('Não compareceu', Icons.event_busy_outlined),
        StatusDaConsulta.desconhecido => ('Situação desconhecida', Icons.help_outline),
      };

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (rotulo, icone) = rotuloEIcone(status, motivo);
    final retorno = tema.extension<CoresDeRetorno>()!;
    final (fundo, frente) = switch (status) {
      StatusDaConsulta.confirmada || StatusDaConsulta.realizada => (retorno.sucesso.fundo, retorno.sucesso.texto),
      StatusDaConsulta.pendentePagamento => (retorno.aviso.fundo, retorno.aviso.texto),
      _ => (tema.colorScheme.surfaceContainerHighest, tema.colorScheme.onSurface),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Espaco.pequeno + 4, vertical: Espaco.pequeno - 2),
      decoration: BoxDecoration(color: fundo, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Espaco.pequeno - 2,
        children: [
          ExcludeSemantics(child: Icon(icone, size: 18, color: frente)),
          Flexible(
            child: Text(
              rotulo,
              style: tema.textTheme.labelLarge!.copyWith(color: frente, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
