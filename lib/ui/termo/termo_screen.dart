import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import 'termo_view_model.dart';
import 'texto_do_termo.dart';

/// O termo de consentimento, antes do cadastro (checklist, item 10.4).
///
/// Primeiro um resumo em tópicos, depois o texto inteiro, e o aceite no fim:
/// para chegar à caixa, a pessoa passa pelo texto que está aceitando. A caixa
/// começa desmarcada.
class TermoScreen extends StatelessWidget {
  const TermoScreen({super.key, required this.aoContinuar, required this.aoSair});

  /// Segue para o cadastro com a versão aceita.
  final void Function(String versao) aoContinuar;

  /// Recusar o termo é uma saída legítima: sair da conta.
  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<TermoViewModel>();
    final sair = (rotulo: 'Sair da conta', aoTocar: aoSair);
    return Scaffold(
      appBar: AppBar(title: const Text('Termo de consentimento')),
      body: SafeArea(
        child: switch (vm.estado) {
          EstadoDoTermo.carregando => IndicadorDeCarga(demorando: vm.demorando),
          EstadoDoTermo.falhou => FalhaDeCarga(mensagem: vm.erro!.mensagem, tentarDeNovo: vm.carregar, outraSaida: sair),
          EstadoDoTermo.desatualizado => _Desatualizado(aoSair: aoSair),
          EstadoDoTermo.pronto => ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: [
                Text(
                  'Antes de completar o cadastro, leia como seus dados são tratados.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: Espaco.medio),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(Espaco.medio),
                    child: TextoDoTermo(vm.resumo!),
                  ),
                ),
                const SizedBox(height: Espaco.grande),
                TextoDoTermo(vm.texto!),
                const Divider(),
                CheckboxListTile(
                  value: vm.aceito,
                  onChanged: (marcado) => vm.marcarAceite(marcado ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: Text('Li e aceito o termo de consentimento (versão ${vm.versao}).'),
                ),
                if (!vm.aceito)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Espaco.pequeno),
                    child: Text(
                      'Marque a caixa acima para continuar.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
                const SizedBox(height: Espaco.pequeno),
                BotaoPrincipal(
                  rotulo: 'Continuar',
                  aoTocar: vm.podeContinuar ? () => aoContinuar(vm.versao!) : null,
                ),
                const SizedBox(height: Espaco.pequeno),
                BotaoDeTexto(rotulo: 'Sair da conta', aoTocar: aoSair),
              ],
            ),
        },
      ),
    );
  }
}

class _Desatualizado extends StatelessWidget {
  const _Desatualizado({required this.aoSair});

  final VoidCallback aoSair;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Atualize o aplicativo', style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: Espaco.medio),
            const Text(
              'O termo de consentimento mudou, e esta versão do aplicativo não tem o texto novo. '
              'Para completar o cadastro, instale a versão mais recente do aplicativo.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Espaco.grande),
            BotaoSecundario(rotulo: 'Sair da conta', aoTocar: aoSair),
          ],
        ),
      ),
    );
  }
}
