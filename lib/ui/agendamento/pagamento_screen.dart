import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/consulta.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../profissional/profissional_screen.dart';
import 'cartao_da_consulta.dart';
import 'etapa_do_agendamento.dart';
import 'pagamento_antecipado.dart';
import 'reserva_view_model.dart';

/// A tela do pagamento, aberta no lugar da grade e do resumo: voltar dela leva
/// à busca, e nunca de novo ao resumo, que reservaria duas vezes.
Route<void> rotaDoPagamento(
  Consulta consulta, {
  required Profissional profissional,
  required Horario horario,
  required DateTime Function() relogio,
}) {
  return MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ReservaViewModel(consulta, profissional: profissional, horario: horario, relogio: relogio),
      child: const PagamentoScreen(),
    ),
  );
}

/// Etapa 3 de 3: o horário reservado e até quando a reserva vale. O botão de
/// pagar entra nesta tela na Etapa 15.
class PagamentoScreen extends StatefulWidget {
  const PagamentoScreen({super.key});

  @override
  State<PagamentoScreen> createState() => _PagamentoScreenState();
}

class _PagamentoScreenState extends State<PagamentoScreen> {
  late final ReservaViewModel _vm;
  bool _avisouQueExpirou = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ReservaViewModel>();
    _vm.addListener(_conferirPrazo);
    // A reserva achada depois de uma resposta perdida pode chegar já vencida.
    WidgetsBinding.instance.addPostFrameCallback((_) => _conferirPrazo());
  }

  @override
  void dispose() {
    _vm.removeListener(_conferirPrazo);
    super.dispose();
  }

  /// O prazo venceu: a folha que explica abre sozinha, uma vez só.
  void _conferirPrazo() {
    if (!mounted || _avisouQueExpirou || !_vm.expirou) return;
    _avisouQueExpirou = true;
    _avisarQueExpirou();
  }

  Future<void> _avisarQueExpirou() async {
    final deNovo = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (contexto) => const _ReservaExpirada(),
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

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReservaViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Pagamento'), bottom: etapaDoAgendamento(context, 3)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaco.margem),
          children: [
            if (vm.ateAs case final ateAs?) ...[
              Nota(
                icone: Icons.lock_clock,
                texto: switch (vm.quantoFalta) {
                  final falta? => 'Seu horário fica reservado até $ateAs ($falta).',
                  null => 'A reserva terminou às $ateAs.',
                },
              ),
              const SizedBox(height: Espaco.medio),
            ],
            CartaoDaConsulta(
              profissional: vm.profissional,
              horario: vm.horario,
              // O valor que a API congelou ao reservar, e não o do profissional.
              valorFormatado: vm.consulta.valorFormatado,
              hoje: vm.hoje,
            ),
            const SizedBox(height: Espaco.grande),
            const PagamentoAntecipado(),
          ],
        ),
      ),
    );
  }
}

/// A reserva venceu (checklist, item 9.2): o porquê, e o caminho de volta à
/// grade. A mensagem é a mesma que a API dá quando recusa pagar.
class _ReservaExpirada extends StatelessWidget {
  const _ReservaExpirada();

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
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
              child: Text(
                'A reserva expirou',
                style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'O prazo para pagar esta reserva terminou. Escolha o horário de novo.',
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
