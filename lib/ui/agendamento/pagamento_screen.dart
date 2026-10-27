import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../data/services/abridor_de_links.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/confirmacao.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../comum/retorno.dart';
import '../comum/textos.dart';
import '../consultas/regras_de_cancelamento.dart';
import '../profissional/profissional_screen.dart';
import '../shell/abas_do_shell.dart';
import 'cartao_da_consulta.dart';
import 'consulta_confirmada_screen.dart';
import 'etapa_do_agendamento.dart';
import 'pagamento_antecipado.dart';
import 'reserva_view_model.dart';

/// A tela do pagamento, aberta no lugar da grade e do resumo: voltar dela leva
/// ao shell, e nunca de novo ao resumo, que reservaria duas vezes.
///
/// [reaberta]: aberta por "Pagar agora", no Início ou nos detalhes da
/// consulta — sem a etapa do agendamento, porque ninguém está no meio dele.
Route<void> rotaDoPagamento(
  Consulta consulta, {
  required Profissional profissional,
  required Horario horario,
  required DateTime Function() relogio,
  bool reaberta = false,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) => ReservaViewModel(
        consulta,
        consultas: contexto.read<RepositorioDeConsultas>(),
        abridor: contexto.read<AbridorDeLinks>(),
        profissional: profissional,
        horario: horario,
        relogio: relogio,
      ),
      child: PagamentoScreen(reaberta: reaberta),
    ),
  );
}

/// Etapa 3 de 3: o horário reservado, até quando a reserva vale, e o
/// pagamento antecipado, feito na página do Mercado Pago em ambiente de teste
/// (TCC, Seção 3.9.5). O aplicativo só abre a página: não coleta cartão.
class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key, this.reaberta = false});

  /// Reaberta por "Pagar agora": sem "Etapa 3 de 3".
  final bool reaberta;

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  late final ReservaViewModel _vm;
  late final AppLifecycleListener _ciclo;
  bool _seguiu = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ReservaViewModel>();
    _vm.addListener(_reagir);
    // Fechar a aba de pagamento devolve o aplicativo para a frente: é a hora
    // de perguntar à API se o pagamento chegou.
    _ciclo = AppLifecycleListener(onResume: _vm.aoVoltar);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _vm.removeListener(_reagir);
    super.dispose();
  }

  /// A situação decidida pela API leva a tela adiante, uma vez só: confirmada,
  /// para a confirmação; encerrada, para a folha que explica.
  void _reagir() {
    if (!mounted || _seguiu) return;
    switch (_vm.situacao) {
      case SituacaoDoPagamento.confirmada:
        _seguiu = true;
        unawaited(Navigator.of(context).pushAndRemoveUntil(
          rotaDaConsultaConfirmada(
            _vm.confirmada!,
            profissionalDeAntes: _vm.profissional,
            horarioDeAntes: _vm.horario,
            hoje: _vm.hoje,
          ),
          (rota) => rota.isFirst,
        ));
      case SituacaoDoPagamento.encerrada:
        _seguiu = true;
        unawaited(_avisarQueAcabou());
      case SituacaoDoPagamento.cancelada:
        // A reserva cancelada aparece em Minhas consultas, com a nota dela.
        _seguiu = true;
        context.read<AbasDoShell>().mostrar(AbaDoShell.consultas);
        mostrarRetorno(context, TipoDeRetorno.sucesso, 'Consulta cancelada.');
        Navigator.of(context).popUntil((rota) => rota.isFirst);
      default:
        break;
    }
  }

  Future<void> _avisarQueAcabou() async {
    final deNovo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contexto) => _ReservaEncerrada(
        motivo: _vm.motivoDoFim,
        pagamentoTalvezFeito: _vm.pagamentoTalvezFeito,
        telefone: _vm.profissional.clinica?.telefone,
      ),
    );
    if (!mounted) return;
    final navegador = Navigator.of(context);
    if (deNovo ?? false) {
      // A grade do mesmo profissional, carregada de novo.
      unawaited(navegador.pushReplacement(rotaDoProfissional(_vm.profissional, relogio: _vm.relogio)));
    } else {
      navegador.popUntil((rota) => rota.isFirst);
    }
  }

  /// Sair sem pagar pergunta antes: a reserva continua valendo, e o caminho de
  /// volta a ela é Minhas consultas.
  Future<void> _perguntarSeSai() async {
    final reservado = switch (_vm.ateAs) {
      final ateAs? => 'o horário fica reservado até $ateAs e depois volta a ficar livre.',
      null => 'o horário fica reservado por um tempo e depois volta a ficar livre.',
    };
    // Com a página de pagamento já aberta, a pessoa pode ter pago: sair não a
    // faz perder a consulta, e o diálogo não pode dar a entender que faz.
    final sai = await confirmar(
      context,
      titulo: _vm.abriuOCheckout ? 'Sair do pagamento?' : 'Sair sem pagar?',
      texto: '${_vm.abriuOCheckout ? 'Se você já pagou, a confirmação chega mesmo assim. Se não pagou, $reservado' : comInicialMaiuscula(reservado)} '
          'Para pagar depois, abra a consulta em Minhas consultas.',
      acao: 'Sair',
      desistir: 'Continuar pagamento',
    );
    if (sai && mounted) Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  /// "Cancelar reserva" pergunta antes, com o mesmo diálogo dos detalhes da
  /// consulta (checklist, itens 3.4 e 5.7).
  Future<void> _cancelarReserva() async {
    if (!await confirmarCancelamento(context, confirmada: false)) return;
    await _vm.cancelarReserva();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReservaViewModel>();
    final tema = Theme.of(context);
    final situacao = vm.situacao;
    final acabou = situacao == SituacaoDoPagamento.confirmada ||
        situacao == SituacaoDoPagamento.encerrada ||
        situacao == SituacaoDoPagamento.cancelada;
    final fonteGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final conteudo = [
      if (vm.demorando) ...[
        const Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando),
        const SizedBox(height: Espaco.medio),
      ],
      ..._situacaoNoTopo(vm),
      CartaoDaConsulta(
        profissional: vm.profissional,
        horario: vm.horario,
        // O valor que a API congelou ao reservar, e não o do profissional.
        valorFormatado: vm.consulta.valorFormatado,
        hoje: vm.hoje,
      ),
      const SizedBox(height: Espaco.grande),
      const PagamentoAntecipado(
        complemento: 'Ele é feito na página do Mercado Pago, que abre a seguir. Depois de pagar, volte para o aplicativo.',
      ),
    ];
    final acao = [
      if (vm.erro case final erro?) ...[
        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
        const SizedBox(height: Espaco.medio),
      ],
      const _AmbienteDeTeste(),
      if (!acabou) ...[
        const SizedBox(height: Espaco.pequeno),
        BotaoPrincipal(
          rotulo: vm.abriuOCheckout ? 'Abrir pagamento de novo' : 'Abrir o pagamento',
          rotuloEnviando: switch (situacao) {
            SituacaoDoPagamento.abrindo => 'Abrindo o pagamento…',
            SituacaoDoPagamento.cancelando => 'Cancelando a reserva…',
            _ => 'Conferindo o pagamento…',
          },
          enviando: situacao == SituacaoDoPagamento.abrindo ||
              situacao == SituacaoDoPagamento.conferindo ||
              situacao == SituacaoDoPagamento.conferindoDepoisDoPrazo ||
              situacao == SituacaoDoPagamento.cancelando,
          aoTocar: vm.abrirPagamento,
        ),
        if (vm.podeCancelarAReserva) ...[
          const SizedBox(height: Espaco.pequeno),
          Center(
            child: TextButton(
              style: TextButton.styleFrom(foregroundColor: tema.colorScheme.error),
              onPressed: _cancelarReserva,
              child: const Text('Cancelar reserva'),
            ),
          ),
        ],
      ],
    ];

    final cores = tema.colorScheme;
    return PopScope(
      // Sair sem pagar pergunta antes; depois de decidido, sai direto.
      canPop: acabou,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _perguntarSeSai();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Pagamento'),
          bottom: widget.reaberta ? null : etapaDoAgendamento(context, 3),
        ),
        body: SafeArea(
          // Como no resumo: o botão fica fixo no rodapé, e, com a fonte
          // grande, vai para o fim da lista, que rola inteira. O aviso de
          // ambiente de teste vai junto com ele.
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
                    if (acao.isNotEmpty)
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

  /// O que vai no topo, conforme a situação: o prazo correndo; a conferência
  /// em andamento; ou a volta sem confirmação, com o cuidado de não pagar duas
  /// vezes (checklist, itens 3.2 e 9.2).
  List<Widget> _situacaoNoTopo(ReservaViewModel vm) {
    final ateAs = vm.ateAs;
    final falta = vm.quantoFalta;
    final reservado = switch ((ateAs, falta)) {
      (final ateAs?, final falta?) => 'Seu horário fica reservado até $ateAs ($falta).',
      (final ateAs?, null) => 'A reserva terminou às $ateAs.',
      _ => null,
    };
    final Widget? topo = switch (vm.situacao) {
      SituacaoDoPagamento.conferindo => const Aviso(
          tipo: TipoDeRetorno.aviso,
          texto: 'Conferindo o pagamento… Isso leva alguns segundos.',
        ),
      SituacaoDoPagamento.conferindoDepoisDoPrazo => const Aviso(
          tipo: TipoDeRetorno.aviso,
          texto: 'O prazo terminou. Conferindo com o servidor se o pagamento chegou…',
        ),
      SituacaoDoPagamento.pendente => Aviso(
          tipo: TipoDeRetorno.aviso,
          texto: 'Ainda não recebemos a confirmação do pagamento. ${reservado ?? ''} '
              'Se você já pagou, não pague de novo: a confirmação pode levar até um minuto e '
              'aparece aqui sozinha.',
        ),
      _ => reservado == null ? null : Nota(icone: Icons.lock_clock, texto: reservado),
    };
    return [if (topo != null) ...[topo, const SizedBox(height: Espaco.medio)]];
  }
}

/// Sempre à vista, no rodapé, junto do botão: nenhuma sessão desta pesquisa
/// gera cobrança de verdade (TCC, pressuposto 2). No meio da lista, a nota da
/// volta sem confirmação o empurrava para fora da tela (portão de 20/10).
class _AmbienteDeTeste extends StatelessWidget {
  const _AmbienteDeTeste();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Espaco.pequeno,
      children: [
        ExcludeSemantics(child: Icon(Icons.science_outlined, color: tema.colorScheme.primary)),
        Expanded(
          child: Text(
            'Ambiente de teste: nenhum valor real é cobrado.',
            style: tema.textTheme.bodyMedium!.copyWith(color: tema.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}

/// A reserva acabou (checklist, itens 3.2 e 9.2): o porquê, e o caminho de
/// volta à grade. A mensagem do prazo é a mesma que a API dá quando recusa
/// pagar.
class _ReservaEncerrada extends StatelessWidget {
  const _ReservaEncerrada({required this.motivo, required this.pagamentoTalvezFeito, required this.telefone});

  final MotivoDoCancelamento? motivo;

  /// O prazo passou com o checkout aberto, e a API não decidiu a tempo.
  final bool pagamentoTalvezFeito;

  /// O telefone da clínica, para quem pagou e não viu a confirmação.
  final String? telefone;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final (titulo, texto) = motivo == MotivoDoCancelamento.paciente
        ? ('A reserva foi cancelada', 'Esta reserva foi cancelada. Se ainda quiser a consulta, escolha o horário de novo.')
        : ('A reserva expirou', 'O prazo para pagar esta reserva terminou. Escolha o horário de novo.');
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espaco.grande, 0, Espaco.grande, Espaco.grande),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Espaco.medio,
          children: [
            Icon(Icons.timer_off_outlined, size: 32, color: tema.colorScheme.onSurfaceVariant),
            Semantics(
              header: true,
              child: Text(titulo, style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800)),
            ),
            Text(texto, style: tema.textTheme.bodyLarge),
            if (pagamentoTalvezFeito)
              Text(
                switch (telefone) {
                  final telefone? => 'Se você já pagou, a confirmação ainda pode chegar. Em caso de dúvida, '
                      'ligue para a clínica: ${semQuebra(telefone)}.',
                  null => 'Se você já pagou, a confirmação ainda pode chegar. Em caso de dúvida, fale com a clínica.',
                },
                style: tema.textTheme.bodyLarge,
              ),
            BotaoPrincipal(rotulo: 'Escolher o horário de novo', aoTocar: () => Navigator.of(context).pop(true)),
            Center(child: BotaoDeTexto(rotulo: 'Agora não', aoTocar: () => Navigator.of(context).pop(false))),
          ],
        ),
      ),
    );
  }
}
