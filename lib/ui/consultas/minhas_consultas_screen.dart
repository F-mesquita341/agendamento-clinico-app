import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../comum/botoes.dart';
import '../comum/chip_de_escolha.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/retorno.dart';
import '../comum/textos.dart';
import '../profissional/profissional_screen.dart';
import '../shell/abas_do_shell.dart';
import 'cartao_na_lista.dart';
import 'consultas_view_model.dart';
import 'detalhes_da_consulta_screen.dart';
import 'situacao_da_consulta.dart';

/// Minhas consultas: as próximas e as anteriores, cada uma com o status em
/// texto e ícone (checklist, itens 1.7 e 8.7), e o que fazer quando não há
/// nenhuma (8.8). Tocar numa consulta abre os detalhes.
class MinhasConsultasScreen extends StatefulWidget {
  const MinhasConsultasScreen({super.key});

  @override
  State<MinhasConsultasScreen> createState() => _MinhasConsultasScreenState();
}

class _MinhasConsultasScreenState extends State<MinhasConsultasScreen> {
  bool _anteriores = false;

  void _abrir(ConsultasViewModel vm, ConsultaNaLista item) =>
      Navigator.of(context).push(rotaDosDetalhes(item, relogio: vm.relogio));

  void _agendar() => context.read<AbasDoShell>().mostrar(AbaDoShell.buscar);

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConsultasViewModel>();
    final proximas = vm.proximas;
    final anteriores = vm.anteriores;

    return Scaffold(
      appBar: AppBar(title: const Text('Minhas consultas')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: vm.atualizar,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
            children: [
              if (vm.demorando && vm.estado == EstadoDaCarga.pronto && !vm.mostrandoMais) ...[
                const ComMargem(child: Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando)),
                const SizedBox(height: Espaco.medio),
              ],
              if (vm.erroAoAtualizar case final erro?) ...[
                ComMargem(
                  child: Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível atualizar. ${erro.mensagem}'),
                ),
                const SizedBox(height: Espaco.medio),
              ],
              ...switch (vm.estado) {
                EstadoDaCarga.carregando => [IndicadorDeCarga(demorando: vm.demorando)],
                EstadoDaCarga.falhou => [FalhaDeCarga(mensagem: vm.erro!.mensagem, tentarDeNovo: vm.carregar)],
                EstadoDaCarga.pronto => [
                    ComMargem(
                      child: Wrap(
                        spacing: Espaco.pequeno,
                        runSpacing: Espaco.pequeno,
                        children: [
                          ChipDeEscolha(
                            rotulo: 'Próximas (${proximas.length})',
                            escolhido: !_anteriores,
                            aoEscolher: () => setState(() => _anteriores = false),
                          ),
                          ChipDeEscolha(
                            rotulo: 'Anteriores (${vm.totalDeAnteriores})',
                            escolhido: _anteriores,
                            aoEscolher: () => setState(() => _anteriores = true),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Espaco.medio),
                    if (!_anteriores && proximas.isEmpty)
                      EstadoVazio(
                        icone: Icons.event_available_outlined,
                        titulo: 'Você ainda não tem consultas marcadas',
                        texto: 'Escolha um profissional e veja os horários livres.',
                        saida: (rotulo: 'Agendar consulta', aoTocar: _agendar),
                      )
                    else if (_anteriores && anteriores.isEmpty && !vm.temMais)
                      EstadoVazio(
                        icone: Icons.history,
                        titulo: 'Nenhuma consulta anterior',
                        texto: 'As consultas canceladas ou com a reserva expirada aparecem aqui.',
                        saida: (rotulo: 'Agendar consulta', aoTocar: _agendar),
                      )
                    else ...[
                      for (final item in _anteriores ? anteriores : proximas)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(Espaco.margem, 0, Espaco.margem, Espaco.medio),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              CartaoNaLista(item: item, hoje: vm.hoje, aoTocar: () => _abrir(vm, item)),
                              // Marcar de novo com quem já atendeu (checklist, item 7.6).
                              if (_anteriores)
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: TextButton.icon(
                                    onPressed: () => Navigator.of(context)
                                        .push(rotaDoProfissional(item.profissional, relogio: vm.relogio)),
                                    icon: const Icon(Icons.replay),
                                    label: Text('Agendar de novo com ${item.profissional.nome}'),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      if (_anteriores) ...[
                        if (vm.erroAoMostrarMais case final erro?) ...[
                          ComMargem(
                            child: Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível mostrar mais. ${erro.mensagem}'),
                          ),
                          const SizedBox(height: Espaco.medio),
                        ],
                        if (vm.mostrandoMais)
                          IndicadorDeCarga(demorando: vm.demorando)
                        else if (vm.temMais && !vm.atualizando)
                          ComMargem(
                            child: BotaoSecundario(rotulo: 'Mostrar mais consultas', aoTocar: vm.mostrarMais),
                          ),
                      ],
                    ],
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }
}
