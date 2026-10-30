import 'dart:math' as math;

import 'package:agendamento_clinico/ui/comum/retorno.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// Um aparelho para a conferência de acessibilidade: o tamanho da tela, a
/// escala do texto e as barras do sistema — a de status em cima e, em pé, a de
/// navegação embaixo. Sem as barras, o teste não veria uma folha passando por
/// baixo da barra de status, nem um rodapé que não cabe.
typedef Aparelho = ({String nome, Size tela, double fonte, FakeViewPadding barras});

/// Os quatro aparelhos da Etapa 18 (WCAG 2.1 AA: 1.3.4, retrato e paisagem;
/// 1.4.4, texto a 200%).
const aparelhos = <Aparelho>[
  (nome: 'em pé, a 100%', tela: Size(411, 891), fonte: 1, barras: FakeViewPadding(top: 24, bottom: 48)),
  (nome: 'em pé e estreito, a 200%', tela: Size(360, 640), fonte: 2, barras: FakeViewPadding(top: 24, bottom: 48)),
  (nome: 'deitado, a 100%', tela: Size(891, 411), fonte: 1, barras: FakeViewPadding(top: 24)),
  (nome: 'deitado, a 200%', tela: Size(891, 411), fonte: 2, barras: FakeViewPadding(top: 24)),
];

final aparelhoEmPe = aparelhos[0];
final aparelhoDeitado = aparelhos[2];

/// Põe a tela que já está montada no [aparelho]. Com [assentar] falso — telas
/// com um indicador girando, que nunca assentam —, avança meio segundo.
Future<void> usarAparelho(WidgetTester tester, Aparelho aparelho, {bool assentar = true}) async {
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = aparelho.tela
    ..padding = aparelho.barras
    ..viewPadding = aparelho.barras;
  tester.platformDispatcher.textScaleFactorTestValue = aparelho.fonte;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  await _assentar(tester, assentar);
}

/// Confere a tela como ela está, nos quatro aparelhos: nada estoura, e as três
/// diretrizes do Flutter — toque de 48 dp, rótulo em tudo o que se toca,
/// contraste de 4,5:1 no texto — valem na tela parada. Rótulo e contraste
/// valem também do começo ao fim da lista, percorrida página a página: as
/// diretrizes só olham o que está à vista. O toque não: rolando, um botão
/// cortado pela borda da lista — que, com o rodapé fixo, não é a borda da
/// tela — aparece com 5 dp de altura, e a diretriz o conta como alvo pequeno.
/// O tamanho de verdade é o do tema, conferido na tela parada.
///
/// [lista] diz qual é a lista da tela quando há mais de uma rolagem vertical;
/// sem ela, é a primeira.
Future<void> conferirNosQuatroAparelhos(WidgetTester tester, {Finder? lista, bool assentar = true}) async {
  for (final aparelho in aparelhos) {
    await usarAparelho(tester, aparelho, assentar: assentar);
    await conferirAcessibilidade(tester, lista: lista, assentar: assentar, motivo: aparelho.nome);
  }
}

/// A conferência num aparelho só: o que está aplicado agora.
Future<void> conferirAcessibilidade(
  WidgetTester tester, {
  Finder? lista,
  bool assentar = true,
  String motivo = '',
}) async {
  final semantica = tester.ensureSemantics();
  expect(tester.takeException(), isNull, reason: 'estouro $motivo');
  _semTextoCortado(motivo);
  await _diretrizes(tester, motivo);

  final rolagem = lista ?? listaVertical();
  if (rolagem.evaluate().isNotEmpty) {
    final posicao = tester.state<ScrollableState>(rolagem.first).position;
    while (posicao.pixels < posicao.maxScrollExtent) {
      posicao.jumpTo(math.min(posicao.pixels + posicao.viewportDimension * 0.8, posicao.maxScrollExtent));
      await _assentar(tester, assentar);
      expect(tester.takeException(), isNull, reason: 'estouro $motivo, rolando');
      _semTextoCortado('$motivo, rolando');
      await _diretrizes(tester, '$motivo, rolando', toque: false);
    }
    posicao.jumpTo(0);
    await _assentar(tester, assentar);
  }
  semantica.dispose();
}

/// A rolagem vertical da tela: a da lista, e não a de uma faixa que rola de
/// lado, como a dos dias.
Finder listaVertical() => find.byWidgetPredicate(
      (widget) => widget is Scrollable && axisDirectionToAxis(widget.axisDirection) == Axis.vertical,
    );

/// Um aviso que fica até a pessoa fechar — o do lembrete, com "Ver" — não
/// cobre o [botao] do rodapé fixo. Com o rodapé no corpo da tela, o aviso
/// ficaria por cima dele; na barra de baixo do Scaffold, o aviso sobe.
Future<void> conferirAvisoAcimaDoRodape(WidgetTester tester, Finder botao) async {
  await usarAparelho(tester, aparelhoEmPe);
  mostrarRetorno(
    tester.element(botao),
    TipoDeRetorno.aviso,
    'Você tem uma consulta amanhã às 14:30.',
    acao: (rotulo: 'Ver', aoTocar: () {}),
  );
  await tester.pumpAndSettle();
  expect(tester.getRect(find.byType(SnackBar)).bottom, lessThanOrEqualTo(tester.getRect(botao).top));
  expect(botao.hitTestable(), findsOneWidget);
  ScaffoldMessenger.of(tester.element(botao)).removeCurrentSnackBar();
  await tester.pumpAndSettle();
}

/// O nó do leitor de tela que delimita a tela em que [alvo] está: é a troca
/// dele que faz o TalkBack anunciar uma tela nova.
SemanticsNode noDaTela(WidgetTester tester, Finder alvo) {
  SemanticsNode? no = tester.getSemantics(alvo);
  while (no != null && !no.getSemanticsData().flagsCollection.scopesRoute) {
    no = no.parent;
  }
  if (no == null) throw StateError('nenhum nó de tela acima de $alvo');
  return no;
}

/// Um texto com menos altura do que precisa não estoura: o Flutter o corta em
/// silêncio, sem erro, e nenhuma diretriz vê. Foi assim com um diálogo que não
/// rola, deitado a 200%. Texto com limite de linhas não entra: ali o corte é
/// pedido, e o texto medido já é o das linhas que cabem.
///
/// Os rótulos da barra de navegação ficam de fora: o Flutter limita a escala
/// deles a 130%, e na fonte dos testes, de letras quadradas, "Minhas" sozinho
/// passa dos 90 dp do destino num celular de 360 e quebra no meio. Com a fonte
/// de verdade, "Minhas consultas" cabe em duas linhas (medido em 28/10/2026).
void _semTextoCortado(String motivo) {
  final daBarra = find
      .descendant(of: find.byType(NavigationBar), matching: find.byType(RichText))
      .evaluate()
      .toSet();
  for (final elemento in find.byType(RichText).evaluate()) {
    if (daBarra.contains(elemento)) continue;
    final paragrafo = elemento.renderObject! as RenderParagraph;
    if (!paragrafo.hasSize) continue;
    expect(
      paragrafo.size.height,
      greaterThanOrEqualTo(paragrafo.textSize.height - 0.5),
      reason: 'texto cortado $motivo: "${paragrafo.text.toPlainText()}"',
    );
  }
}

Future<void> _diretrizes(WidgetTester tester, String motivo, {bool toque = true}) async {
  if (toque) await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: 'toque $motivo');
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: 'rótulo $motivo');
  await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'contraste $motivo');
}

Future<void> _assentar(WidgetTester tester, bool assentar) async {
  if (assentar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump(const Duration(milliseconds: 500));
  }
}
