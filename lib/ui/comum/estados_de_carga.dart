import 'package:flutter/material.dart';

import 'botoes.dart';
import 'espaco.dart';
import 'textos.dart';

/// O estado de uma tela que carrega dados. Depois que eles apareceram,
/// atualizar não volta a `carregando`: o que está na tela fica enquanto o novo
/// chega.
enum EstadoDaCarga { carregando, pronto, falhou }

/// Carregando, com o aviso de servidor demorando quando a espera se alonga
/// (checklist, itens 1.1 e 9.6). Toda tela que carrega dados usa este, para
/// a espera ter a mesma cara em todo o aplicativo.
class IndicadorDeCarga extends StatelessWidget {
  const IndicadorDeCarga({super.key, required this.demorando});

  final bool demorando;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Espaco.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: Espaco.medio),
            // liveRegion: o leitor de tela anuncia a troca da mensagem.
            Semantics(
              liveRegion: true,
              child: Text(demorando ? Textos.servidorDemorando : Textos.carregando, textAlign: TextAlign.center),
            ),
          ],
        ),
      ),
    );
  }
}

/// Falha ao carregar: a mensagem — que a API já escreve para o paciente — e o
/// botão de tentar de novo. A tela nunca fica presa carregando.
class FalhaDeCarga extends StatelessWidget {
  const FalhaDeCarga({
    super.key,
    required this.mensagem,
    required this.tentarDeNovo,
    this.outraSaida,
  });

  final String mensagem;
  final VoidCallback tentarDeNovo;

  /// Uma segunda saída, quando tentar de novo não é a única coisa que a pessoa
  /// pode querer — "Sair da conta", por exemplo.
  final ({String rotulo, VoidCallback aoTocar})? outraSaida;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Espaco.grande),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(liveRegion: true, child: Text(mensagem, textAlign: TextAlign.center)),
            const SizedBox(height: Espaco.medio),
            BotaoPrincipal(rotulo: Textos.tentarDeNovo, aoTocar: tentarDeNovo),
            if (outraSaida case final saida?) ...[
              const SizedBox(height: Espaco.pequeno),
              BotaoSecundario(rotulo: saida.rotulo, aoTocar: saida.aoTocar),
            ],
          ],
        ),
      ),
    );
  }
}

/// Não há o que listar: o que aconteceu, por quê, e — quando há o que a
/// pessoa possa fazer — uma saída (checklist, item 8.8). Nunca uma tela em
/// branco.
class EstadoVazio extends StatelessWidget {
  const EstadoVazio({
    super.key,
    required this.icone,
    required this.titulo,
    required this.texto,
    this.saida,
  });

  final IconData icone;
  final String titulo;
  final String texto;
  final ({String rotulo, VoidCallback aoTocar})? saida;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaco.grande),
      child: Column(
        children: [
          // Reforço visual: o título já diz o que aconteceu.
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: cores.primaryContainer, borderRadius: BorderRadius.circular(20)),
            child: Icon(icone, size: 32, color: cores.primary),
          ),
          const SizedBox(height: Espaco.medio),
          // liveRegion: o leitor de tela anuncia que a busca não achou nada.
          Semantics(
            liveRegion: true,
            child: Text(titulo, style: tema.textTheme.titleMedium, textAlign: TextAlign.center),
          ),
          const SizedBox(height: Espaco.pequeno),
          Text(texto, textAlign: TextAlign.center, style: TextStyle(color: cores.onSurfaceVariant)),
          if (saida case final saida?) ...[
            const SizedBox(height: Espaco.medio),
            BotaoSecundario(rotulo: saida.rotulo, aoTocar: saida.aoTocar),
          ],
        ],
      ),
    );
  }
}
