import 'package:flutter/material.dart';

import '../../domain/models/data_civil.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/selo_de_status.dart';
import 'situacao_da_consulta.dart';

/// Uma consulta numa lista — o Início e Minhas consultas: o dia e a hora em
/// destaque (checklist, item 8.3), o selo do status com texto e ícone (1.7),
/// quem atende e, quando pedido, onde (6.2). Tocar abre os detalhes.
///
/// O cartão inteiro é um botão só, e é lido como um.
class CartaoNaLista extends StatelessWidget {
  const CartaoNaLista({
    super.key,
    required this.item,
    required this.hoje,
    required this.aoTocar,
    this.comEndereco = false,
  });

  final ConsultaNaLista item;
  final DataCivil hoje;
  final VoidCallback aoTocar;

  /// A próxima consulta, no Início, mostra também a clínica e o endereço.
  final bool comEndereco;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final apoio = tema.textTheme.bodyMedium!.copyWith(color: cores.onSurfaceVariant);
    final (:consulta, :horario, :profissional) = item;
    final especialidade = profissional.especialidade;
    final clinica = profissional.clinica;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          child: InkWell(
            onTap: aoTocar,
            child: Padding(
              padding: const EdgeInsets.all(Espaco.medio),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      spacing: Espaco.pequeno - 4,
                      children: [
                        Text(
                          diaEHora(horario.dia, horario.hora, hoje: hoje),
                          style: tema.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          profissional.nome,
                          style: tema.textTheme.titleSmall!.copyWith(fontSize: 17),
                        ),
                        if (especialidade != null) Text(especialidade.nome, style: apoio),
                        if (comEndereco && clinica != null)
                          Text(
                            switch (clinica.endereco) {
                              final endereco? => '${clinica.nome} · $endereco',
                              null => clinica.nome,
                            },
                            style: apoio,
                          ),
                        const SizedBox(height: Espaco.pequeno - 4),
                        SeloDeStatus(status: consulta.status, motivo: consulta.motivoDoCancelamento),
                      ],
                    ),
                  ),
                  const SizedBox(width: Espaco.pequeno),
                  Icon(Icons.chevron_right, color: cores.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
