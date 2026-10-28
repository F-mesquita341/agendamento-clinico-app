import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/checkout.dart';
import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/ui/agendamento/pagamento_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/reserva_view_model.dart';
import 'package:agendamento_clinico/ui/comum/selo_de_status.dart';
import 'package:agendamento_clinico/ui/comum/textos.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_view_model.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:agendamento_clinico/ui/shell/abas_do_shell.dart';
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
Consulta reserva({Duration? falta = const Duration(minutes: 15)}) => Consulta(
      id: 50,
      status: StatusDaConsulta.pendentePagamento,
      horarioId: escolhido.id,
      valorFormatado: 'R\$ 200,00',
      reservaExpiraEm: falta == null ? null : meioDiaDeQuarta.add(falta),
    );

/// A consulta como o `GET /consultas/:id` a devolve, com o horário e o
/// profissional.
Consulta noDetalhe(StatusDaConsulta status, {MotivoDoCancelamento? motivo}) => Consulta(
      id: 50,
      status: status,
      motivoDoCancelamento: motivo,
      horarioId: escolhido.id,
      valorFormatado: 'R\$ 200,00',
      reservaExpiraEm: status == StatusDaConsulta.pendentePagamento ? meioDiaDeQuarta.add(const Duration(minutes: 15)) : null,
      horario: escolhido,
      profissional: timbo,
    );

final aguardando = noDetalhe(StatusDaConsulta.pendentePagamento);
final paga = noDetalhe(StatusDaConsulta.confirmada);
final expirada = noDetalhe(StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.reservaExpirada);

final checkout = Checkout(
  endereco: Uri.parse('https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123'),
);

ReservaViewModel reservaVm(Consulta consulta) => ReservaViewModel(
      consulta,
      consultas: ConsultasFalso(),
      abridor: AbridorDeLinksFalso(),
      profissional: timbo,
      horario: escolhido,
      relogio: () => agora,
    );

const tituloDaFolha = 'A reserva expirou';
const abrirPagamento = 'Abrir o pagamento';
const abrirDeNovo = 'Abrir pagamento de novo';
const ambienteDeTeste = 'Ambiente de teste: nenhum valor real é cobrado.';

void main() {
  setUp(() => agora = meioDiaDeQuarta);

  group('reserva, no view model', () {
    test('até quando, na hora da clínica, e quanto falta, no minuto mais próximo', () {
      final vm = reservaVm(reserva());
      addTearDown(vm.dispose);

      expect(vm.ateAs, '12:15');
      expect(vm.quantoFalta, 'faltam 15\u00a0minutos');
      expect(vm.prazoPassou, isFalse);

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

    test('no último minuto, "falta menos de 1 minuto"; no prazo, ele passou', () {
      final vm = reservaVm(reserva());
      addTearDown(vm.dispose);

      agora = meioDiaDeQuarta.add(const Duration(minutes: 14));
      expect(vm.quantoFalta, 'falta menos de 1\u00a0minuto');
      expect(vm.prazoPassou, isFalse);

      agora = meioDiaDeQuarta.add(const Duration(minutes: 15));
      expect(vm.quantoFalta, isNull);
      expect(vm.prazoPassou, isTrue);
    });

    test('sem prazo, nada a contar, e nada vencido', () {
      final vm = reservaVm(
        const Consulta(id: 50, status: StatusDaConsulta.pendentePagamento, horarioId: 3, valorFormatado: 'R\$ 200,00'),
      );
      addTearDown(vm.dispose);

      expect((vm.ateAs, vm.quantoFalta, vm.prazoPassou), (null, null, false));
    });

    test('dois toques em abrir, um pedido', () async {
      final resposta = Completer<Checkout>();
      final consultas = ConsultasFalso(pagar: [resposta]);
      final vm = ReservaViewModel(
        reserva(),
        consultas: consultas,
        abridor: AbridorDeLinksFalso(),
        profissional: timbo,
        horario: escolhido,
        relogio: () => agora,
      );
      addTearDown(vm.dispose);

      final primeiro = vm.abrirPagamento();
      await vm.abrirPagamento();
      resposta.complete(checkout);
      await primeiro;

      expect(consultas.pedidosDePagar, [50]);
      expect(vm.situacao, SituacaoDoPagamento.noCheckout);
    });
  });

  group('selo de status', () {
    test('os rótulos da checklist, um para cada status, e o motivo separa a reserva expirada', () {
      String rotulo(StatusDaConsulta status, [MotivoDoCancelamento? motivo]) =>
          SeloDeStatus.rotuloEIcone(status, motivo).$1;

      expect(rotulo(StatusDaConsulta.pendentePagamento), 'Aguardando pagamento');
      expect(rotulo(StatusDaConsulta.confirmada), 'Confirmada');
      expect(rotulo(StatusDaConsulta.cancelada), 'Cancelada');
      expect(rotulo(StatusDaConsulta.cancelada, MotivoDoCancelamento.paciente), 'Cancelada');
      expect(rotulo(StatusDaConsulta.cancelada, MotivoDoCancelamento.reservaExpirada), 'Reserva expirada');
      expect(rotulo(StatusDaConsulta.realizada), 'Realizada');
      expect(rotulo(StatusDaConsulta.naoCompareceu), 'Não compareceu');
    });
  });

  group('pagamento, na tela', () {
    late CatalogoFalso catalogo;
    late ConsultasFalso consultas;
    late AbridorDeLinksFalso abridor;
    late AbasDoShell abas;

    /// Uma tela por baixo, que abre o pagamento como o resumo abriria — ou,
    /// com [reaberta], como "Pagar agora" reabre.
    Future<void> abrir(
      WidgetTester tester,
      Consulta consulta, {
      List<Object?> horarios = const [],
      List<Object?> pagar = const [],
      List<Object?> lidas = const [],
      bool abre = true,
      double altura = 1400,
      bool reaberta = false,
      List<Object?> cancelar = const [],
      bool lembretesPermitidos = true,
    }) async {
      // Alta, para a tela inteira caber sem rolar; o teste a 200% rola.
      tester.view.physicalSize = Size(411, altura);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      catalogo = CatalogoFalso(horarios: horarios);
      consultas = ConsultasFalso(pagar: pagar, consulta: lidas, cancelar: cancelar);
      // A aba de quem agenda: a busca. O pagamento escolhe para onde se volta.
      abas = AbasDoShell()..mostrar(AbaDoShell.buscar);
      addTearDown(abas.dispose);
      abridor = AbridorDeLinksFalso(consegue: abre);
      // Os lembretes, só pela permissão: a nota da confirmação depende dela.
      final sessao = SessaoViewModel(autenticacao: AutenticacaoFalsa(), pacientes: RepositorioDoPacienteFalso());
      addTearDown(sessao.dispose);
      final lembretes = LembretesViewModel(
        notificacoes: NotificacoesFalsas(permitido: lembretesPermitidos),
        dispositivos: DispositivosFalso(),
        sessao: sessao,
      )..iniciar();
      addTearDown(lembretes.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<RepositorioDoCatalogo>.value(value: catalogo),
          Provider<RepositorioDeConsultas>.value(value: consultas),
          Provider<AbridorDeLinks>.value(value: abridor),
          ChangeNotifierProvider<AbasDoShell>.value(value: abas),
          ChangeNotifierProvider<LembretesViewModel>.value(value: lembretes),
        ],
        child: MaterialApp(
          theme: temaDoApp(),
          home: Builder(
            builder: (contexto) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(contexto).push(
                    rotaDoPagamento(
                      consulta,
                      profissional: timbo,
                      horario: escolhido,
                      relogio: () => agora,
                      reaberta: reaberta,
                    ),
                  ),
                  child: const Text('Ir ao pagamento'),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ir ao pagamento'));
      await tester.pumpAndSettle();
    }

    /// Adianta o relógio da tela e o tempo do teste juntos.
    Future<void> passar(WidgetTester tester, Duration tempo) async {
      agora = agora.add(tempo);
      await tester.pump(tempo);
    }

    /// A pessoa fecha a aba de pagamento, e o aplicativo volta para a frente.
    Future<void> voltarAoApp(WidgetTester tester) async {
      for (final estado in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(estado);
      }
      await tester.pump();
    }

    /// Leva o relógio até o prazo em dois passos: a contagem segue até um
    /// segundo antes, e só o último segundo vence o prazo.
    Future<void> chegarAoPrazo(WidgetTester tester) async {
      await passar(tester, const Duration(minutes: 14, seconds: 59));
      await passar(tester, const Duration(seconds: 1));
    }

    Future<void> tocarEmAbrir(WidgetTester tester) async {
      await tester.tap(find.text(abrirPagamento));
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a etapa, o prazo, a consulta com o valor congelado, e o aviso de ambiente de teste', (tester) async {
      await abrir(tester, reserva());

      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.text('Etapa 3 de 3'), findsOneWidget);
      expect(find.text('Seu horário fica reservado até 12:15 (faltam 15\u00a0minutos).'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 14:30'), findsOneWidget);
      expect(find.text('R\$\u00a0200,00'), findsOneWidget);
      expect(
        find.text('O pagamento antecipado garante o seu horário. Ele é feito na página do Mercado Pago, que abre a '
            'seguir. Depois de pagar, volte para o aplicativo.'),
        findsOneWidget,
      );
      expect(find.text(ambienteDeTeste), findsOneWidget);
      expect(find.text(abrirPagamento), findsOneWidget);
      expect(find.textContaining(RegExp('cau[çc][ãa]o', caseSensitive: false)), findsNothing);
    });

    testWidgets('abrir o pagamento pede a página da consulta e a abre na aba; o botão vira "de novo"', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout]);

      await tocarEmAbrir(tester);

      expect(consultas.pedidosDePagar, [50]);
      expect(abridor.pagamentos, [checkout.endereco]);
      expect(find.text(abrirDeNovo), findsOneWidget);
    });

    testWidgets('enquanto pede, o botão trava e diz "Abrindo o pagamento…"', (tester) async {
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta]);

      await tester.tap(find.text(abrirPagamento));
      await tester.pump();

      expect(find.text('Abrindo o pagamento…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);

      resposta.complete(checkout);
      await tester.pump();
      await tester.pump();
    });

    testWidgets('servidor demorando ao pedir a página: o aviso', (tester) async {
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta]);

      await tester.tap(find.text(abrirPagamento));
      await tester.pump(const Duration(seconds: 4));

      expect(find.text(Textos.servidorDemorando), findsOneWidget);

      resposta.complete(checkout);
      await tester.pump();
      await tester.pump();
      expect(find.text(Textos.servidorDemorando), findsNothing);
    });

    testWidgets('aparelho que não abre a aba: a mensagem, e tentar de novo', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout, checkout], abre: false);

      await tocarEmAbrir(tester);
      expect(find.text('Não foi possível abrir a página de pagamento. Tente de novo.'), findsOneWidget);
      expect(find.text(abrirPagamento), findsOneWidget);

      abridor.consegue = true;
      await tocarEmAbrir(tester);
      expect(abridor.pagamentos, hasLength(2));
      expect(find.text('Não foi possível abrir a página de pagamento. Tente de novo.'), findsNothing);
    });

    testWidgets('pagamento indisponível: a mensagem da API, e o botão continua', (tester) async {
      const indisponivel = ErroDaApi(
        status: 503,
        codigo: 'PAGAMENTO_INDISPONIVEL',
        mensagem: 'O pagamento está indisponível no momento. Tente de novo em instantes.',
        acao: AcaoSugerida.tentarNovamente,
      );
      await abrir(tester, reserva(), pagar: [indisponivel]);

      await tocarEmAbrir(tester);

      expect(find.text(indisponivel.mensagem), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
      // Indisponível não é recusa: não há o que reler.
      expect(consultas.pedidosDeConsulta, isEmpty);
    });

    testWidgets('a volta do checkout pergunta à API; confirmada, a tela de confirmação, montada pelo que ela devolveu', (
      tester,
    ) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [paga]);
      await tocarEmAbrir(tester);

      await voltarAoApp(tester);
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeConsulta, [50]);
      expect(find.text('Consulta confirmada'), findsOneWidget);
      expect(find.text('Recebemos a confirmação do pagamento.'), findsOneWidget);
      expect(find.widgetWithText(SeloDeStatus, 'Confirmada'), findsOneWidget);
      expect(find.text('Centro, Quixadá - CE'), findsOneWidget);
    });

    testWidgets('a volta em si não confirma nada: enquanto a API não diz, "Conferindo o pagamento…"', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [aguardando, for (var i = 0; i < 9; i++) aguardando]);
      await tocarEmAbrir(tester);

      await voltarAoApp(tester);
      await tester.pump();

      expect(find.text('Conferindo o pagamento… Isso leva alguns segundos.'), findsOneWidget);
      expect(find.text('Conferindo o pagamento…'), findsOneWidget);
      expect(find.text('Consulta confirmada'), findsNothing);

      // Sai da tela, para a conferência parar.
      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('sem confirmação depois da conferência rápida: o prazo, o "não pague de novo" e "Abrir de novo"', (
      tester,
    ) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [for (var i = 0; i < 9; i++) aguardando]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);

      await passar(tester, const Duration(seconds: 3 * 5));
      await tester.pump();

      expect(consultas.pedidosDeConsulta, hasLength(5));
      expect(find.textContaining('Ainda não recebemos a confirmação do pagamento.'), findsOneWidget);
      expect(find.textContaining('Seu horário fica reservado até 12:15'), findsOneWidget);
      expect(find.textContaining('Se você já pagou, não pague de novo'), findsOneWidget);
      expect(find.text(abrirDeNovo), findsOneWidget);

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('num celular comum, o aviso de ambiente de teste fica à vista junto do botão, mesmo com a nota da '
        'volta sem confirmação', (tester) async {
      // Mais baixa que o emulador do portão (914), onde a nota o empurrava
      // para fora da tela.
      await abrir(tester, reserva(), pagar: [checkout], lidas: [for (var i = 0; i < 9; i++) aguardando], altura: 780);
      expect(find.text(ambienteDeTeste).hitTestable(), findsOneWidget);

      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));
      await tester.pump();

      expect(find.textContaining('Ainda não recebemos a confirmação do pagamento.'), findsOneWidget);
      expect(find.text(ambienteDeTeste).hitTestable(), findsOneWidget);
      expect(find.text(abrirDeNovo).hitTestable(), findsOneWidget);

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('a confirmação que chega tarde leva à confirmação sozinha', (tester) async {
      await abrir(
        tester,
        reserva(),
        pagar: [checkout],
        lidas: [for (var i = 0; i < 6; i++) aguardando, paga],
      );
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));

      await passar(tester, const Duration(seconds: 10));
      await passar(tester, const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('"Abrir pagamento de novo" reabre a mesma página', (tester) async {
      await abrir(
        tester,
        reserva(),
        pagar: [checkout, checkout],
        lidas: [for (var i = 0; i < 9; i++) aguardando],
      );
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));

      await tester.tap(find.text(abrirDeNovo));
      await tester.pump();
      await tester.pump();

      expect(consultas.pedidosDePagar, [50, 50]);
      expect(abridor.pagamentos, [checkout.endereco, checkout.endereco]);

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('sair da tela para as conferências', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [for (var i = 0; i < 9; i++) aguardando]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));
      final antes = consultas.pedidosDeConsulta.length;

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      await passar(tester, const Duration(seconds: 30));

      expect(consultas.pedidosDeConsulta, hasLength(antes));
    });

    testWidgets('recusa do pagamento: a consulta já paga, relida, leva à confirmação', (tester) async {
      const jaPaga = ErroDaApi(status: 422, codigo: 'CONSULTA_NAO_PAGAVEL', mensagem: 'Esta consulta já está paga.');
      await abrir(tester, reserva(), pagar: [jaPaga], lidas: [paga]);

      await tocarEmAbrir(tester);
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeConsulta, [50]);
      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('recusa com a consulta ainda aguardando: a mensagem da API fica na tela', (tester) async {
      const recusa = ErroDaApi(status: 422, codigo: 'OUTRA_RECUSA', mensagem: 'Não dá para pagar agora.');
      await abrir(tester, reserva(), pagar: [recusa], lidas: [aguardando]);

      await tocarEmAbrir(tester);
      await tester.pump();

      expect(find.text('Não dá para pagar agora.'), findsOneWidget);
      expect(find.text(abrirPagamento), findsOneWidget);
    });

    testWidgets('recusa com a consulta já cancelada pelo prazo: a folha da reserva vencida', (tester) async {
      const vencida = ErroDaApi(
        status: 422,
        codigo: 'RESERVA_EXPIRADA',
        mensagem: 'O prazo para pagar esta reserva terminou. Escolha o horário de novo.',
      );
      await abrir(tester, reserva(), pagar: [vencida], lidas: [expirada]);

      await tocarEmAbrir(tester);
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('a consulta cancelada pelo paciente: a folha diz que foi cancelada', (tester) async {
      const recusa = ErroDaApi(status: 422, codigo: 'CONSULTA_NAO_PAGAVEL', mensagem: 'Esta consulta não pode mais ser paga.');
      await abrir(
        tester,
        reserva(),
        pagar: [recusa],
        lidas: [noDetalhe(StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.paciente)],
      );

      await tocarEmAbrir(tester);
      await tester.pumpAndSettle();

      expect(find.text('A reserva foi cancelada'), findsOneWidget);
      expect(find.text(tituloDaFolha), findsNothing);
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

    testWidgets('prazo vencido sem o checkout aberto: a folha na hora, sem perguntar à API', (tester) async {
      await abrir(tester, reserva());

      await chegarAoPrazo(tester);
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(find.text('O prazo para pagar esta reserva terminou. Escolha o horário de novo.'), findsOneWidget);
      expect(find.text('A reserva terminou às 12:15.'), findsOneWidget);
      expect(consultas.pedidosDeConsulta, isEmpty);

      await passar(tester, const Duration(minutes: 5));
      await tester.pumpAndSettle();
      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('o prazo vence com o pedido da página no ar, e a resposta não chega: a folha, sem esperar outro toque', (
      tester,
    ) async {
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta]);
      await tester.tap(find.text(abrirPagamento));
      await tester.pump();

      await chegarAoPrazo(tester);
      await tester.pump();
      expect(find.text(tituloDaFolha), findsNothing);

      resposta.completeError(const ErroDaApi.semConexao());
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(abridor.pagamentos, isEmpty);
    });

    testWidgets('o prazo vence com o pedido da página no ar, e a aba não abre: a folha, sem esperar outro toque', (
      tester,
    ) async {
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta], abre: false);
      await tester.tap(find.text(abrirPagamento));
      await tester.pump();

      await chegarAoPrazo(tester);
      await tester.pump();
      resposta.complete(checkout);
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('sem prazo na reserva, a conferência continuada para depois do tempo de uma reserva; voltar recomeça', (
      tester,
    ) async {
      await abrir(tester, reserva(falta: null), pagar: [checkout], lidas: [for (var i = 0; i < 120; i++) aguardando]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));
      await tester.pump();
      expect(find.textContaining('Ainda não recebemos a confirmação do pagamento.'), findsOneWidget);

      for (var i = 0; i < ReservaViewModel.conferenciasContinuadas + 10; i++) {
        await passar(tester, ReservaViewModel.intervaloDaConferenciaContinuada);
      }
      const teto = ReservaViewModel.conferenciasRapidas + ReservaViewModel.conferenciasContinuadas;
      expect(consultas.pedidosDeConsulta, hasLength(teto));
      expect(find.text(abrirDeNovo), findsOneWidget);

      await voltarAoApp(tester);
      await tester.pump();
      expect(consultas.pedidosDeConsulta, hasLength(teto + 1));

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('prazo vencido com o checkout aberto: confere antes, e a confirmação tardia vira confirmação', (
      tester,
    ) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [aguardando, paga]);
      await tocarEmAbrir(tester);

      await chegarAoPrazo(tester);
      await tester.pump();

      expect(find.text('O prazo terminou. Conferindo com o servidor se o pagamento chegou…'), findsOneWidget);
      expect(find.text(tituloDaFolha), findsNothing);

      await passar(tester, const Duration(seconds: 10));
      await tester.pumpAndSettle();

      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('prazo vencido com o checkout aberto, e a API cancela: a folha', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [expirada]);
      await tocarEmAbrir(tester);

      await chegarAoPrazo(tester);
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(find.textContaining('Se você já pagou'), findsNothing);
    });

    testWidgets('prazo vencido com o checkout aberto, e a API sem decidir em 3 minutos: a folha, com a saída de quem pagou', (
      tester,
    ) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [for (var i = 0; i < 30; i++) aguardando]);
      await tocarEmAbrir(tester);
      await chegarAoPrazo(tester);

      for (var i = 0; i < 18; i++) {
        await passar(tester, const Duration(seconds: 10));
      }
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(
        find.text('Se você já pagou, a confirmação ainda pode chegar. Em caso de dúvida, ligue para a clínica: '
            '(88)\u00a03000-0000.'),
        findsOneWidget,
      );
    });

    testWidgets('a reserva que já chega vencida abre a folha de cara', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero));
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('"Escolher o horário de novo" abre a grade do mesmo profissional, carregada de novo', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero), horarios: [gradeDeSexta()]);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Escolher o horário de novo'));
      await tester.pumpAndSettle();

      expect(find.text('Escolher horário'), findsOneWidget);
      expect(catalogo.pedidosDeHorarios.single.profissionalId, timbo.id);
      // A grade ficou no lugar do pagamento: voltar leva à tela de baixo.
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ir ao pagamento'), findsOneWidget);
    });

    testWidgets('"Agora não" volta à primeira tela', (tester) async {
      await abrir(tester, reserva(falta: Duration.zero));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsNothing);
      expect(find.text('Pagamento'), findsNothing);
      expect(find.text('Ir ao pagamento'), findsOneWidget);
    });

    testWidgets('sair sem pagar pergunta antes; "Continuar pagamento" fica, "Sair" sai', (tester) async {
      await abrir(tester, reserva());

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Sair sem pagar?'), findsOneWidget);
      expect(
        find.text('O horário fica reservado até 12:15 e depois volta a ficar livre. '
            'Para pagar depois, abra a consulta em Minhas consultas.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Continuar pagamento'));
      await tester.pumpAndSettle();
      expect(find.text('Pagamento'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
      expect(find.text('Pagamento'), findsNothing);
      // Um relógio esquecido ficaria pendente, e o teste cairia no fim.
      expect(find.text('Ir ao pagamento'), findsOneWidget);
    });

    testWidgets('com a página já aberta, sair não dá a entender que a consulta se perde', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout]);
      await tocarEmAbrir(tester);

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Sair do pagamento?'), findsOneWidget);
      expect(
        find.text('Se você já pagou, a confirmação chega mesmo assim. Se não pagou, o horário fica reservado '
            'até 12:15 e depois volta a ficar livre. Para pagar depois, abra a consulta em Minhas consultas.'),
        findsOneWidget,
      );
      expect(find.text('Sair sem pagar?'), findsNothing);

      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('a confirmação fica no lugar do pagamento: voltar não reabre o checkout', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [paga]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await tester.pumpAndSettle();

      // A confirmação não tem barra: é o voltar do Android.
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('Consulta confirmada'), findsNothing);
      expect(find.text('Pagamento'), findsNothing);
      expect(find.text('Ir ao pagamento'), findsOneWidget);
      expect(abridor.pagamentos, hasLength(1));
      // E o shell, por baixo, mostra o Início (checklist, item 3.3).
      expect(abas.aba, AbaDoShell.inicio);
    });

    testWidgets('na confirmação, a data e a hora em destaque, "Abrir no mapa", e "Ver minhas consultas" leva à aba delas', (
      tester,
    ) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [paga]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await tester.pumpAndSettle();

      final destaque = tester.widget<Text>(find.text('Amanhã, quinta-feira, 15/10 · 14:30').first);
      expect(destaque.style?.fontSize, greaterThanOrEqualTo(22));

      await tester.tap(find.text('Abrir no mapa'));
      await tester.pump();
      expect(abridor.mapas, ['Clínica Exemplo Quixadá, Centro, Quixadá - CE']);

      expect(find.text('Voltar à busca'), findsNothing);
      await tester.tap(find.text('Ver minhas consultas'));
      await tester.pumpAndSettle();
      expect(find.text('Ir ao pagamento'), findsOneWidget);
      expect(abas.aba, AbaDoShell.consultas);
    });

    group('na confirmação, a nota do lembrete', () {
      const umDiaAntes = 'Você recebe um lembrete um dia antes da consulta.';
      const desativados = 'Os lembretes estão desativados. Para receber o aviso um dia antes, ative em Perfil.';

      /// A consulta paga, num horário que começa [daquiA] depois do meio-dia
      /// de quarta, quando a confirmação chega.
      Consulta pagaPara(Duration daquiA) {
        final inicio = meioDiaDeQuarta.add(daquiA);
        final outro = Horario(id: 9, inicio: inicio, duracaoMinutos: 30, versao: 0);
        return Consulta(
          id: 50,
          status: StatusDaConsulta.confirmada,
          horarioId: outro.id,
          valorFormatado: 'R\$ 200,00',
          horario: outro,
          profissional: timbo,
        );
      }

      Future<void> confirmar(WidgetTester tester, Consulta lida, {bool permitidos = true}) async {
        await abrir(tester, reserva(), pagar: [checkout], lidas: [lida], lembretesPermitidos: permitidos);
        await tocarEmAbrir(tester);
        await voltarAoApp(tester);
        await tester.pumpAndSettle();
        expect(find.text('Consulta confirmada'), findsOneWidget);
      }

      testWidgets('com os lembretes permitidos: um dia antes', (tester) async {
        await confirmar(tester, paga);

        expect(find.text(umDiaAntes), findsOneWidget);
      });

      testWidgets('sem a permissão: os lembretes desativados, e onde ativar', (tester) async {
        await confirmar(tester, paga, permitidos: false);

        expect(find.text(desativados), findsOneWidget);
        expect(find.text(umDiaAntes), findsNothing);
      });

      testWidgets('com 24 h ou menos até a consulta, não aparece: o lembrete sai em minutos', (tester) async {
        await confirmar(tester, pagaPara(const Duration(hours: 24)));

        expect(find.text(umDiaAntes), findsNothing);
      });

      testWidgets('com um minuto a mais que 24 h, aparece', (tester) async {
        await confirmar(tester, pagaPara(const Duration(hours: 24, minutes: 1)));

        expect(find.text(umDiaAntes), findsOneWidget);
      });
    });

    testWidgets('na confirmação, "Voltar ao início" leva ao Início', (tester) async {
      await abrir(tester, reserva(), pagar: [checkout], lidas: [paga]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Voltar ao início'));
      await tester.pumpAndSettle();
      expect(find.text('Ir ao pagamento'), findsOneWidget);
      expect(abas.aba, AbaDoShell.inicio);
    });

    testWidgets('a confirmação mostra o que a API devolveu, e não o que a tela do pagamento tinha', (tester) async {
      final daApi = Consulta(
        id: 50,
        status: StatusDaConsulta.confirmada,
        horarioId: escolhido.id,
        valorFormatado: 'R\$ 200,00',
        horario: escolhido,
        profissional: timboNa(const Clinica(nome: 'Clínica Exemplo Quixadá', endereco: 'Rua da API, 1')),
      );
      await abrir(tester, reserva(), pagar: [checkout], lidas: [daApi]);
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await tester.pumpAndSettle();

      expect(find.text('Rua da API, 1'), findsOneWidget);
      expect(find.text('Centro, Quixadá - CE'), findsNothing);
    });

    testWidgets('voltar ao app com uma conferência no ar não deixa duas correndo', (tester) async {
      final noAr = Completer<Consulta>();
      await abrir(
        tester,
        reserva(),
        pagar: [checkout],
        lidas: [for (var i = 0; i < 5; i++) aguardando, noAr, for (var i = 0; i < 9; i++) aguardando],
      );
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));
      // A conferência espaçada sai, e fica no ar.
      await passar(tester, const Duration(seconds: 10));
      expect(consultas.pedidosDeConsulta, hasLength(6));

      // A pessoa volta de novo: uma conferência rápida nova, com as suas cinco
      // leituras. A resposta antiga, que chega no meio, não conta como uma delas.
      await voltarAoApp(tester);
      noAr.complete(aguardando);
      await tester.pump();
      await passar(tester, const Duration(seconds: 3 * 5));

      expect(consultas.pedidosDeConsulta, hasLength(6 + 5));

      await tester.pageBack();
      await tester.pump();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('recusa depois do prazo, com a consulta ainda aguardando: a reserva acabou', (tester) async {
      const vencida = ErroDaApi(
        status: 422,
        codigo: 'RESERVA_EXPIRADA',
        mensagem: 'O prazo para pagar esta reserva terminou. Escolha o horário de novo.',
      );
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta], lidas: [aguardando]);

      // Toca no último segundo; o prazo passa com o pedido no ar, e a API recusa.
      await passar(tester, const Duration(minutes: 14, seconds: 59));
      await tester.tap(find.text(abrirPagamento));
      await tester.pump();
      await passar(tester, const Duration(seconds: 2));
      resposta.completeError(vencida);
      await tester.pumpAndSettle();

      // A rotina da API ainda não rodou — a consulta diz que aguarda —, mas o
      // prazo passou: a reserva acabou.
      expect(consultas.pedidosDeConsulta, [50]);
      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('recusa depois do prazo, com a página aberta antes: confere antes, e a confirmação tardia vira '
        'confirmação', (tester) async {
      const vencida = ErroDaApi(
        status: 422,
        codigo: 'RESERVA_EXPIRADA',
        mensagem: 'O prazo para pagar esta reserva terminou. Escolha o horário de novo.',
      );
      final resposta = Completer<Checkout>();
      final ultimaLeitura = Completer<Consulta>();
      await abrir(
        tester,
        reserva(),
        pagar: [checkout, resposta],
        // Cinco na conferência rápida, a releitura da recusa e a conferência
        // depois do prazo.
        lidas: [for (var i = 0; i < 6; i++) aguardando, ultimaLeitura],
      );

      // A página abre aos 14:40 e a volta não traz confirmação.
      await passar(tester, const Duration(minutes: 14, seconds: 40));
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 15));
      await tester.pump();
      expect(find.text(abrirDeNovo), findsOneWidget);

      // Abre de novo; o prazo passa com o pedido no ar, e a API recusa.
      await tester.tap(find.text(abrirDeNovo));
      await tester.pump();
      await passar(tester, const Duration(seconds: 4));
      await passar(tester, const Duration(seconds: 1));
      resposta.completeError(vencida);
      await tester.pump();
      await tester.pump();

      // A pessoa pode ter pago na primeira página: a tela pergunta antes.
      expect(find.text('O prazo terminou. Conferindo com o servidor se o pagamento chegou…'), findsOneWidget);
      expect(find.text(vencida.mensagem), findsNothing);
      expect(find.text(tituloDaFolha), findsNothing);

      ultimaLeitura.complete(paga);
      await tester.pumpAndSettle();
      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('toque, rótulos e contraste: no pagamento, na volta sem confirmação e na confirmação', (tester) async {
      final semantica = tester.ensureSemantics();
      await abrir(
        tester,
        reserva(),
        pagar: [checkout],
        lidas: [for (var i = 0; i < 5; i++) aguardando, paga],
      );
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 3 * 5));
      // O botão volta de travado para ativo com uma animação de cor: mede-se no fim.
      await tester.pumpAndSettle();
      expect(find.textContaining('Ainda não recebemos'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await passar(tester, const Duration(seconds: 10));
      await tester.pumpAndSettle();
      expect(find.text('Consulta confirmada'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('reaberta por "Pagar agora": sem "Etapa 3 de 3"', (tester) async {
      await abrir(tester, reserva(), reaberta: true);

      expect(find.text('Pagamento'), findsOneWidget);
      expect(find.text('Etapa 3 de 3'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    Finder noDialogo(String texto) => find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));

    testWidgets('"Cancelar reserva" pergunta, cancela e leva a Minhas consultas, com "Consulta cancelada."', (
      tester,
    ) async {
      await abrir(tester, reserva(), cancelar: [noDetalhe(StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.paciente)]);

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar esta consulta?'), findsOneWidget);
      expect(find.textContaining('Esta consulta ainda aguarda a confirmação do pagamento.'), findsOneWidget);
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeCancelar, [50]);
      expect(find.text('Pagamento'), findsNothing);
      expect(find.text('Ir ao pagamento'), findsOneWidget);
      expect(find.text('Consulta cancelada.'), findsOneWidget);
      expect(abas.aba, AbaDoShell.consultas);
      expect(find.text(tituloDaFolha), findsNothing);
    });

    testWidgets('"Cancelar reserva" some enquanto a tela pede a página', (tester) async {
      final resposta = Completer<Checkout>();
      await abrir(tester, reserva(), pagar: [resposta]);
      expect(find.text('Cancelar reserva'), findsOneWidget);

      await tester.tap(find.text(abrirPagamento));
      await tester.pump();
      expect(find.text('Cancelar reserva'), findsNothing);

      resposta.complete(checkout);
      await tester.pump();
      await tester.pump();
      expect(find.text('Cancelar reserva'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('a reserva que a API já tinha expirado: a folha da reserva vencida, e não o sucesso', (tester) async {
      await abrir(tester, reserva(), cancelar: [expirada]);

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(find.text(tituloDaFolha), findsOneWidget);
      expect(find.text('Consulta cancelada.'), findsNothing);
    });

    testWidgets('a recusa do cancelamento: a mensagem, e a reserva continua na tela', (tester) async {
      const recusa = ErroDaApi(status: 422, codigo: 'OUTRA_RECUSA', mensagem: 'Não dá para cancelar agora.');
      await abrir(tester, reserva(), cancelar: [recusa], lidas: [aguardando]);

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Não dá para cancelar agora.'), findsOneWidget);
      expect(find.text('Cancelar reserva'), findsOneWidget);
      expect(abas.aba, AbaDoShell.buscar);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('a conferência continuada para durante o cancelamento, e volta se ele for recusado', (tester) async {
      final resposta = Completer<Consulta>();
      const recusa = ErroDaApi(status: 422, codigo: 'OUTRA_RECUSA', mensagem: 'Não dá para cancelar agora.');
      await abrir(
        tester,
        reserva(),
        pagar: [checkout],
        cancelar: [resposta],
        lidas: [for (var i = 0; i < 9; i++) aguardando],
      );
      await tocarEmAbrir(tester);
      await voltarAoApp(tester);
      await passar(tester, const Duration(seconds: 15));
      await tester.pump();
      expect(consultas.pedidosDeConsulta, hasLength(5));

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await passar(tester, const Duration(seconds: 20));
      // Com o cancelamento no ar, ninguém confere.
      expect(consultas.pedidosDeConsulta, hasLength(5));

      resposta.completeError(recusa);
      await tester.pump();
      await tester.pump();
      // A releitura do cancelamento, e a conferência de volta.
      expect(consultas.pedidosDeConsulta, hasLength(6));
      expect(find.text('Não dá para cancelar agora.'), findsOneWidget);
      await passar(tester, const Duration(seconds: 10));
      expect(consultas.pedidosDeConsulta, hasLength(7));

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('o prazo vence durante o cancelamento, e a resposta não chega: a folha da reserva vencida', (
      tester,
    ) async {
      final resposta = Completer<Consulta>();
      await abrir(tester, reserva(), cancelar: [resposta], lidas: [const ErroDaApi.semConexao()]);

      await tester.tap(find.text('Cancelar reserva'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await chegarAoPrazo(tester);
      await tester.pump();
      // Com a tela ocupada cancelando, o prazo espera o fim do pedido.
      expect(find.text(tituloDaFolha), findsNothing);

      resposta.completeError(const ErroDaApi.semConexao());
      await tester.pumpAndSettle();
      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('a 200%, nada estoura, e o botão continua ao alcance', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await abrir(tester, reserva());

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(abrirPagamento).hitTestable(), findsOneWidget);
      expect(find.text(ambienteDeTeste).hitTestable(), findsOneWidget);
    });
  });
}

/// Uma grade qualquer, para a grade aberta de novo ter o que mostrar.
List<Horario> gradeDeSexta() => [horario(4, 16, 9)];
