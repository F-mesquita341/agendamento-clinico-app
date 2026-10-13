import 'package:flutter/material.dart';

// As cores do aplicativo, definidas uma única vez (checklist, item 4.1). Vêm do
// modelo visual (design/modelo/corrigido). As telas não usam estes valores:
// leem do tema, por `Theme.of(context)`.
const _ameixa = Color(0xFF6E2A5E);
const _ameixaEscura = Color(0xFF4A1840);
const _lilas = Color(0xFFF5E4EF);
const _fundo = Color(0xFFF8F4EE);
const _branco = Color(0xFFFFFFFF);
const _texto = Color(0xFF2B1E27);
const _textoDeApoio = Color(0xFF64565F);
const _borda = Color(0xFF8A7D84);
const _divisoria = Color(0xFFEADFD3);
const _realce = Color(0xFFEFE7DD);
const _erro = Color(0xFFA1261E);
const _fundoDoErro = Color(0xFFFBE6E4);

/// O âmbar da marca. É decoração — o "í" do nome, a arte da abertura — sempre
/// sobre a cor principal. Não leva texto, e não serve sobre o fundo claro.
const ambarDaMarca = Color(0xFFF2B544);

/// A fonte do aplicativo, como declarada em pubspec.yaml. Foi desenhada para
/// quem tem baixa visão: letras parecidas (I, l, 1; O, 0) têm formas distintas.
const familiaDaFonte = 'Atkinson Hyperlegible Next';

/// Um fundo e o texto que vai sobre ele.
typedef ParDeCores = ({Color fundo, Color texto});

/// As cores de retorno que o Material não tem: sucesso e aviso. O erro e a
/// informação já têm par no esquema de cores (`errorContainer` e
/// `primaryContainer`).
@immutable
class CoresDeRetorno extends ThemeExtension<CoresDeRetorno> {
  const CoresDeRetorno({required this.sucesso, required this.aviso});

  final ParDeCores sucesso;
  final ParDeCores aviso;

  // O aplicativo tem um tema só: não há outro para onde copiar ou transitar.
  @override
  CoresDeRetorno copyWith() => this;

  @override
  CoresDeRetorno lerp(CoresDeRetorno? outro, double t) => this;
}

/// O tema: cores, tipografia e a forma de cada componente, num lugar só.
///
/// As cores são escolhidas à mão, e por isso o contraste não vem de graça: que
/// cada par usado com texto chega aos 4,5:1 do WCAG 2.1 AA, e cada borda de
/// campo aos 3:1, é conferido por teste (test/config/tema_test.dart).
ThemeData temaDoApp() {
  // O que não é definido aqui continua derivado da cor principal.
  final esquema = ColorScheme.fromSeed(seedColor: _ameixa).copyWith(
    primary: _ameixa,
    onPrimary: _branco,
    primaryContainer: _lilas,
    onPrimaryContainer: _ameixaEscura,
    secondary: _ameixaEscura,
    onSecondary: _branco,
    secondaryContainer: _lilas,
    onSecondaryContainer: _ameixaEscura,
    surface: _fundo,
    onSurface: _texto,
    onSurfaceVariant: _textoDeApoio,
    // Cartões, campos, barra inferior e diálogos são brancos sobre o fundo.
    surfaceContainerLowest: _branco,
    surfaceContainerLow: _branco,
    surfaceContainer: _branco,
    surfaceContainerHigh: _branco,
    surfaceContainerHighest: _realce,
    outline: _borda,
    outlineVariant: _divisoria,
    error: _erro,
    onError: _branco,
    errorContainer: _fundoDoErro,
    onErrorContainer: _erro,
    // Sem o véu colorido que o Material 3 põe sobre as superfícies elevadas.
    surfaceTint: Colors.transparent,
  );

  final base = ThemeData(
    colorScheme: esquema,
    fontFamily: familiaDaFonte,
    // Área de toque mínima de 48 dp — acima dos 44 × 44 px do WCAG 2.1.
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
    extensions: const [
      CoresDeRetorno(
        sucesso: (fundo: Color(0xFFE2F2E8), texto: Color(0xFF14492F)),
        aviso: (fundo: Color(0xFFFFEFD6), texto: Color(0xFF6B3A00)),
      ),
    ],
    // Corpo de 16 e botões de 17: o texto do modelo é maior que o padrão do
    // Material, pensando em quem lê com dificuldade.
    textTheme: const TextTheme(
      headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, height: 1.15, letterSpacing: -0.5),
      headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.2, letterSpacing: 0),
      titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: 0),
      titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1.25, letterSpacing: 0),
      titleSmall: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0),
      bodyLarge: TextStyle(fontSize: 17, height: 1.5, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5, letterSpacing: 0),
      bodySmall: TextStyle(fontSize: 14, height: 1.45, letterSpacing: 0),
      labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: 0),
      // Rótulos pequenos (a barra inferior, por exemplo). O Material usa o
      // peso 500 aqui, que a fonte do aplicativo não traz como arquivo.
      labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0),
      labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0),
    ),
  );

  const capsula = StadiumBorder();
  const alturaDoBotao = Size(64, 56);
  const respiroDoBotao = EdgeInsets.symmetric(horizontal: 24, vertical: 8);
  OutlineInputBorder contorno(Color cor, double largura) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: cor, width: largura),
      );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: esquema.surface,
      // A barra não muda de cor quando o conteúdo rola por baixo dela.
      scrolledUnderElevation: 0,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: alturaDoBotao, shape: capsula, padding: respiroDoBotao),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: alturaDoBotao,
        shape: capsula,
        padding: respiroDoBotao,
        backgroundColor: esquema.surfaceContainerLowest,
        side: BorderSide(color: esquema.outline, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: capsula,
        // Partindo do estilo do tema, para o botão de texto não perder a fonte.
        textStyle: base.textTheme.labelLarge!.copyWith(fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: esquema.surfaceContainerLowest,
      contentPadding: const EdgeInsets.all(16),
      // O erro diz como corrigir (checklist, item 9.4): não pode ser cortado
      // em reticências quando não cabe numa linha.
      errorMaxLines: 3,
      border: contorno(esquema.outline, 1.5),
      enabledBorder: contorno(esquema.outline, 1.5),
      focusedBorder: contorno(esquema.primary, 2),
      errorBorder: contorno(esquema.error, 1.5),
      focusedErrorBorder: contorno(esquema.error, 2),
    ),
    cardTheme: CardThemeData(
      color: esquema.surfaceContainerLowest,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: esquema.outlineVariant),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Razão de contraste do WCAG 2.1 entre duas cores, de 1 a 21.
double razaoDeContraste(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final (clara, escura) = la > lb ? (la, lb) : (lb, la);
  return (clara + 0.05) / (escura + 0.05);
}
