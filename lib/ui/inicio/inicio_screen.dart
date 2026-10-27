import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/instante.dart';
import '../agendamento/pagamento_screen.dart';
import '../busca/busca_view_model.dart';
import '../busca/sugestoes.dart';
import '../comum/botoes.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/retorno.dart';
import '../comum/textos.dart';
import '../consultas/cartao_na_lista.dart';
import '../consultas/consultas_view_model.dart';
import '../consultas/detalhes_da_consulta_screen.dart';
import '../consultas/situacao_da_consulta.dart';
import '../shell/abas_do_shell.dart';

/// Início: a reserva que espera o pagamento, com o caminho de volta a ela; a
/// próxima consulta em destaque, com o endereço (checklist, itens 6.2 e 8.3);
/// e, sem consulta nenhuma, o convite para agendar (8.8). Embaixo, o atalho
/// da busca e as especialidades, com o nome comum de cada uma (2.7).
class InicioScreen extends StatelessWidget {
  const InicioScreen({super.key});

  Future<void> _atualizar(BuildContext context) async {
    final busca = context.read<BuscaViewModel>();
    await Future.wait([
      context.read<ConsultasViewModel>().atualizar(),
      // As especialidades vêm da busca; se não vieram, tenta de novo.
      if (busca.especialidades.isEmpty) busca.carregar(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConsultasViewModel>();
    final busca = context.watch<BuscaViewModel>();
    final abas = context.read<AbasDoShell>();
    final tema = Theme.of(context);
    final titulo = tema.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800);

    return Scaffold(
      appBar: AppBar(title: const Text('Início')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => _atualizar(context),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
            children: [
              ComMargem(child: _AtalhoDaBusca(aoTocar: () => abas.mostrar(AbaDoShell.buscar))),
              const SizedBox(height: Espaco.grande),
              if (vm.demorando && vm.estado == EstadoDaCarga.pronto) ...[
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
                    if (vm.reservaAguardando case final reserva?) ...[
                      ComMargem(child: _ReservaAguardando(item: reserva, vm: vm)),
                      const SizedBox(height: Espaco.grande),
                    ],
                    if (vm.proximaConfirmada case final proxima?) ...[
                      ComMargem(
                        child: Row(
                          children: [
                            Expanded(
                              child: Semantics(header: true, child: Text('Sua próxima consulta', style: titulo)),
                            ),
                            TextButton(
                              onPressed: () => abas.mostrar(AbaDoShell.consultas),
                              child: const Text('Ver todas'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: Espaco.pequeno),
                      ComMargem(
                        child: CartaoNaLista(
                          item: proxima,
                          hoje: vm.hoje,
                          comEndereco: true,
                          aoTocar: () => Navigator.of(context).push(rotaDosDetalhes(proxima, relogio: vm.relogio)),
                        ),
                      ),
                      const SizedBox(height: Espaco.grande),
                    ],
                    if (vm.reservaAguardando == null && vm.proximaConfirmada == null)
                      EstadoVazio(
                        icone: Icons.event_available_outlined,
                        titulo: 'Você ainda não tem consultas',
                        texto: 'Escolha um profissional e veja os horários livres.',
                        saida: (rotulo: 'Agendar consulta', aoTocar: () => abas.mostrar(AbaDoShell.buscar)),
                      ),
                  ],
              },
              if (busca.especialidades.isNotEmpty) ...[
                const SizedBox(height: Espaco.medio),
                ComMargem(child: Semantics(header: true, child: Text('Especialidades', style: titulo))),
                const SizedBox(height: Espaco.pequeno),
                for (final especialidade in busca.especialidades)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
                    leading: const Icon(Icons.medical_services_outlined),
                    title: Text(especialidade.nome),
                    subtitle: switch (apoioDaEspecialidade(especialidade)) {
                      final apoio? => Text(comInicialMaiuscula(apoio)),
                      null => null,
                    },
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      busca.mostrarEspecialidade(especialidade.id);
                      abas.mostrar(AbaDoShell.buscar);
                    },
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// O atalho para a busca, com a cara do campo dela: tocar abre a aba Buscar.
class _AtalhoDaBusca extends StatelessWidget {
  const _AtalhoDaBusca({required this.aoTocar});

  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Semantics(
      button: true,
      child: Material(
        color: cores.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(color: cores.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: aoTocar,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Espaco.medio, vertical: Espaco.pequeno),
              child: Row(
                spacing: Espaco.medio,
                children: [
                  ExcludeSemantics(child: Icon(Icons.search, color: cores.onSurfaceVariant)),
                  Expanded(
                    child: Text(
                      'Buscar profissional ou especialidade',
                      style: tema.textTheme.bodyLarge!.copyWith(color: cores.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A reserva que aguarda o pagamento, com o prazo e o caminho de volta a ela
/// — "Pagar agora" reabre a tela do pagamento (checklist, item 3.2).
class _ReservaAguardando extends StatelessWidget {
  const _ReservaAguardando({required this.item, required this.vm});

  final ConsultaNaLista item;
  final ConsultasViewModel vm;

  @override
  Widget build(BuildContext context) {
    final (:consulta, :horario, :profissional) = item;
    final ateAs = switch (consulta.reservaExpiraEm) {
      final prazo? => ' Seu horário fica reservado até ${horaNaClinica(prazo)}.',
      null => '',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Espaco.medio,
      children: [
        Aviso(
          tipo: TipoDeRetorno.aviso,
          texto: 'Reserva aguardando pagamento. ${profissional.nome}, '
              '${diaEHora(horario.dia, horario.hora, hoje: vm.hoje)}.$ateAs',
        ),
        BotaoPrincipal(
          rotulo: 'Pagar agora',
          aoTocar: () => Navigator.of(context).push(rotaDoPagamento(
            consulta,
            profissional: profissional,
            horario: horario,
            relogio: vm.relogio,
            reaberta: true,
          )),
        ),
      ],
    );
  }
}
