import 'package:flutter/material.dart';

import '../../domain/models/clinica.dart';
import '../agendamento/pagamento_antecipado.dart';
import '../comum/atalhos_da_clinica.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/textos.dart';
import '../consultas/regras_de_cancelamento.dart';

/// As dúvidas mais comuns, em perguntas curtas (checklist, item 10.6), e o
/// telefone da clínica a um toque (item 10.3).
class ComoFuncionaScreen extends StatelessWidget {
  const ComoFuncionaScreen({super.key, required this.clinicas});

  /// As clínicas que a busca conhece; as sem telefone ficam de fora. Vêm de
  /// quem abre a tela: ela fica fora do shell, onde a busca está.
  final List<Clinica> clinicas;

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
            for (final clinica in clinicas)
              if (clinica.telefone case final telefone?) ...[
                const SizedBox(height: Espaco.medio),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(Espaco.medio),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: Espaco.pequeno,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Prefere falar com alguém?',
                            style: tema.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ),
                        Text('${clinica.nome} · ${semQuebra(telefone)}', style: tema.textTheme.bodyLarge),
                        const SizedBox(height: Espaco.pequeno),
                        BotaoSecundario(
                          rotulo: 'Ligar para a clínica',
                          aoTocar: () => ligarParaAClinica(context, telefone),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
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
        'resumo e faça o pagamento antecipado.',
  ),
  (
    pergunta: 'Como funciona o pagamento?',
    resposta: 'Ao confirmar o resumo, o horário fica reservado para você por $minutosDeReserva minutos. O pagamento '
        'é feito na página do Mercado Pago, e a consulta fica confirmada quando o pagamento é confirmado. Nesta '
        'versão de teste, nenhum valor real é cobrado.',
  ),
  (
    pergunta: 'Fechei a página de pagamento sem pagar. E agora?',
    resposta: 'Dentro do prazo da reserva, toque em Pagar agora, no Início ou na consulta em Minhas consultas. '
        'Depois do prazo, a reserva expira e é preciso escolher o horário de novo.',
  ),
  (
    pergunta: 'Como cancelo uma consulta?',
    resposta: 'Em Minhas consultas, abra a consulta e toque em Cancelar consulta. '
        '${RegraDoCancelamento.horarioLivre} ${RegraDoCancelamento.devolucao}',
  ),
  (
    pergunta: 'Posso trocar o horário de uma consulta?',
    resposta: 'Nesta versão não há troca de horário. O caminho é cancelar a consulta e agendar de novo.',
  ),
  (
    pergunta: 'Não recebi o lembrete. O que faço?',
    resposta: 'O lembrete chega até 24 horas antes da consulta, se os lembretes estiverem ativados. Confira em '
        'Perfil e, nas configurações do celular, se o aplicativo pode enviar notificações. A consulta continua '
        'valendo mesmo sem o lembrete.',
  ),
];
