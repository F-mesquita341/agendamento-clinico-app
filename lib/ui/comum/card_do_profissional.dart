import 'package:flutter/material.dart';

import '../../domain/models/profissional.dart';
import 'avatar.dart';
import 'espaco.dart';
import 'textos.dart';

/// O profissional numa lista: iniciais, nome, especialidade e o valor da
/// consulta — o que a pessoa precisa para escolher, e nada além (checklist,
/// itens 8.2 e 5.10).
///
/// O card inteiro é um botão só, e é lido como um: nome, especialidade e
/// valor, numa frase.
class CardDoProfissional extends StatelessWidget {
  const CardDoProfissional({super.key, required this.profissional, required this.aoTocar});

  final Profissional profissional;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final apoio = tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: cores.onSurfaceVariant);
    final especialidade = profissional.especialidade;

    return Card(
      // O realce do toque fica dentro dos cantos arredondados.
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
                  AvatarDeIniciais(nome: profissional.nome, tamanho: 56),
                  const SizedBox(width: Espaco.medio),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(profissional.nome, style: tema.textTheme.titleSmall!.copyWith(fontSize: 17)),
                        if (especialidade != null) Text(especialidade.nome, style: apoio),
                        // O valor como a API o escreve, sem conta no aplicativo — só não
                        // quebra de linha no meio.
                        Text.rich(
                          TextSpan(
                            text: 'Consulta ',
                            children: [
                              TextSpan(
                                text: semQuebra(profissional.valorFormatado),
                                style: TextStyle(fontWeight: FontWeight.w700, color: cores.onSurface),
                              ),
                            ],
                          ),
                          style: apoio,
                        ),
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
