import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../domain/models/especialidade.dart';
import '../../domain/models/profissional.dart';
import '../comum/botoes.dart';
import '../comum/card_do_profissional.dart';
import '../comum/chip_de_escolha.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/retorno.dart';
import '../comum/textos.dart';
import 'busca_view_model.dart';

/// Buscar: as especialidades para escolher (checklist, item 6.3), o nome do
/// profissional para digitar (6.4) e a lista com o valor da consulta à vista
/// (5.10). A escolha de um profissional leva aos horários dele.
class BuscaScreen extends StatefulWidget {
  const BuscaScreen({super.key, required this.aoAbrir});

  /// O profissional que a pessoa tocou na lista.
  final void Function(Profissional profissional) aoAbrir;

  @override
  State<BuscaScreen> createState() => _BuscaScreenState();
}

class _BuscaScreenState extends State<BuscaScreen> {
  final _campo = TextEditingController();

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<BuscaViewModel>();
    final tema = Theme.of(context);
    final apoio = tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: tema.colorScheme.onSurfaceVariant);
    final achou = vm.estado == EstadoDaCarga.pronto && vm.profissionais.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Buscar')),
      body: SafeArea(
        // Tudo rola junto, o campo e os chips também: com o aparelho deitado
        // ou o texto ampliado, sobra pouca altura para a lista.
        child: RefreshIndicator(
          onRefresh: vm.atualizar,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
            children: [
              ComMargem(
                // A dica some quando há texto no campo; o nome dele, para o leitor
                // de tela, não.
                child: Semantics(
                  label: 'Buscar',
                  child: TextField(
                    controller: _campo,
                    onChanged: vm.aoDigitar,
                    textInputAction: TextInputAction.search,
                    // Nome de gente não é erro de digitação.
                    autocorrect: false,
                    decoration: InputDecoration(
                      hintText: 'Nome do profissional ou especialidade',
                      // Com o texto ampliado, a dica quebra em linhas em vez de ser cortada.
                      hintMaxLines: 3,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _campo.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Limpar o texto da busca',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _campo.clear();
                                vm.aoDigitar('');
                              },
                            ),
                      helperText: vm.textoCurto ? 'Busque por ao menos duas letras.' : null,
                      helperMaxLines: 2,
                    ),
                  ),
                ),
              ),
              if (vm.especialidades.isNotEmpty) ...[
                const SizedBox(height: Espaco.medio),
                _Especialidades(vm: vm),
              ],
              // Na lista vazia, a saída é o botão do próprio aviso.
              if (achou || (vm.temFiltro && vm.estado != EstadoDaCarga.pronto))
                ComMargem(
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: Espaco.pequeno,
                    children: [
                      if (achou)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
                          // liveRegion: o leitor de tela anuncia o resultado da busca.
                          child: Semantics(liveRegion: true, child: Text(_contagem(vm.total), style: apoio)),
                        ),
                      if (vm.temFiltro)
                        TextButton.icon(
                          onPressed: () => _ficarSoCom(vm, null),
                          icon: const Icon(Icons.filter_alt_off_outlined),
                          label: const Text('Limpar filtros'),
                        ),
                    ],
                  ),
                )
              else
                const SizedBox(height: Espaco.medio),
              for (final sugerida in vm.sugestoes)
                ComMargem(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => _ficarSoCom(vm, sugerida),
                      icon: const Icon(Icons.arrow_forward),
                      label: Text('Ver profissionais de ${sugerida.nome}'),
                    ),
                  ),
                ),
              // Com a lista na tela, uma espera longa — atualizar — também avisa.
              // A do "mostrar mais" avisa no fim da lista, onde a pessoa está.
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
                EstadoDaCarga.pronto when vm.profissionais.isEmpty => [
                    EstadoVazio(
                      icone: Icons.person_search_outlined,
                      titulo: 'Nenhum profissional encontrado',
                      texto: _razaoDoVazio(vm),
                      saida: vm.temFiltro ? (rotulo: 'Limpar filtros', aoTocar: () => _ficarSoCom(vm, null)) : null,
                    ),
                  ],
                EstadoDaCarga.pronto => [
                    for (final profissional in vm.profissionais)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Espaco.margem, 0, Espaco.margem, Espaco.medio),
                        child: CardDoProfissional(
                          profissional: profissional,
                          aoTocar: () => widget.aoAbrir(profissional),
                        ),
                      ),
                    if (vm.erroAoMostrarMais case final erro?) ...[
                      ComMargem(
                        child: Aviso(
                          tipo: TipoDeRetorno.erro,
                          texto: 'Não foi possível mostrar mais. ${erro.mensagem}',
                        ),
                      ),
                      const SizedBox(height: Espaco.medio),
                    ],
                    if (vm.mostrandoMais)
                      IndicadorDeCarga(demorando: vm.demorando)
                    else if (vm.temMais)
                      ComMargem(
                        child: BotaoSecundario(rotulo: 'Mostrar mais profissionais', aoTocar: vm.mostrarMais),
                      ),
                  ],
              },
            ],
          ),
        ),
      ),
    );
  }

  /// Apaga o texto do campo junto com o filtro: fica só a especialidade dada —
  /// a sugerida —, ou nenhum filtro.
  void _ficarSoCom(BuscaViewModel vm, Especialidade? especialidade) {
    _campo.clear();
    if (especialidade == null) {
      vm.limparFiltros();
    } else {
      vm.aceitarSugestao(especialidade);
    }
  }
}

String _contagem(int total) => total == 1 ? '1 profissional' : '$total profissionais';

/// Por que a lista veio vazia, com o que a pessoa pode fazer a respeito.
String _razaoDoVazio(BuscaViewModel vm) {
  final especialidade = vm.especialidade?.nome;
  return switch ((vm.termo, especialidade)) {
    (final termo?, final nome?) =>
      'Nenhum profissional de $nome com "$termo" no nome. Confira o nome digitado ou escolha outra especialidade.',
    (final termo?, null) => 'Nenhum profissional com "$termo" no nome. Confira o nome digitado.',
    (null, final nome?) => 'Ainda não há profissionais de $nome no aplicativo.',
    (null, null) => 'Ainda não há profissionais no aplicativo.',
  };
}

/// Os chips de especialidade, numa linha que rola para o lado.
class _Especialidades extends StatelessWidget {
  const _Especialidades({required this.vm});

  final BuscaViewModel vm;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Filtrar por especialidade',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
        child: Row(
          children: [
            ChipDeEscolha(
              rotulo: 'Todas',
              escolhido: vm.especialidadeId == null,
              aoEscolher: () => vm.escolherEspecialidade(null),
            ),
            for (final especialidade in vm.especialidades) ...[
              const SizedBox(width: Espaco.pequeno),
              ChipDeEscolha(
                rotulo: especialidade.nome,
                escolhido: vm.especialidadeId == especialidade.id,
                aoEscolher: () => vm.escolherEspecialidade(especialidade.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
