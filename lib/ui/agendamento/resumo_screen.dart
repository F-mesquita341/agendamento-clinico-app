import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../comum/retorno.dart';
import '../comum/textos.dart';
import 'cartao_da_consulta.dart';
import 'etapa_do_agendamento.dart';
import 'pagamento_antecipado.dart';
import 'pagamento_screen.dart';
import 'resumo_view_model.dart';

/// O resumo, aberto por cima da grade. Termina com o [DesfechoDoResumo] para
/// a grade — ou, com o horário reservado, no lugar dela, no pagamento.
Route<DesfechoDoResumo> rotaDoResumo(
  Profissional profissional,
  Horario horario, {
  required DataCivil hoje,
  required DateTime Function() relogio,
}) {
  return MaterialPageRoute<DesfechoDoResumo>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) => ResumoViewModel(
        contexto.read<RepositorioDeConsultas>(),
        profissional: profissional,
        horario: horario,
        hoje: hoje,
      ),
      child: ResumoScreen(relogio: relogio),
    ),
  );
}

/// Etapa 2 de 3: tudo o que vai ser reservado, antes de reservar (checklist,
/// item 5.1), e um botão que diz o que acontece ao tocar nele.
class ResumoScreen extends StatelessWidget {
  const ResumoScreen({super.key, required this.relogio});

  /// O relógio da grade, que segue para a tela do pagamento.
  final DateTime Function() relogio;

  Future<void> _confirmar(BuildContext context, ResumoViewModel vm) async {
    final desfecho = await vm.confirmar();
    if (!context.mounted) return;
    switch (desfecho) {
      case Reservada(:final consulta):
        unawaited(Navigator.of(context).pushAndRemoveUntil(
          rotaDoPagamento(consulta, profissional: vm.profissional, horario: vm.horario, relogio: relogio),
          (rota) => rota.isFirst,
        ));
      case Conflito():
        // A grade recarrega e explica (checklist, item 9.1).
        Navigator.of(context).pop(desfecho);
      case null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ResumoViewModel>();
    final cores = Theme.of(context).colorScheme;

    final conteudo = [
      if (vm.demorando) ...[
        const Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando),
        const SizedBox(height: Espaco.medio),
      ],
      CartaoDaConsulta(
        profissional: vm.profissional,
        horario: vm.horario,
        valorFormatado: vm.profissional.valorFormatado,
        hoje: vm.hoje,
      ),
      const SizedBox(height: Espaco.medio),
      const Nota(
        icone: Icons.lock_clock,
        texto: 'Ao confirmar, o horário fica reservado para você por $minutosDeReserva minutos, '
            'enquanto você faz o pagamento.',
      ),
      const SizedBox(height: Espaco.grande),
      const PagamentoAntecipado(),
    ];
    final acao = [
      if (vm.erro case final erro?) ...[
        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
        const SizedBox(height: Espaco.medio),
      ],
      BotaoPrincipal(
        rotulo: 'Confirmar e ir para o pagamento',
        rotuloEnviando: 'Reservando o horário…',
        enviando: vm.enviando,
        aoTocar: () => _confirmar(context, vm),
      ),
    ];

    // O botão fica fixo no rodapé, como no modelo. Com a fonte grande, ele vai
    // para o fim da lista, que rola inteira: fixo, junto com o aviso de erro,
    // ele tomaria uma tela pequena toda.
    final fonteGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;
    return PopScope(
      // Sair no meio do envio deixaria uma reserva feita sem a pessoa saber.
      canPop: !vm.enviando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Resumo da consulta'), bottom: etapaDoAgendamento(context, 2)),
        body: SafeArea(
          child: fonteGrande
              ? ListView(
                  padding: const EdgeInsets.all(Espaco.margem),
                  children: [...conteudo, const SizedBox(height: Espaco.grande), ...acao],
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView(padding: const EdgeInsets.all(Espaco.margem), children: conteudo),
                    ),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: cores.surfaceContainerLowest,
                        border: Border(top: BorderSide(color: cores.outlineVariant)),
                      ),
                      padding: const EdgeInsets.all(Espaco.medio),
                      child: Column(children: acao),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
