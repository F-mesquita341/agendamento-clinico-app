import 'package:flutter/material.dart';

import 'botoes.dart';
import 'espaco.dart';
import 'textos.dart';

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
