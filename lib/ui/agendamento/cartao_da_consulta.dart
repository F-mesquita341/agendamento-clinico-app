import 'package:flutter/material.dart';

import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/textos.dart';

/// A consulta, linha a linha: quem atende, quando, onde e quanto custa
/// (checklist, itens 5.1 e 2.4). O mesmo cartão no resumo e no pagamento, para
/// a pessoa reconhecer a consulta de uma tela para a outra.
class CartaoDaConsulta extends StatelessWidget {
  const CartaoDaConsulta({
    super.key,
    required this.profissional,
    required this.horario,
    required this.valorFormatado,
    required this.hoje,
  });

  final Profissional profissional;
  final Horario horario;

  /// No resumo, o valor do profissional; no pagamento, o que a API congelou na
  /// consulta.
  final String valorFormatado;

  /// Hoje, na clínica: decide o "Amanhã" e o ano.
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    final clinica = profissional.clinica;
    return Card(
      child: Column(
        children: [
          _LinhaDoCartao(
            icone: Icons.medical_services_outlined,
            chave: 'Profissional',
            valor: profissional.nome,
            apoio: profissional.especialidade?.nome,
          ),
          const Divider(height: 1),
          _LinhaDoCartao(
            icone: Icons.event_outlined,
            chave: 'Data e horário',
            valor: '${diaPorInteiro(horario.dia, hoje: hoje)} · ${horario.hora}',
            apoio: '${horario.duracaoMinutos} minutos',
          ),
          // Sem a clínica, a API não diz onde é; a linha não inventa um lugar.
          if (clinica != null) ...[
            const Divider(height: 1),
            _LinhaDoCartao(
              icone: Icons.location_on_outlined,
              chave: 'Local',
              valor: clinica.nome,
              apoio: clinica.endereco,
            ),
          ],
          const Divider(height: 1),
          _LinhaDoCartao(
            icone: Icons.payments_outlined,
            chave: 'Valor da consulta',
            valor: semQuebra(valorFormatado),
          ),
        ],
      ),
    );
  }
}

class _LinhaDoCartao extends StatelessWidget {
  const _LinhaDoCartao({required this.icone, required this.chave, required this.valor, this.apoio});

  final IconData icone;
  final String chave;
  final String valor;
  final String? apoio;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final deApoio = TextStyle(color: cores.onSurfaceVariant);
    // Uma linha, uma leitura: "Profissional, Ana Lima, Cardiologia".
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.medio),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icone, color: cores.primary),
            const SizedBox(width: Espaco.medio),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(chave, style: tema.textTheme.bodySmall!.copyWith(fontSize: 14).merge(deApoio)),
                  Text(
                    valor,
                    style: tema.textTheme.titleSmall!.copyWith(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
                  ),
                  if (apoio case final apoio?)
                    Text(apoio, style: tema.textTheme.bodySmall!.copyWith(fontSize: 15).merge(deApoio)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
