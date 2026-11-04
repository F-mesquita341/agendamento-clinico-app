import 'package:flutter/material.dart';

import '../comum/espaco.dart';
import 'busca_view_model.dart';

/// A cidade da busca, no alto do Início e da Busca: "Quixadá, CE", ou "Todas
/// as cidades". Tocar abre a lista numa folha. Lido como um botão só: "Cidade:
/// Quixadá, CE. Trocar".
class SeletorDaCidade extends StatelessWidget {
  const SeletorDaCidade({super.key, required this.vm});

  final BuscaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final rotulo = vm.cidade?.rotulo ?? 'Todas as cidades';
    return _Seletor(
      icone: Icons.location_on_outlined,
      texto: rotulo,
      leitura: 'Cidade: $rotulo. Trocar',
      aoTocar: () => _escolher<int>(
        context,
        vm: vm,
        titulo: 'Onde você quer se consultar?',
        nenhum: 'Todas as cidades',
        opcoes: () => [for (final cidade in vm.cidades) (valor: cidade.id, rotulo: cidade.rotulo)],
        escolhido: vm.cidade?.id,
        semLista: 'Não foi possível carregar as cidades agora. A busca mostra todas.',
        aoEscolher: vm.escolherCidade,
      ),
    );
  }
}

/// O plano de saúde da busca: "Plano", ou "Plano: Unimed". Tocar abre a lista
/// numa folha.
class SeletorDoPlano extends StatelessWidget {
  const SeletorDoPlano({super.key, required this.vm});

  final BuscaViewModel vm;

  @override
  Widget build(BuildContext context) {
    final plano = vm.plano;
    return _Seletor(
      icone: Icons.health_and_safety_outlined,
      texto: plano == null ? 'Plano' : 'Plano: ${plano.nome}',
      leitura: plano == null ? 'Plano de saúde: qualquer um. Escolher' : 'Plano de saúde: ${plano.nome}. Trocar',
      aoTocar: () => _escolher<int>(
        context,
        vm: vm,
        titulo: 'Qual o seu plano de saúde?',
        nenhum: 'Qualquer plano, ou sem plano',
        opcoes: () => [for (final plano in vm.planos) (valor: plano.id, rotulo: plano.nome)],
        escolhido: plano?.id,
        semLista: 'Não foi possível carregar os planos agora.',
        aoEscolher: vm.escolherPlano,
      ),
    );
  }
}

/// O botão de um seletor: ícone, o que está escolhido, e a seta para baixo.
/// Quebra em mais linhas com o texto ampliado, em vez de cortar.
class _Seletor extends StatelessWidget {
  const _Seletor({required this.icone, required this.texto, required this.leitura, required this.aoTocar});

  final IconData icone;
  final String texto;
  final String leitura;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: leitura,
      excludeSemantics: true,
      child: OutlinedButton(
        onPressed: aoTocar,
        style: OutlinedButton.styleFrom(
          foregroundColor: cores.onSurface,
          padding: const EdgeInsets.symmetric(horizontal: Espaco.medio, vertical: Espaco.pequeno),
          minimumSize: const Size(48, 48),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icone, color: cores.primary),
            const SizedBox(width: Espaco.pequeno),
            Flexible(child: Text(texto)),
            const SizedBox(width: Espaco.pequeno),
            const Icon(Icons.expand_more),
          ],
        ),
      ),
    );
  }
}

/// A folha de escolha: a opção "nenhum" primeiro, depois a lista, com a
/// escolhida marcada. Se a lista não veio, pede de novo ao abrir; se ainda
/// assim não vier, diz isso, e a única opção é a "nenhum".
Future<void> _escolher<T>(
  BuildContext context, {
  required BuscaViewModel vm,
  required String titulo,
  required String nenhum,
  required List<({T valor, String rotulo})> Function() opcoes,
  required T? escolhido,
  required String semLista,
  required void Function(T? valor) aoEscolher,
}) async {
  if (opcoes().isEmpty) {
    await vm.tentarListasDeNovo();
    if (!context.mounted) return;
  }
  final escolha = await showModalBottomSheet<({T? valor})>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (contexto) {
      // Lida aqui, e não antes: a lista pode ter chegado no "tentar de novo".
      final atuais = opcoes();
      final tema = Theme.of(contexto);
      Widget opcao(T? valor, String rotulo) {
        final marcada = valor == escolhido;
        return ListTile(
          title: Text(rotulo),
          selected: marcada,
          trailing: marcada ? const Icon(Icons.check) : null,
          onTap: () => Navigator.pop(contexto, (valor: valor)),
        );
      }

      return SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: Espaco.medio),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Espaco.grande, 0, Espaco.grande, Espaco.pequeno),
              child: Semantics(
                header: true,
                child: Text(titulo, style: tema.textTheme.titleLarge!.copyWith(fontWeight: FontWeight.w800)),
              ),
            ),
            opcao(null, nenhum),
            for (final (:valor, :rotulo) in atuais) opcao(valor, rotulo),
            if (atuais.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Espaco.grande, vertical: Espaco.pequeno),
                child: Text(semLista, style: tema.textTheme.bodyMedium),
              ),
          ],
        ),
      );
    },
  );
  if (escolha != null) aoEscolher(escolha.valor);
}

