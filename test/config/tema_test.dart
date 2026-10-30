import 'package:agendamento_clinico/config/tema.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.1 AA: contraste mínimo de 4,5:1 entre texto e fundo (critério 1.4.3)
/// e de 3:1 nas bordas que delimitam um componente (critério 1.4.11).
///
/// As cores do tema são escolhidas à mão, a partir do modelo visual, e por
/// isso o contraste não vem de graça como vinha com a paleta derivada: cada
/// par usado numa tela está aqui. Trocar uma cor para "acertar a identidade"
/// derruba o par afetado.
void main() {
  final tema = temaDoApp();
  final esquema = tema.colorScheme;
  final retorno = tema.extension<CoresDeRetorno>()!;
  final branco = esquema.surfaceContainerLowest;

  // O chip como o tema o pinta em cada estado, e não só as cores do esquema.
  final chip = tema.chipTheme;
  const escolhido = {WidgetState.selected};
  Color fundoDoChip(Set<WidgetState> estados) => chip.color!.resolve(estados)!;
  Color textoDoChip(Set<WidgetState> estados) =>
      WidgetStateProperty.resolveAs<Color?>(chip.labelStyle!.color, estados)!;
  final bordaDoChip = WidgetStateProperty.resolveAs<BorderSide?>(chip.side, {})!.color;

  test('a fórmula de contraste dá os extremos conhecidos', () {
    expect(razaoDeContraste(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(razaoDeContraste(Colors.white, Colors.white), closeTo(1, 0.01));
  });

  final textos = <String, (Color, Color)>{
    'texto sobre o fundo': (esquema.onSurface, esquema.surface),
    'texto de apoio sobre o fundo': (esquema.onSurfaceVariant, esquema.surface),
    'texto sobre o branco de cartões e campos': (esquema.onSurface, branco),
    'texto de apoio sobre o branco de cartões e campos': (esquema.onSurfaceVariant, branco),
    'texto sobre a cor principal (botões)': (esquema.onPrimary, esquema.primary),
    'texto sobre o contêiner principal': (esquema.onPrimaryContainer, esquema.primaryContainer),
    'texto sobre o contêiner secundário (indicador da barra inferior)': (
      esquema.onSecondaryContainer,
      esquema.secondaryContainer,
    ),
    'cor principal como texto sobre o fundo (links, botões de texto)': (esquema.primary, esquema.surface),
    'cor principal como texto sobre o branco (botão secundário)': (esquema.primary, branco),
    'texto de erro sobre o fundo': (esquema.error, esquema.surface),
    'texto de erro sobre o branco': (esquema.error, branco),
    'retorno de erro': (esquema.onErrorContainer, esquema.errorContainer),
    'retorno de sucesso': (retorno.sucesso.texto, retorno.sucesso.fundo),
    'retorno de aviso': (retorno.aviso.texto, retorno.aviso.fundo),
    'chip': (textoDoChip({}), fundoDoChip({})),
    'chip escolhido': (textoDoChip(escolhido), fundoDoChip(escolhido)),
    'texto claro sobre a cor principal (abertura)': (esquema.primaryContainer, esquema.primary),
    'selo de cancelada': (esquema.onSurface, esquema.surfaceContainerHighest),
  };

  for (final MapEntry(key: nome, value: (texto, fundo)) in textos.entries) {
    test('$nome passa de 4,5:1', () {
      expect(razaoDeContraste(texto, fundo), greaterThanOrEqualTo(4.5));
    });
  }

  // As bordas como os componentes as usam de fato, e não só a cor do esquema.
  final campo = tema.inputDecorationTheme;
  final bordaDoCampo = (campo.enabledBorder! as OutlineInputBorder).borderSide.color;
  final bordaDoBotao = tema.outlinedButtonTheme.style!.side!.resolve({})!.color;
  final bordas = <String, (Color, Color)>{
    'borda de campo sobre o fundo': (bordaDoCampo, esquema.surface),
    'borda de campo sobre o preenchimento do próprio campo': (bordaDoCampo, campo.fillColor!),
    'borda do botão secundário sobre o fundo': (bordaDoBotao, esquema.surface),
    'borda do chip sobre o fundo': (bordaDoChip, esquema.surface),
    'borda do chip sobre o próprio chip': (bordaDoChip, fundoDoChip({})),
    'chip escolhido sobre o fundo': (fundoDoChip(escolhido), esquema.surface),
    'ícone de marcado sobre o chip escolhido': (chip.iconTheme!.color!, fundoDoChip(escolhido)),
    // A marca é texto grande, e o "í" dela é a única coisa em âmbar que se lê.
    'âmbar da marca sobre a cor principal': (ambarDaMarca, esquema.primary),
    'ícone principal sobre o contêiner principal (estado vazio, lembretes)': (esquema.primary, esquema.primaryContainer),
  };

  for (final MapEntry(key: nome, value: (borda, fundo)) in bordas.entries) {
    test('$nome passa de 3:1', () {
      expect(razaoDeContraste(borda, fundo), greaterThanOrEqualTo(3));
    });
  }

  test('área de toque mínima de 48 dp', () {
    expect(tema.materialTapTargetSize, MaterialTapTargetSize.padded);
  });
}
