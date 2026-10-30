import 'package:flutter/material.dart';

import '../comum/botoes.dart';
import '../comum/confirmacao.dart';
import '../comum/espaco.dart';
import '../comum/textos.dart';

/// A regra do estorno, decidida em 20/10/2026: cancelar até o horário da
/// consulta devolve o valor pago inteiro; faltar sem cancelar, não. O texto
/// não promete prazo nem forma da devolução, que a clínica faz à mão a partir
/// do registro que a API grava (checklist, itens 3.4, 10.1 e 10.2).
///
/// Os textos moram aqui, num lugar só, para o "Saiba mais" do pagamento, o
/// diálogo de cancelar e as regras dizerem a mesma coisa.
abstract final class RegraDoCancelamento {
  /// O que acontece com o valor, para quem cancela e para quem falta.
  static const devolucao = 'Se você cancelar até o horário da consulta, o valor pago é devolvido integralmente. '
      'Se faltar sem cancelar, o valor não é devolvido.';

  /// O que acontece com o horário.
  static const horarioLivre = 'Ao cancelar, o horário volta a ficar livre para outras pessoas.';

  /// O diálogo de cancelar uma consulta confirmada.
  static const aoCancelarConfirmada = '$horarioLivre O valor pago é devolvido integralmente.';

  /// O diálogo de cancelar uma reserva que aguarda o pagamento. Não diz "você
  /// não pagou": o pagamento pode estar a caminho, e a confirmação chegar
  /// depois.
  static const aoCancelarAguardando = 'Esta consulta ainda aguarda a confirmação do pagamento. $horarioLivre '
      'Se você já pagou, o valor é devolvido integralmente.';

  /// As regras inteiras, com o telefone da clínica quando ela tem.
  static String regras(String? telefone) =>
      'Você pode cancelar pelo aplicativo até o horário da consulta. Ao cancelar, o horário volta a ficar livre '
      'para outras pessoas, e o valor pago é devolvido integralmente. Se faltar sem cancelar, o valor não é '
      'devolvido. ${switch (telefone) {
        final telefone? => 'Em caso de dúvida, ligue para a clínica: ${semQuebra(telefone)}.',
        null => 'Em caso de dúvida, fale com a clínica.',
      }}';
}

/// Pergunta antes de cancelar (checklist, itens 3.4 e 5.7), dizendo o que
/// acontece com o horário e com o valor. Devolve true só se a pessoa confirmou.
Future<bool> confirmarCancelamento(BuildContext context, {required bool confirmada}) => confirmar(
      context,
      titulo: 'Cancelar esta consulta?',
      texto: confirmada ? RegraDoCancelamento.aoCancelarConfirmada : RegraDoCancelamento.aoCancelarAguardando,
      acao: 'Cancelar consulta',
      desistir: 'Manter consulta',
      destrutiva: true,
    );

/// As regras de cancelamento numa folha (checklist, item 10.2).
Future<void> mostrarRegrasDeCancelamento(BuildContext context, {String? telefone}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (contexto) {
      final tema = Theme.of(contexto);
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(Espaco.grande, 0, Espaco.grande, Espaco.grande),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: Espaco.medio,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'Regras de cancelamento',
                  style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(RegraDoCancelamento.regras(telefone), style: tema.textTheme.bodyLarge),
              BotaoPrincipal(rotulo: 'Entendi', aoTocar: () => Navigator.of(contexto).pop()),
            ],
          ),
        ),
      );
    },
  );
}
