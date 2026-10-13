import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/retorno.dart';
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
        EstadoDaCarga.carregando => IndicadorDeCarga(demorando: vm.demorando),
        EstadoDaCarga.falhou => FalhaDeCarga(mensagem: vm.erro!.mensagem, tentarDeNovo: vm.carregar),
        // Puxar para atualizar mantém a lista na tela; se a atualização
        // falhar, a lista anterior fica e um aviso diz por quê.
        EstadoDaCarga.pronto => RefreshIndicator(
            onRefresh: vm.carregar,
            child: ListView(
              children: [
                if (vm.erroAoAtualizar case final erro?)
                  Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível atualizar. ${erro.mensagem}'),
                if (vm.itens.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(Espaco.grande),
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
