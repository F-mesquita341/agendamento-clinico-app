import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/consultas/regras_de_cancelamento.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Uma tela com um botão que faz [acao] e guarda o que ela devolveu.
  Future<List<Object?>> montar(WidgetTester tester, Future<Object?> Function(BuildContext) acao) async {
    final devolvidos = <Object?>[];
    await tester.pumpWidget(MaterialApp(
      theme: temaDoApp(),
      home: Builder(
        builder: (contexto) => Scaffold(
          body: Center(
            child: TextButton(onPressed: () async => devolvidos.add(await acao(contexto)), child: const Text('Abrir')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('Abrir'));
    await tester.pumpAndSettle();
    return devolvidos;
  }

  group('confirmar o cancelamento', () {
    testWidgets('da consulta confirmada: o horário livre e a devolução integral', (tester) async {
      final devolvidos = await montar(tester, (c) => confirmarCancelamento(c, confirmada: true));

      expect(find.text('Cancelar esta consulta?'), findsOneWidget);
      expect(
        find.text('Ao cancelar, o horário volta a ficar livre para outras pessoas. '
            'O valor pago é devolvido integralmente.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar consulta'));
      await tester.pumpAndSettle();
      expect(devolvidos, [true]);
    });

    testWidgets('da reserva que aguarda: não afirma que a pessoa não pagou', (tester) async {
      final devolvidos = await montar(tester, (c) => confirmarCancelamento(c, confirmada: false));

      expect(
        find.text('Esta consulta ainda aguarda a confirmação do pagamento. Ao cancelar, o horário volta a ficar '
            'livre para outras pessoas. Se você já pagou, o valor é devolvido integralmente.'),
        findsOneWidget,
      );
      expect(find.textContaining('não pagou'), findsNothing);

      await tester.tap(find.text('Manter consulta'));
      await tester.pumpAndSettle();
      expect(devolvidos, [false]);
    });

    testWidgets('o botão diz a ação, na cor de ação destrutiva', (tester) async {
      await montar(tester, (c) => confirmarCancelamento(c, confirmada: true));

      final botao = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Cancelar consulta'));
      final cores = Theme.of(tester.element(find.text('Cancelar consulta'))).colorScheme;
      expect(botao.style?.foregroundColor?.resolve({}), cores.error);
    });
  });

  group('regras de cancelamento', () {
    testWidgets('dizem até quando, o que acontece com o valor, e o telefone da clínica; "Entendi" fecha', (
      tester,
    ) async {
      await montar(tester, (c) => mostrarRegrasDeCancelamento(c, telefone: '(88) 3000-0000'));

      expect(find.text('Regras de cancelamento'), findsOneWidget);
      expect(
        find.text('Você pode cancelar pelo aplicativo até o horário da consulta. Ao cancelar, o horário volta a '
            'ficar livre para outras pessoas, e o valor pago é devolvido integralmente. Se faltar sem cancelar, o '
            'valor não é devolvido. Em caso de dúvida, ligue para a clínica: (88)\u00a03000-0000.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();
      expect(find.text('Regras de cancelamento'), findsNothing);
    });

    testWidgets('sem o telefone da clínica, mandam falar com ela', (tester) async {
      await montar(tester, (c) => mostrarRegrasDeCancelamento(c));

      expect(find.textContaining('Em caso de dúvida, fale com a clínica.'), findsOneWidget);
      expect(find.textContaining('ligue'), findsNothing);
    });
  });
}
