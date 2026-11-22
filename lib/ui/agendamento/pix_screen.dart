import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/pix.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/nota.dart';
import '../comum/retorno.dart';
import 'pagamento_screen.dart';
import 'pix_view_model.dart';
import 'reserva_view_model.dart';

/// A tela do Pix, aberta por cima do Pagamento. Fecha sozinha quando a API
/// decide, devolvendo a consulta — confirmada, ou cancelada pelo prazo —, e
/// é o Pagamento que leva a pessoa adiante. "Voltar" devolve null: o Pix
/// continua aberto, e pedi-lo de novo traz o mesmo.
Route<Consulta?> rotaDoPix(Pix pix, ReservaViewModel reserva) {
  return MaterialPageRoute<Consulta?>(
    builder: (_) => MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: reserva),
        ChangeNotifierProvider(
          create: (contexto) => PixViewModel(
            pix,
            consultaId: reserva.consulta.id,
            consultas: contexto.read<RepositorioDeConsultas>(),
            relogio: reserva.relogio,
          ),
        ),
      ],
      child: const PixScreen(),
    ),
  );
}

/// O QR Code, o "copia e cola", o valor e o prazo, e a espera pela confirmação
/// (contrato da versão 2, "Pix"). Em ambiente de teste: nenhum valor real é
/// cobrado.
class PixScreen extends StatefulWidget {
  const PixScreen({super.key});

  @override
  State<PixScreen> createState() => _PixScreenState();
}

class _PixScreenState extends State<PixScreen> {
  late final PixViewModel _vm;
  late final AppLifecycleListener _ciclo;
  bool _fechou = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<PixViewModel>();
    _vm.addListener(_reagir);
    // Quem volta do app do banco não espera o intervalo para saber se pagou.
    _ciclo = AppLifecycleListener(onResume: _vm.aoVoltar);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _vm.removeListener(_reagir);
    super.dispose();
  }

  /// A API decidiu, ou o prazo esgotou: a tela fecha, uma vez só, e entrega a
  /// consulta ao Pagamento.
  void _reagir() {
    if (!mounted || _fechou) return;
    if (_vm.decidida != null || _vm.esgotou) {
      _fechou = true;
      Navigator.of(context).pop(_vm.decidida);
    }
  }

  Future<void> _copiar() async {
    await Clipboard.setData(ClipboardData(text: _vm.pix.copiaECola));
    if (mounted) mostrarRetorno(context, TipoDeRetorno.sucesso, 'Código copiado.');
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PixViewModel>();
    final reserva = context.watch<ReservaViewModel>();
    final tema = Theme.of(context);
    final pix = vm.pix;
    final prazo = switch ((reserva.ateAs, reserva.quantoFalta)) {
      (final ateAs?, final falta?) => 'Pague até $ateAs ($falta).',
      (final ateAs?, null) => 'O prazo terminou às $ateAs.',
      _ => null,
    };

    return Scaffold(
      appBar: AppBar(title: const Text('Pagar com Pix')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaco.margem),
          children: [
            if (vm.indisponivel)
              const Aviso(
                tipo: TipoDeRetorno.erro,
                texto: 'O Pix não está disponível agora. Volte e use a página do Mercado Pago.',
              )
            else
              const Nota(
                icone: Icons.hourglass_top,
                texto: 'Aguardando o pagamento… A confirmação aparece aqui sozinha.',
              ),
            const SizedBox(height: Espaco.medio),
            if (prazo != null) ...[
              Nota(icone: Icons.lock_clock, texto: prazo),
              const SizedBox(height: Espaco.medio),
            ],
            Semantics(
              header: true,
              child: Text('Valor: ${pix.valorFormatado}', style: tema.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
            ),
            const SizedBox(height: Espaco.medio),
            Text(
              'No app do seu banco, escolha pagar com Pix e leia o QR Code ou cole o código.',
              style: tema.textTheme.bodyLarge,
            ),
            const SizedBox(height: Espaco.grande),
            if (pix.qrCode case final bytes?)
              Center(
                // Fundo branco também no tema escuro: o leitor do banco precisa
                // do contraste do QR Code.
                child: ColoredBox(
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(Espaco.medio),
                    child: Image.memory(
                      bytes,
                      width: 240,
                      height: 240,
                      semanticLabel: 'QR Code do Pix',
                      errorBuilder: (_, _, _) => const _SemQrCode(),
                    ),
                  ),
                ),
              )
            else
              const _SemQrCode(),
            const SizedBox(height: Espaco.grande),
            BotaoPrincipal(rotulo: 'Copiar código', aoTocar: _copiar),
            const SizedBox(height: Espaco.medio),
            const AmbienteDeTeste(),
          ],
        ),
      ),
    );
  }
}

/// Quando a imagem não veio ou não abre, o código continua valendo.
class _SemQrCode extends StatelessWidget {
  const _SemQrCode();

  @override
  Widget build(BuildContext context) {
    return const Aviso(
      tipo: TipoDeRetorno.aviso,
      texto: 'Não foi possível mostrar o QR Code. Use o botão "Copiar código" e cole no app do seu banco.',
    );
  }
}
