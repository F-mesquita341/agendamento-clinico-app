import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/comum/botoes.dart';
import 'package:agendamento_clinico/ui/comum/estados_de_carga.dart';
import 'package:agendamento_clinico/ui/comum/marca.dart';
import 'package:agendamento_clinico/ui/comum/retorno.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> montar(WidgetTester tester, Widget corpo) async {
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: Scaffold(body: Padding(padding: const EdgeInsets.all(16), child: corpo)),
  ));
}

void main() {
  group('botão principal', () {
    testWidgets('enviando, fica desabilitado e mostra o indicador no lugar do texto', (tester) async {
      var toques = 0;
      await montar(tester, BotaoPrincipal(rotulo: 'Entrar', aoTocar: () => toques++, enviando: true));

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      // O segundo toque não dispara um segundo pedido (checklist 1.2 e 5.3).
      expect(toques, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      // O leitor de tela continua sabendo que botão é.
      expect(find.bySemanticsLabel(RegExp('Entrar, enviando')), findsOneWidget);
    });

    testWidgets('enviando com o que dizer: o indicador e o texto, e o leitor lê o texto', (tester) async {
      var toques = 0;
      await montar(
        tester,
        BotaoPrincipal(
          rotulo: 'Confirmar',
          aoTocar: () => toques++,
          enviando: true,
          rotuloEnviando: 'Reservando o horário…',
        ),
      );

      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(toques, 0);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Reservando o horário…'), findsOneWidget);
      expect(find.text('Confirmar'), findsNothing);
      expect(find.bySemanticsLabel('Reservando o horário…'), findsOneWidget);
    });

    testWidgets('fora do envio, o texto de enviando não aparece', (tester) async {
      await montar(
        tester,
        BotaoPrincipal(rotulo: 'Confirmar', aoTocar: () {}, rotuloEnviando: 'Reservando o horário…'),
      );

      expect(find.text('Confirmar'), findsOneWidget);
      expect(find.text('Reservando o horário…'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('fora do envio, toca e mostra o rótulo', (tester) async {
      var toques = 0;
      await montar(tester, BotaoPrincipal(rotulo: 'Entrar', aoTocar: () => toques++));

      await tester.tap(find.text('Entrar'));

      expect(toques, 1);
    });

    testWidgets('ocupa a largura toda e tem 56 dp de altura', (tester) async {
      await montar(tester, BotaoPrincipal(rotulo: 'Entrar', aoTocar: () {}));

      final tamanho = tester.getSize(find.byType(FilledButton));
      expect(tamanho.width, tester.getSize(find.byType(Scaffold)).width - 32);
      expect(tamanho.height, greaterThanOrEqualTo(56));
    });
  });

  group('botões secundário e de texto', () {
    testWidgets('o secundário tem a mesma altura do principal', (tester) async {
      await montar(tester, BotaoSecundario(rotulo: 'Criar conta', aoTocar: () {}));

      expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(56));
    });

    testWidgets('o destrutivo tem a cor de erro, no texto e na borda, e a altura dos outros', (tester) async {
      await montar(tester, BotaoDestrutivo(rotulo: 'Sair da conta', aoTocar: () {}));

      final erro = temaDoApp().colorScheme.error;
      final estilo = tester.widget<OutlinedButton>(find.byType(OutlinedButton)).style!;
      expect(estilo.foregroundColor!.resolve({}), erro);
      expect(estilo.side!.resolve({})!.color, erro);
      expect(tester.getSize(find.byType(OutlinedButton)).height, greaterThanOrEqualTo(56));
    });

    testWidgets('o destrutivo, enviando, fica travado e diz o que está fazendo', (tester) async {
      var toques = 0;
      await montar(
        tester,
        BotaoDestrutivo(rotulo: 'Cancelar consulta', aoTocar: () => toques++, enviando: true, rotuloEnviando: 'Cancelando…'),
      );

      expect(find.text('Cancelando…'), findsOneWidget);
      expect(find.text('Cancelar consulta'), findsNothing);
      expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed, isNull);
      await tester.tap(find.byType(OutlinedButton));
      expect(toques, 0);
    });

    testWidgets('o de texto, mesmo com rótulo curto, tem 48 dp também no que se vê', (tester) async {
      await montar(tester, Align(child: BotaoDeTexto(rotulo: 'Ok', aoTocar: () {})));

      // A área de toque de 48 dp o tema já garante; aqui é a forma visível do
      // botão — o realce ao tocar — que não fica menor que ela.
      final forma = tester.getSize(find.descendant(of: find.byType(TextButton), matching: find.byType(Material)));
      expect(forma.width, greaterThanOrEqualTo(48));
      expect(forma.height, greaterThanOrEqualTo(48));
    });
  });

  group('retorno ao paciente', () {
    for (final (tipo, icone) in [
      (TipoDeRetorno.sucesso, Icons.check_circle_outline),
      (TipoDeRetorno.aviso, Icons.info_outline),
      (TipoDeRetorno.erro, Icons.error_outline),
    ]) {
      testWidgets('$tipo tem sempre o mesmo ícone, e o texto junto — nunca só a cor', (tester) async {
        await montar(
          tester,
          Builder(
            builder: (context) => TextButton(
              onPressed: () => mostrarRetorno(context, tipo, 'Dados salvos.'),
              child: const Text('mostrar'),
            ),
          ),
        );

        await tester.tap(find.text('mostrar'));
        await tester.pump();

        expect(find.text('Dados salvos.'), findsOneWidget);
        expect(find.byIcon(icone), findsOneWidget);
      });
    }

    testWidgets('cada tipo tem a própria cor de fundo (checklist 4.6)', (tester) async {
      await montar(
        tester,
        Column(children: [for (final tipo in TipoDeRetorno.values) Aviso(tipo: tipo, texto: '$tipo')]),
      );

      final fundos = tester
          .widgetList<Container>(find.descendant(of: find.byType(Aviso), matching: find.byType(Container)))
          .map((caixa) => (caixa.decoration! as BoxDecoration).color)
          .toSet();
      expect(fundos, hasLength(TipoDeRetorno.values.length));
    });

    testWidgets('o aviso na tela usa o mesmo padrão do retorno passageiro', (tester) async {
      await montar(tester, const Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível atualizar.'));

      expect(find.text('Não foi possível atualizar.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('marca', () {
    testWidgets('é um texto só: o leitor de tela lê o nome inteiro', (tester) async {
      await montar(tester, const Marca(tamanho: 40));

      expect(find.bySemanticsLabel('Marcaí'), findsOneWidget);
    });

    testWidgets('com texto a 200% e pouca largura, encolhe para caber inteira, sem corte', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: const MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: Align(alignment: Alignment.topLeft, child: SizedBox(width: 200, child: Marca(tamanho: 60))),
          ),
        ),
      ));

      final texto = find.descendant(of: find.byType(Marca), matching: find.byType(RichText));
      final paragrafo = tester.renderObject<RenderParagraph>(texto);
      // Inteira: o texto foi disposto na largura que pede, e não espremido.
      expect(paragrafo.size.width, greaterThanOrEqualTo(paragrafo.getMaxIntrinsicWidth(double.infinity) - 0.5));
      // E cabe: na tela, não passa da largura que tem.
      expect(tester.getRect(texto).width, lessThanOrEqualTo(200.5));
    });
  });

  group('falha de carga', () {
    testWidgets('a segunda saída aparece quando existe, e funciona', (tester) async {
      var saiu = false;
      await montar(
        tester,
        FalhaDeCarga(
          mensagem: 'Não foi possível falar com o servidor.',
          tentarDeNovo: () {},
          outraSaida: (rotulo: 'Sair da conta', aoTocar: () => saiu = true),
        ),
      );

      await tester.tap(find.text('Sair da conta'));

      expect(saiu, isTrue);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });
}
