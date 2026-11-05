import 'package:flutter/material.dart';

import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/plano.dart';
import '../../domain/models/profissional.dart';
import 'avatar.dart';
import 'datas.dart';
import 'distancia.dart';
import 'espaco.dart';
import 'textos.dart';

/// O profissional numa lista: iniciais, nome, especialidade e o valor da
/// consulta — o que a pessoa precisa para escolher, e nada além (checklist,
/// itens 8.2 e 5.10). Com a versão 2 da API, também o próximo horário livre,
/// os planos aceitos e, quando a busca está em todas as cidades, a cidade; em
/// "Perto de mim", a distância até a clínica.
///
/// O card inteiro é um botão só, e é lido como um: tudo isso numa frase. O
/// próximo horário é só informação: tocar abre o perfil, que lê a grade de
/// novo.
class CardDoProfissional extends StatelessWidget {
  const CardDoProfissional({
    super.key,
    required this.profissional,
    required this.aoTocar,
    this.hoje,
    this.mostrarCidade = false,
    this.distancia,
  });

  final Profissional profissional;
  final VoidCallback aoTocar;

  /// Hoje, no calendário da clínica, para o próximo horário dizer "hoje" e
  /// "amanhã". Sem ele, o próximo horário não aparece.
  final DataCivil? hoje;

  /// A cidade da clínica: só quando a busca não está numa cidade — aí ela
  /// repetiria em todo card a que está no alto da tela.
  final bool mostrarCidade;

  /// Quantos quilômetros até a clínica, em "Perto de mim"; null fora dele.
  final double? distancia;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final apoio = tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: cores.onSurfaceVariant);
    final especialidade = profissional.especialidade;
    final cidade = mostrarCidade ? profissional.clinica?.cidade : null;
    final distancia = this.distancia == null ? null : textoDaDistancia(this.distancia!);
    // A cidade e a distância numa linha: "Quixadá, CE · a 2,3 km", lida
    // "Quixadá, CE, a 2,3 quilômetros".
    final onde = switch ((cidade?.rotulo, distancia)) {
      (final rotulo?, (:final texto, :final leitura)?) => (texto: '$rotulo · $texto', leitura: '$rotulo, $leitura'),
      (final rotulo?, null) => (texto: rotulo, leitura: rotulo),
      (null, final distancia?) => distancia,
      (null, null) => null,
    };
    final planos = planosAceitos(profissional.planos);
    final hoje = this.hoje;
    final proximo = hoje != null && profissional.informaProximoHorario
        ? textoDoProximoHorario(profissional.proximoHorario, hoje: hoje)
        : null;

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
                        if (onde case (:final texto, :final leitura)?)
                          Text(texto, semanticsLabel: leitura, style: apoio),
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
                        if (planos != null) Text(planos, style: apoio),
                        if (proximo != null) Text(proximo, style: apoio.copyWith(color: cores.onSurface)),
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

/// "Próximo horário: amanhã, 09:00", "Próximo horário: seg, 16/11, 14:30" —
/// ou, sem horário livre, "Sem horário livre nos próximos dias".
String textoDoProximoHorario(ProximoHorario? proximo, {required DataCivil hoje}) {
  if (proximo == null) return 'Sem horário livre nos próximos dias';
  final dia = diaRelativo(proximo.dia, hoje: hoje)?.toLowerCase() ?? diaCurto(proximo.dia, hoje: hoje);
  return 'Próximo horário: $dia, ${proximo.hora}';
}

/// "Aceita Unimed", "Aceita Unimed e Hapvida", "Aceita 3 planos" — ou null,
/// sem plano. Mais de dois nomes não cabem numa linha do card; os nomes estão
/// todos no perfil.
String? planosAceitos(List<Plano> planos) => switch (planos) {
      [] => null,
      [final um] => 'Aceita ${um.nome}',
      [final um, final outro] => 'Aceita ${um.nome} e ${outro.nome}',
      _ => 'Aceita ${planos.length} planos',
    };
