import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/forma_de_pagamento.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../comum/retorno.dart';
import '../comum/rodape.dart';
import '../comum/textos.dart';
import 'cartao_da_consulta.dart';
import 'consulta_confirmada_screen.dart';
import 'etapa_do_agendamento.dart';
import 'pagamento_antecipado.dart';
import 'pagamento_screen.dart';
import 'resumo_view_model.dart';

/// O resumo, aberto por cima da grade. Termina com o [DesfechoDoResumo] para
/// a grade — ou, com o horário reservado, no lugar dela: no pagamento, ou,
/// com o plano ou na clínica, na confirmação.
Route<DesfechoDoResumo> rotaDoResumo(
  Profissional profissional,
  Horario horario, {
  required DataCivil hoje,
  required DateTime Function() relogio,
  int? planoPreferido,
}) {
  return MaterialPageRoute<DesfechoDoResumo>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) => ResumoViewModel(
        contexto.read<RepositorioDeConsultas>(),
        profissional: profissional,
        horario: horario,
        hoje: hoje,
        planoPreferido: planoPreferido,
      ),
      child: ResumoScreen(relogio: relogio),
    ),
  );
}

/// Etapa 2: tudo o que vai ser reservado, antes de reservar (checklist, item
/// 5.1), como vai ser pago, e um botão que diz o que acontece ao tocar nele.
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
      case Confirmada(:final consulta):
        // Plano ou clínica: confirmada na hora, sem a etapa do pagamento.
        unawaited(Navigator.of(context).pushAndRemoveUntil(
          rotaDaConsultaConfirmada(
            consulta,
            profissionalDeAntes: vm.profissional,
            horarioDeAntes: vm.horario,
            agora: relogio(),
          ),
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
    // A reserva de 15 minutos e o pagamento antecipado só valem pelo
    // aplicativo.
    final pelaApp = vm.forma == FormaDePagamento.app;

    final conteudo = [
      if (vm.demorando) ...[
        const Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando),
        const SizedBox(height: Espaco.medio),
      ],
      CartaoDaConsulta(
        profissional: vm.profissional,
        horario: vm.horario,
        // Pelo plano, a consulta é acertada com o plano: o valor some.
        valorFormatado: vm.forma == FormaDePagamento.plano ? null : vm.profissional.valorFormatado,
        hoje: vm.hoje,
      ),
      if (vm.pergunta) ...[
        const SizedBox(height: Espaco.grande),
        _ComoPagar(vm: vm),
      ],
      if (pelaApp) ...[
        const SizedBox(height: Espaco.medio),
        const Nota(
          icone: Icons.lock_clock,
          texto: 'Ao confirmar, o horário fica reservado para você por $minutosDeReserva minutos, '
              'enquanto você faz o pagamento.',
        ),
        const SizedBox(height: Espaco.grande),
        const PagamentoAntecipado(),
      ],
    ];
    final acao = [
      if (vm.erro case final erro?) ...[
        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
        const SizedBox(height: Espaco.medio),
      ],
      BotaoPrincipal(
        rotulo: switch (vm.forma) {
          null => 'Escolha como pagar',
          FormaDePagamento.plano when !vm.podeConfirmar => 'Escolha o plano',
          FormaDePagamento.app => 'Confirmar e ir para o pagamento',
          _ => 'Confirmar consulta',
        },
        rotuloEnviando: pelaApp ? 'Reservando o horário…' : 'Confirmando a consulta…',
        enviando: vm.enviando,
        aoTocar: vm.podeConfirmar ? () => _confirmar(context, vm) : null,
      ),
    ];

    // O botão fica fixo no rodapé, como no modelo. Sem altura para isso, ele
    // vai para o fim da lista, que rola inteira: fixo, junto com o aviso de
    // erro, ele tomaria a tela toda.
    final fixo = rodapeFixo(context);
    return PopScope(
      // Sair no meio do envio deixaria uma reserva feita sem a pessoa saber.
      canPop: !vm.enviando,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Resumo da consulta'),
          bottom: etapaDoAgendamento(context, 2, total: vm.etapas),
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Espaco.margem),
            children: [...conteudo, if (!fixo) ...[const SizedBox(height: Espaco.grande), ...acao]],
          ),
        ),
        bottomNavigationBar: fixo ? RodapeDeAcao(child: Column(children: acao)) : null,
      ),
    );
  }
}

/// "Como você vai pagar?": as formas que o profissional aceita, nenhuma
/// marcada de saída; com o plano, os planos dele logo abaixo.
class _ComoPagar extends StatelessWidget {
  const _ComoPagar({required this.vm});

  final ResumoViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final titulo = tema.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800);
    final apoio = tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: tema.colorScheme.onSurfaceVariant);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(header: true, child: Text('Como você vai pagar?', style: titulo)),
        const SizedBox(height: Espaco.pequeno),
        RadioGroup<FormaDePagamento>(
          groupValue: vm.forma,
          onChanged: (forma) {
            if (forma != null) vm.escolherForma(forma);
          },
          child: Column(
            children: [
              for (final forma in vm.formasOferecidas)
                RadioListTile<FormaDePagamento>(
                  value: forma,
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (forma) {
                    FormaDePagamento.app => 'Pelo aplicativo, agora',
                    FormaDePagamento.plano => 'Pelo plano de saúde',
                    FormaDePagamento.clinica => 'Na clínica, no dia da consulta',
                  }),
                  subtitle: switch (forma) {
                    FormaDePagamento.app =>
                      Text('Reserva de $minutosDeReserva minutos; o pagamento é no Mercado Pago.', style: apoio),
                    FormaDePagamento.plano => Text('A clínica confere o plano no dia.', style: apoio),
                    FormaDePagamento.clinica => Text('A consulta fica confirmada agora.', style: apoio),
                  },
                ),
            ],
          ),
        ),
        if (vm.forma == FormaDePagamento.plano) ...[
          const SizedBox(height: Espaco.pequeno),
          Semantics(header: true, child: Text('Qual o seu plano?', style: titulo)),
          RadioGroup<int>(
            groupValue: vm.planoId,
            onChanged: (planoId) {
              if (planoId != null) vm.escolherPlano(planoId);
            },
            child: Column(
              children: [
                for (final plano in vm.profissional.planos)
                  RadioListTile<int>(value: plano.id, contentPadding: EdgeInsets.zero, title: Text(plano.nome)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
