import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/ui/agendamento/pagamento_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/reserva_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/agenda.dart';
import '../apoio/falsos.dart';

/// O relógio que a tela lê: o teste o adianta junto com o tempo do teste.
DateTime agora = meioDiaDeQuarta;

final escolhido = horario(3, 15, 14, minuto: 30);

/// Reservada ao meio-dia na clínica; o prazo, 15 minutos depois — 12:15. O
/// valor congelado na consulta é outro que o do profissional (R$ 250,00).
Consulta reserva({Duration falta = const Duration(minutes: 15)}) => Consulta(
      id: 50,
      status: StatusDaConsulta.pendentePagamento,
      horarioId: escolhido.id,
      valorFormatado: 'R\$ 200,00',
      reservaExpiraEm: meioDiaDeQuarta.add(falta),
    );

ReservaViewModel reservaVm(Consulta consulta) =>
    ReservaViewModel(consulta, profissional: timbo, horario: escolhido, relogio: () => agora);

const tituloDaFolha = 'A reserva expirou';

void main() {
  setUp(() => agora = meioDiaDeQuarta);

  group('reserva, no view model', () {
    test('até quando, na hora da clínica, e quanto falta, no minuto mais próximo', () {
      final vm = reservaVm(reserva());
      addTearDown(vm.dispose);

      expect(vm.ateAs, '12:15');
      expect(vm.quantoFalta, 'faltam 15\u00a0minutos');
      expect(vm.expirou, isFalse);

      agora = meioDiaDeQuarta.add(const Duration(minutes: 1, seconds: 1));
      expect(vm.quantoFalta, 'faltam 14\u00a0minutos');
      agora = meioDiaDeQuarta.add(const Duration(minutes: 1, seconds: 31));
      expect(vm.quantoFalta, 'faltam 13\u00a0minutos');
      agora = meioDiaDeQuarta.add(const Duration(minutes: 13, seconds: 59));
      expect(vm.quantoFalta, 'falta 1\u00a0minuto');
    });

    // O portão pegou: com o relógio do aparelho uns segundos atrás do
    // servidor, logo depois de reservar faltavam "16 minutos" de 15.
    test('o relógio do aparelho uns segundos atrás do servidor não vira 16 minutos', () {
      final vm = reservaVm(reserva());
      addTearDown(vm.dispose);

      agora = meioDiaDeQuarta.subtract(const Duration(seconds: 3));
      expect(vm.quantoFalta, 'faltam 15\u00a0minutos');
      // E, no sentido contrário, 14 minutos e meio arredondam para baixo.
      agora = meioDiaDeQuarta.add(const Duration(seconds: 31));
      expect(vm.quantoFalta, 'faltam 14\u00a0minutos');
    });

    test('no último minuto, "falta menos de 1 minuto"; no prazo, vencida', () {
      final vm = reservaVm(reserva());
      addTearDown(vm.dispose);

      agora = meioDiaDeQuarta.add(const Duration(minutes: 14));
      expect(vm.quantoFalta, 'falta menos de 1\u00a0minuto');
      expect(vm.expirou, isFalse);

      agora = meioDiaDeQuarta.add(const Duration(minutes: 15));
      expect(vm.quantoFalta, isNull);
      expect(vm.expirou, isTrue);
    });

    test('sem prazo, nada a contar, e nada vencido', () {
      final vm = ReservaViewModel(
        Consulta(id: 50, status: StatusDaConsulta.pendentePagamento, horarioId: 3, valorFormatado: 'R\$ 200,00'),
        profissional: timbo,
        horario: escolhido,
        relogio: () => agora,
      );
      addTearDown(vm.dispose);

      expect((vm.ateAs, vm.quantoFalta, vm.expirou), (null, null, false));
    });
  });

  group('pagamento, na tela', () {
    late CatalogoFalso catalogo;

    /// Uma tela por baixo, que abre o pagamento como o resumo abriria.
    Future<void> abrir(WidgetTester tester, Consulta consulta, {List<Object?> horarios = const []}) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogo = CatalogoFalso(horarios: horarios);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<RepositorioDoCatalogo>.value(value: catalogo),
          Provider<AbridorDeLinks>.value(value: AbridorDeLinksFalso()),
        ],
        child: MaterialApp(
          theme: temaDoApp(),
          home: Builder(
            builder: (contexto) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(contexto).push(
                    rotaDoPagamento(consulta, profissional: timbo, horario: escolhido, relogio: () => agora),
                  ),
                  child: const Text('Abrir o pagamento'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Abrir o pagamento'));
      await tester.pumpAndSettle();
    }

    /// Adianta o relógio da tela e o tempo do teste juntos.
    Future<void> passar(WidgetTester tester, Duration tempo) async {
      agora = agora.add(tempo);
      await tester.pump(tempo);
    }

    testWidgets('a etapa, até quando o horário fica reservado, e a consulta com o valor congelado', (tester) async {
      await abrir(tester, reserva());

      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.text('Etapa 3 de 3'), findsOneWidget);
      expect(find.text('Seu horário fica reservado até 12:15 (faltam 15\u00a0minutos).'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 14:30'), findsOneWidget);
      expect(find.text('R\$ 200,00'), findsOneWidget);
      expect(find.text('O pagamento antecipado garante o seu horário.'), findsOneWidget);
      expect(find.textContaining(RegExp('cau[çc][ãa]o', caseSensitive: false)), findsNothing);
    });

    testWidgets('ainda sem botão de pagar: ele entra na Etapa 15', (tester) async {
      await abrir(tester, reserva());

      expect(find.byType(FilledButton), findsNothing);
    });

    testWidgets('a contagem troca sozinha, minuto a minuto', (tester) async {
      await abrir(tester, reserva());

      await passar(tester, const Duration(minutes: 1));
      expect(find.text('Seu horário fica reservado até 12:15 (faltam 14\u00a0minutos).'), findsOneWidget);

      // O texto troca no meio minuto: com 13 minutos e meio, são 13.
      await passar(tester, const Duration(seconds: 30));
      expect(find.text('Seu horário fica reservado até 12:15 (faltam 13\u00a0minutos).'), findsOneWidget);

      await passar(tester, const Duration(minutes: 12));
      expect(find.text('Seu horário fica reservado até 12:15 (falta 1\u00a0minuto).'), findsOneWidget);

      await passar(tester, const Duration(seconds: 30));
      expect(find.text('Seu horário fica reservado até 12:15 (falta menos de 1\u00a0minuto).'), findsOneWidget);
    });

    testWidgets('o prazo venceu: a folha abre sozinha, uma vez só, e a nota diz quando terminou', (tester) async {
      await abrir(tester, reserva());

      await passar(tester, const Duration(minutes: 15));
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(find.text('O prazo para pagar esta reserva terminou. Escolha o horário de novo.'), findsOneWidget);
      expect(find.text('A reserva terminou às 12:15.'), findsOneWidget);

      await passar(tester, const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('a reserva que já chega vencida abre a folha de cara', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero));

      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('"Escolher o horário de novo" abre a grade do mesmo profissional, carregada de novo', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero), horarios: [gradeDeSexta()]);

      await tester.tap(find.text('Escolher o horário de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher horário'), findsOneWidget);
      expect(catalogo.pedidosDeHorarios.single.profissionalId, timbo.id);
      // A grade ficou no lugar do pagamento: voltar leva à tela de baixo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Abrir o pagamento'), findsOneWidget);
    });

    testWidgets('"Agora não" volta à primeira tela', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero));

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsNothing);
      expect(find.text('Pagamento'), findsNothing);
      expect(find.text('Abrir o pagamento'), findsOneWidget);
    });

    testWidgets('sair da tela para o relógio da contagem', (tester) async {
      await abrir(tester, reserva());

      await tester.pageBack();
      await tester.pumpAndSettle();

      // Um relógio esquecido ficaria pendente, e o teste cairia no fim.
      expect(find.text('Abrir o pagamento'), findsOneWidget);
    });

    testWidgets('a 200%, nada estoura', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester, reserva());

      expect(tester.takeException(), isNull);
    });
  });
}

/// Uma grade qualquer, para a grade aberta de novo ter o que mostrar.
List<Horario> gradeDeSexta() => [horario(4, 16, 9)];
