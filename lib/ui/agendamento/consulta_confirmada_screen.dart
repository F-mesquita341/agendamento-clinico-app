import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/tema.dart';
import '../../data/services/abridor_de_links.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import '../comum/selo_de_status.dart';
import 'cartao_da_consulta.dart';

/// A consulta confirmada, aberta no lugar do pagamento: voltar dela leva à
/// busca, e nunca de novo ao checkout (checklist, item 3.3).
///
/// Monta-se com a consulta como a API a devolveu ao confirmar, e não com o
/// que a tela do pagamento tinha (item 1.4). O profissional e o horário de
/// antes só entram se a resposta, fora do esperado, não os trouxer.
Route<void> rotaDaConsultaConfirmada(
  Consulta consulta, {
  required Profissional profissionalDeAntes,
  required Horario horarioDeAntes,
  required DataCivil hoje,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => ConsultaConfirmadaScreen(
      consulta: consulta,
      profissional: consulta.profissional ?? profissionalDeAntes,
      horario: consulta.horario ?? horarioDeAntes,
      hoje: hoje,
    ),
  );
}

/// "Consulta confirmada": só aparece quando a API diz `confirmada` — a volta
/// do checkout não confirma nada (checklist, itens 1.3 e 1.5).
class ConsultaConfirmadaScreen extends StatelessWidget {
  const ConsultaConfirmadaScreen({
    super.key,
    required this.consulta,
    required this.profissional,
    required this.horario,
    required this.hoje,
  });

  final Consulta consulta;
  final Profissional profissional;
  final Horario horario;
  final DataCivil hoje;

  Future<void> _abrirNoMapa(BuildContext context, String lugar, String endereco) async {
    final abriu = await context.read<AbridorDeLinks>().abrirNoMapa(lugar);
    if (!abriu && context.mounted) {
      mostrarRetorno(context, TipoDeRetorno.erro, 'Não foi possível abrir o mapa. O endereço é $endereco.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final sucesso = tema.extension<CoresDeRetorno>()!.sucesso;
    final clinica = profissional.clinica;
    final endereco = clinica?.endereco;
    final fonteGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final conteudo = [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: sucesso.fundo, shape: BoxShape.circle),
          child: ExcludeSemantics(child: Icon(Icons.check_circle, size: 36, color: sucesso.texto)),
        ),
      ),
      const SizedBox(height: Espaco.medio),
      Semantics(
        header: true,
        child: Text(
          'Consulta confirmada',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: Espaco.pequeno),
      Text(
        'Recebemos a confirmação do pagamento.',
        textAlign: TextAlign.center,
        style: tema.textTheme.bodyLarge,
      ),
      const SizedBox(height: Espaco.grande),
      // A data e a hora, com o maior destaque da tela (checklist, item 8.3).
      Text(
        '${diaPorInteiro(horario.dia, hoje: hoje)} · ${horario.hora}',
        textAlign: TextAlign.center,
        style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: Espaco.pequeno),
      Center(child: SeloDeStatus(status: consulta.status, motivo: consulta.motivoDoCancelamento)),
      const SizedBox(height: Espaco.grande),
      CartaoDaConsulta(
        profissional: profissional,
        horario: horario,
        valorFormatado: consulta.valorFormatado,
        hoje: hoje,
      ),
      if (clinica != null && endereco != null) ...[
        const SizedBox(height: Espaco.pequeno),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _abrirNoMapa(context, '${clinica.nome}, $endereco', endereco),
            icon: const Icon(Icons.map_outlined),
            label: const Text('Abrir no mapa'),
          ),
        ),
      ],
    ];
    final voltar = BotaoPrincipal(
      rotulo: 'Voltar à busca',
      aoTocar: () => Navigator.of(context).popUntil((rota) => rota.isFirst),
    );

    return Scaffold(
      body: SafeArea(
        child: fonteGrande
            ? ListView(
                padding: const EdgeInsets.all(Espaco.margem),
                children: [...conteudo, const SizedBox(height: Espaco.grande), voltar],
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(Espaco.margem, Espaco.maior, Espaco.margem, Espaco.margem),
                      children: conteudo,
                    ),
                  ),
                  Padding(padding: const EdgeInsets.all(Espaco.medio), child: voltar),
                ],
              ),
      ),
    );
  }
}
