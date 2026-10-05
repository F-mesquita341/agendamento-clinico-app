import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'especialidades_view_model.dart';

/// Primeira tela da Etapa 11: prova o caminho inteiro — aplicativo, rede, API
/// publicada, banco — com a rota pública mais simples. Vira a tela de busca na
/// Etapa 13.
class EspecialidadesScreen extends StatelessWidget {
  const EspecialidadesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<EspecialidadesViewModel>();
    return Scaffold(
      appBar: AppBar(title: const Text('Especialidades')),
      body: switch (vm.estado) {
        EstadoDaCarga.carregando => _Carregando(demorando: vm.demorando),
        EstadoDaCarga.falhou => _Falha(mensagem: vm.erro!.mensagem, tentarDeNovo: vm.carregar),
        // Puxar para atualizar mantém a lista na tela; se a atualização
        // falhar, a lista anterior fica e um aviso diz por quê.
        EstadoDaCarga.pronto => RefreshIndicator(
            onRefresh: vm.carregar,
            child: ListView(
              children: [
                if (vm.erroAoAtualizar case final erro?) _AvisoDeAtualizacao(mensagem: erro.mensagem),
                if (vm.itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Nenhuma especialidade cadastrada ainda.'),
                  ),
                for (final especialidade in vm.itens) ListTile(title: Text(especialidade.nome)),
              ],
            ),
          ),
      },
    );
  }
}

class _AvisoDeAtualizacao extends StatelessWidget {
  const _AvisoDeAtualizacao({required this.mensagem});

  final String mensagem;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Container(
      color: cores.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Semantics(
        liveRegion: true,
        child: Text(
          'Não foi possível atualizar. $mensagem',
          style: TextStyle(color: cores.onErrorContainer),
        ),
      ),
    );
  }
}

class _Carregando extends StatelessWidget {
  const _Carregando({required this.demorando});

  final bool demorando;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            // liveRegion: o leitor de tela anuncia a troca da mensagem.
            Semantics(
              liveRegion: true,
              child: Text(
                // Não afirma a causa: com o servidor fora do ar, a conexão
                // também fica pendurada, e "acordando" seria mentira.
                demorando
                    ? 'O servidor está demorando para responder. Se ele estava parado, o primeiro acesso pode levar até um minuto.'
                    : 'Carregando…',
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Falha extends StatelessWidget {
  const _Falha({required this.mensagem, required this.tentarDeNovo});

  final String mensagem;
  final Future<void> Function() tentarDeNovo;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(liveRegion: true, child: Text(mensagem, textAlign: TextAlign.center)),
            const SizedBox(height: 16),
            FilledButton(onPressed: tentarDeNovo, child: const Text('Tentar de novo')),
          ],
        ),
      ),
    );
  }
}
