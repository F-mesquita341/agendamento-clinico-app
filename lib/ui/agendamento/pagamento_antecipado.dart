import 'package:flutter/material.dart';

import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../consultas/regras_de_cancelamento.dart';

/// Quantos minutos a reserva espera o pagamento: o `RESERVA_MINUTOS` da API,
/// 15 em produção. A API só diz o prazo depois de reservar, e o resumo precisa
/// do número antes; por isso ele mora aqui. A tela do pagamento usa o prazo que
/// a API devolveu, e não este número.
const minutosDeReserva = 15;

/// A frase que explica o pagamento antecipado, onde ele aparece, e o caminho
/// para a explicação inteira (checklist, itens 2.3 e 10.1). Nunca "caução".
class PagamentoAntecipado extends StatelessWidget {
  const PagamentoAntecipado({super.key, this.complemento});

  /// O que a frase diz a mais, onde precisa — na tela do pagamento, que a
  /// página do Mercado Pago abre a seguir.
  final String? complemento;

  @override
  Widget build(BuildContext context) {
    const frase = 'O pagamento antecipado garante o seu horário.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          switch (complemento) {
            final mais? => '$frase $mais',
            null => frase,
          },
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        // Um link que continua a frase de cima, alinhado à esquerda como ela —
        // e não centrado, como os outros botões de texto. Sem o recuo do botão,
        // o texto começa onde a frase começa, e a área de toque não invade a
        // margem da tela.
        TextButton(
          style: TextButton.styleFrom(
            alignment: AlignmentDirectional.centerStart,
            padding: EdgeInsets.zero,
          ),
          onPressed: () => explicarPagamentoAntecipado(context),
          child: const Text('Saiba mais sobre o pagamento antecipado'),
        ),
      ],
    );
  }
}

/// A explicação inteira, numa folha por cima da tela: por que o pagamento é
/// antecipado, a reserva, e o que acontece com o valor se a pessoa cancelar ou
/// faltar (checklist, item 10.1).
Future<void> explicarPagamentoAntecipado(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (contexto) {
      final tema = Theme.of(contexto);
      final texto = tema.textTheme.bodyLarge;
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
                  'Por que o pagamento é antecipado?',
                  style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                'O pagamento antecipado garante o seu horário e ajuda a clínica a reduzir as faltas.',
                style: texto,
              ),
              Text(
                'Ao confirmar o resumo, o horário fica reservado para você por $minutosDeReserva minutos. '
                'Se o pagamento não for confirmado nesse prazo, a reserva expira e o horário volta a ficar livre.',
                style: texto,
              ),
              Text(RegraDoCancelamento.devolucao, style: texto),
              Text('Nesta versão de teste, nenhum valor real é cobrado.', style: texto),
              BotaoPrincipal(rotulo: 'Entendi', aoTocar: () => Navigator.of(contexto).pop()),
            ],
          ),
        ),
      );
    },
  );
}
