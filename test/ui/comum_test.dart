import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/comum/botoes.dart';
import 'package:agendamento_clinico/ui/comum/estados_de_carga.dart';
import 'package:agendamento_clinico/ui/comum/retorno.dart';
import 'package:flutter/material.dart';
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

    testWidgets('fora do envio, toca e mostra o rótulo', (tester) async {
      var toques = 0;
      await montar(tester, BotaoPrincipal(rotulo: 'Entrar', aoTocar: () => toques++));

      await tester.tap(find.text('Entrar'));

      expect(toques, 1);
    });

    testWidgets('ocupa a largura toda e tem ao menos 48 dp de altura', (tester) async {
      await montar(tester, BotaoPrincipal(rotulo: 'Entrar', aoTocar: () {}));

      final tamanho = tester.getSize(find.byType(FilledButton));
      expect(tamanho.width, tester.getSize(find.byType(Scaffold)).width - 32);
      expect(tamanho.height, greaterThanOrEqualTo(48));
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

    testWidgets('o aviso na tela usa o mesmo padrão do retorno passageiro', (tester) async {
      await montar(tester, const Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível atualizar.'));

      expect(find.text('Não foi possível atualizar.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
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
