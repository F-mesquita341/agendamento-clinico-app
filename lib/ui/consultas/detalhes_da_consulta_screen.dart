import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/instante.dart';
import '../agendamento/cartao_da_consulta.dart';
import '../agendamento/pagamento_screen.dart';
import '../comum/atalhos_da_clinica.dart';
import '../comum/botoes.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../comum/retorno.dart';
import '../comum/rodape.dart';
import '../comum/selo_de_status.dart';
import '../comum/textos.dart';
import '../profissional/profissional_screen.dart';
import 'detalhes_da_consulta_view_model.dart';
import 'regras_de_cancelamento.dart';
import 'situacao_da_consulta.dart';

/// Os detalhes de uma consulta, abertos do Início ou de Minhas consultas.
Route<void> rotaDosDetalhes(ConsultaNaLista item, {DateTime Function() relogio = DateTime.now}) {
  return MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) => DetalhesDaConsultaViewModel(
        item,
        consultas: contexto.read<RepositorioDeConsultas>(),
        relogio: relogio,
      ),
      child: const DetalhesDaConsultaScreen(),
    ),
  );
}

/// Detalhes da consulta: o dia e a hora em destaque (checklist, item 8.3), o
/// status com texto e ícone (1.7), onde e quanto, o mapa e o telefone da
/// clínica (2.9, 10.3), as regras de cancelamento (10.2) e o que dá para
/// fazer agora — pagar, cancelar ou agendar de novo (3.4, 7.6).
class DetalhesDaConsultaScreen extends StatelessWidget {
  const DetalhesDaConsultaScreen({super.key});

  Future<void> _cancelar(BuildContext context, DetalhesDaConsultaViewModel vm) async {
    final confirmada = vm.consulta.status == StatusDaConsulta.confirmada;
    if (!await confirmarCancelamento(context, confirmada: confirmada)) return;
    final cancelou = await vm.cancelar();
    if (cancelou && context.mounted) mostrarRetorno(context, TipoDeRetorno.sucesso, 'Consulta cancelada.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<DetalhesDaConsultaViewModel>();
    final tema = Theme.of(context);
    final fixo = rodapeFixo(context);
    final (:consulta, :horario, :profissional) = vm.item;
    final clinica = profissional.clinica;
    final nota = _nota(vm);

    final conteudo = [
      if (vm.demorando) ...[
        const Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando),
        const SizedBox(height: Espaco.medio),
      ],
      Semantics(
        header: true,
        child: Text(
          diaEHora(horario.dia, horario.hora, hoje: vm.hoje),
          style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: Espaco.pequeno),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: SeloDeStatus(status: consulta.status, motivo: consulta.motivoDoCancelamento),
      ),
      const SizedBox(height: Espaco.medio),
      if (nota != null) ...[nota, const SizedBox(height: Espaco.medio)],
      CartaoDaConsulta(
        profissional: profissional,
        horario: horario,
        // O valor que a API congelou ao reservar, e não o do profissional.
        valorFormatado: consulta.valorFormatado,
        hoje: vm.hoje,
      ),
      if (clinica != null) ...[
        const SizedBox(height: Espaco.pequeno),
        AtalhosDaClinica(clinica: clinica, rotuloDeLigar: 'Ligar para a clínica'),
      ],
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: () => mostrarRegrasDeCancelamento(context, telefone: clinica?.telefone),
          icon: const Icon(Icons.info_outline),
          label: const Text('Regras de cancelamento'),
        ),
      ),
    ];
    final acao = [
      if (vm.erro case final erro?) ...[
        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
        const SizedBox(height: Espaco.medio),
      ],
      if (vm.podePagar) ...[
        BotaoPrincipal(
          rotulo: 'Pagar agora',
          aoTocar: vm.cancelando
              ? null
              : () => Navigator.of(context).push(rotaDoPagamento(
                    consulta,
                    profissional: profissional,
                    horario: horario,
                    relogio: vm.relogio,
                    reaberta: true,
                  )),
        ),
        const SizedBox(height: Espaco.pequeno),
      ],
      if (vm.podeCancelar)
        BotaoDestrutivo(
          rotulo: 'Cancelar consulta',
          enviando: vm.cancelando,
          rotuloEnviando: 'Cancelando…',
          aoTocar: () => _cancelar(context, vm),
        )
      else
        BotaoPrincipal(
          rotulo: 'Agendar de novo',
          aoTocar: () => Navigator.of(context).push(rotaDoProfissional(profissional, relogio: vm.relogio)),
        ),
    ];

    return PopScope(
      // Com o cancelamento no ar, sair deixaria a pessoa sem saber se cancelou.
      canPop: !vm.cancelando,
      child: Scaffold(
        appBar: AppBar(title: const Text('Detalhes da consulta')),
        // Como no pagamento: os botões ficam fixos no rodapé e, sem altura
        // para isso, vão para o fim da lista, que rola inteira.
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

  /// O que a situação pede que se diga, além do selo.
  Widget? _nota(DetalhesDaConsultaViewModel vm) {
    final consulta = vm.consulta;
    if (vm.reservaVencida) {
      return const Aviso(
        tipo: TipoDeRetorno.aviso,
        texto: 'O prazo para pagar esta reserva terminou. Se você já pagou, a confirmação ainda pode chegar.',
      );
    }
    return switch ((consulta.status, consulta.motivoDoCancelamento, consulta.reservaExpiraEm)) {
      (StatusDaConsulta.pendentePagamento, _, final prazo?) when vm.podePagar =>
        Nota(icone: Icons.lock_clock, texto: 'Seu horário fica reservado até ${horaNaClinica(prazo)}.'),
      (StatusDaConsulta.cancelada, MotivoDoCancelamento.paciente, _) => const Nota(
          icone: Icons.info_outline,
          texto: 'Você cancelou esta consulta. Se ela já estava paga, o valor é devolvido integralmente.',
        ),
      (StatusDaConsulta.cancelada, MotivoDoCancelamento.reservaExpirada, _) => const Nota(
          icone: Icons.timer_off_outlined,
          texto: 'O prazo para pagar esta reserva terminou, e o horário voltou a ficar livre.',
        ),
      (StatusDaConsulta.cancelada, _, _) => const Nota(icone: Icons.info_outline, texto: 'Esta consulta foi cancelada.'),
      _ => null,
    };
  }
}
