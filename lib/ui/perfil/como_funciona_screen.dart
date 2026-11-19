import 'package:flutter/material.dart';

import '../agendamento/pagamento_antecipado.dart';
import '../comum/espaco.dart';
import '../consultas/regras_de_cancelamento.dart';

/// As dúvidas mais comuns, em perguntas curtas (checklist, item 10.6). O
/// telefone da clínica fica onde a clínica aparece: nos detalhes da consulta
/// e na página do profissional (item 10.3).
class ComoFuncionaScreen extends StatelessWidget {
  const ComoFuncionaScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Como funciona')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaco.margem),
          children: [
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  for (final (i, (:pergunta, :resposta)) in perguntasFrequentes.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    ExpansionTile(
                      title: Text(pergunta, style: tema.textTheme.titleSmall),
                      // Sem os fios que a ExpansionTile põe aberta: os do
                      // cartão já separam as perguntas.
                      shape: const Border(),
                      collapsedShape: const Border(),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      childrenPadding: const EdgeInsets.fromLTRB(Espaco.medio, 0, Espaco.medio, Espaco.medio),
                      children: [Text(resposta, style: tema.textTheme.bodyLarge)],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// As perguntas, na ordem do modelo. As respostas dizem o que as telas dizem:
/// o prazo da reserva e a regra do cancelamento vêm de onde as telas os tiram.
const perguntasFrequentes = <({String pergunta, String resposta})>[
  (
    pergunta: 'Como agendo uma consulta?',
    resposta: 'Em Buscar, escolha a especialidade ou o profissional. Depois escolha o dia e o horário, confira o '
        'resumo e escolha como pagar: pelo aplicativo, pelo plano de saúde ou na clínica, conforme o que o '
        'profissional aceita.',
  ),
  (
    pergunta: 'Como funciona o pagamento?',
    resposta: 'Ao confirmar o resumo, o horário fica reservado para você por $minutosDeReserva minutos. O pagamento '
        'é feito na página do Mercado Pago, e a consulta fica confirmada quando o pagamento é confirmado. Nesta '
        'versão de teste, nenhum valor real é cobrado. Alguns profissionais aceitam plano de saúde ou pagamento '
        'na clínica: nesse caso, a consulta é confirmada na hora, sem pagamento pelo aplicativo.',
  ),
  (
    pergunta: 'Fechei a página de pagamento sem pagar. E agora?',
    resposta: 'Dentro do prazo da reserva, toque em Pagar agora, no Início ou na consulta em Minhas consultas. '
        'Depois do prazo, a reserva expira e é preciso escolher o horário de novo.',
  ),
  (
    pergunta: 'Como cancelo uma consulta?',
    resposta: 'Em Minhas consultas, abra a consulta e toque em Cancelar consulta. '
        '${RegraDoCancelamento.horarioLivre} ${RegraDoCancelamento.devolucao} '
        '${RegraDoCancelamento.semValorADevolver}',
  ),
  (
    pergunta: 'Posso trocar o horário de uma consulta?',
    resposta: 'Nesta versão não há troca de horário. O caminho é cancelar a consulta e agendar de novo.',
  ),
  (
    pergunta: 'Para que o Marcaí usa a minha localização?',
    resposta: 'Só para mostrar os profissionais mais perto, quando você escolhe "Perto de mim" na cidade. A '
        'localização é aproximada, fica no seu celular e não é enviada nem guardada. Você pode desligar '
        'escolhendo uma cidade, ou tirar a permissão nas configurações do celular.',
  ),
  (
    pergunta: 'Não recebi o lembrete. O que faço?',
    resposta: 'O lembrete chega até 24 horas antes da consulta, se os lembretes estiverem ativados. Confira em '
        'Perfil e, nas configurações do celular, se o aplicativo pode enviar notificações. A consulta continua '
        'valendo mesmo sem o lembrete.',
  ),
];
