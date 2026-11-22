import 'dart:async';
import 'dart:convert';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/checkout.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/pix.dart';
import 'package:agendamento_clinico/ui/agendamento/pagamento_screen.dart';
import 'package:agendamento_clinico/ui/agendamento/pix_view_model.dart';
import 'package:agendamento_clinico/ui/agendamento/reserva_view_model.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_view_model.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:agendamento_clinico/ui/shell/abas_do_shell.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/acessibilidade.dart';
import '../apoio/agenda.dart';
import '../apoio/falsos.dart';

/// O pagamento por Pix (versão 2, ambiente de teste): o pedido, na tela de
/// Pagamento; a espera, na tela do Pix; e a decisão, de volta no Pagamento.

/// O relógio que as telas leem: o teste o adianta junto com o tempo do teste.
DateTime agora = meioDiaDeQuarta;

final escolhido = horario(3, 15, 14, minuto: 30);
final prazo = meioDiaDeQuarta.add(const Duration(minutes: 15));

/// Reservada ao meio-dia na clínica; o prazo, 15 minutos depois — 12:15.
final reserva = Consulta(
  id: 50,
  status: StatusDaConsulta.pendentePagamento,
  horarioId: escolhido.id,
  valorFormatado: 'R\$ 200,00',
  reservaExpiraEm: prazo,
);

Consulta noDetalhe(StatusDaConsulta status, {MotivoDoCancelamento? motivo}) => Consulta(
      id: 50,
      status: status,
      motivoDoCancelamento: motivo,
      horarioId: escolhido.id,
      valorFormatado: 'R\$ 200,00',
      reservaExpiraEm: status == StatusDaConsulta.pendentePagamento ? prazo : null,
      horario: escolhido,
      profissional: timbo,
    );

final aguardando = noDetalhe(StatusDaConsulta.pendentePagamento);
final paga = noDetalhe(StatusDaConsulta.confirmada);
final expirada = noDetalhe(StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.reservaExpirada);

/// Um PNG de 1×1: a imagem só precisa existir.
final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
);

const codigo = '00020126580014br.gov.bcb.pix0136codigo-de-teste';

final pix = Pix(copiaECola: codigo, qrCode: png, expiraEm: prazo, valorFormatado: 'R\$ 200,00');

final checkout = Checkout(
  endereco: Uri.parse('https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123'),
);

const desligado = ErroDaApi(status: 404, codigo: 'ROTA_NAO_ENCONTRADA', mensagem: 'Rota não encontrada.');
const emAndamento = ErroDaApi(
  status: 409,
  codigo: 'PAGAMENTO_EM_ANDAMENTO',
  mensagem: 'Você já começou o pagamento desta consulta por outro meio. Conclua por lá.',
);
const semConexao = ErroDaApi(status: 0, codigo: 'SEM_CONEXAO', mensagem: 'Sem conexão.');

const pagarComPix = 'Pagar com Pix';
const pagarNaPagina = 'Pagar na página do Mercado Pago';
const copiar = 'Copiar código';
const tituloDaFolha = 'A reserva expirou';

/// Muitas respostas iguais: a espera pergunta a cada 5 segundos.
List<Object?> varias(Object resposta, [int quantas = 400]) => List.filled(quantas, resposta);

void main() {
  setUp(() => agora = meioDiaDeQuarta);

  group('pedir o Pix, no view model do Pagamento', () {
    late ConsultasFalso consultas;

    ReservaViewModel vm({
      List<Object?> pedir = const [],
      List<Object?> lidas = const [],
      List<Object?> pagar = const [],
    }) {
      consultas = ConsultasFalso(pagarComPix: pedir, consulta: lidas, pagar: pagar);
      final vm = ReservaViewModel(
        reserva,
        consultas: consultas,
        abridor: AbridorDeLinksFalso(),
        profissional: timbo,
        horario: escolhido,
        relogio: () => agora,
      );
      addTearDown(vm.dispose);
      return vm;
    }

    test('o Pix criado volta para a tela abrir; a situação não muda', () async {
      final reservaVm = vm(pedir: [pix]);

      final lido = await reservaVm.pagarComPix();

      expect(lido, same(pix));
      expect(consultas.pedidosDePagarComPix, [50]);
      expect(reservaVm.abriuOPix, isTrue);
      expect(reservaVm.situacao, SituacaoDoPagamento.aguardando);
      expect(reservaVm.erro, isNull);
      expect(reservaVm.podePagarComPix, isTrue);
    });

    test('dois toques, um pedido', () async {
      final resposta = Completer<Pix>();
      final reservaVm = vm(pedir: [resposta]);

      final primeiro = reservaVm.pagarComPix();
      expect(reservaVm.situacao, SituacaoDoPagamento.abrindoPix);
      expect(await reservaVm.pagarComPix(), isNull);
      resposta.complete(pix);

      expect(await primeiro, same(pix));
      expect(consultas.pedidosDePagarComPix, [50]);
    });

    test('404 ROTA_NAO_ENCONTRADA: o Pix está desligado, o botão some, e a página do Mercado Pago continua', () async {
      final reservaVm = vm(pedir: [desligado], pagar: [checkout]);

      expect(await reservaVm.pagarComPix(), isNull);

      expect(reservaVm.podePagarComPix, isFalse);
      expect(reservaVm.erro, ReservaViewModel.pixIndisponivel);
      expect(reservaVm.situacao, SituacaoDoPagamento.aguardando);
      expect(consultas.pedidosDeConsulta, isEmpty, reason: 'não é recusa da consulta: não relê');
      // Pedir de novo não vai à API.
      expect(await reservaVm.pagarComPix(), isNull);
      expect(consultas.pedidosDePagarComPix, [50]);

      await reservaVm.abrirPagamento();
      expect(reservaVm.situacao, SituacaoDoPagamento.noCheckout);
    });

    test('outro 404 é recusa comum: relê a consulta, e o Pix continua', () async {
      const naoAchada = ErroDaApi(status: 404, codigo: 'CONSULTA_NAO_ENCONTRADA', mensagem: 'Consulta não encontrada.');
      final reservaVm = vm(pedir: [naoAchada], lidas: [aguardando]);

      expect(await reservaVm.pagarComPix(), isNull);

      expect(reservaVm.podePagarComPix, isTrue);
      expect(reservaVm.erro, 'Consulta não encontrada.');
      expect(consultas.pedidosDeConsulta, [50]);
    });

    test('409 PAGAMENTO_EM_ANDAMENTO: relê a consulta, que ainda espera, e fica a mensagem da API', () async {
      final reservaVm = vm(pedir: [emAndamento], lidas: [aguardando]);

      expect(await reservaVm.pagarComPix(), isNull);

      expect(consultas.pedidosDeConsulta, [50]);
      expect(reservaVm.situacao, SituacaoDoPagamento.aguardando);
      expect(reservaVm.erro, emAndamento.mensagem);
      expect(reservaVm.abriuOPix, isFalse);
    });

    test('422 com a consulta já paga, ou vencida, relida: o status decide', () async {
      const naoPagavel = ErroDaApi(status: 422, codigo: 'CONSULTA_NAO_PAGAVEL', mensagem: 'Esta consulta já está paga.');
      final reservaVm = vm(pedir: [naoPagavel], lidas: [paga]);
      expect(await reservaVm.pagarComPix(), isNull);
      expect(reservaVm.situacao, SituacaoDoPagamento.confirmada);

      const vencida = ErroDaApi(status: 422, codigo: 'RESERVA_EXPIRADA', mensagem: 'O prazo terminou.');
      final outraVm = vm(pedir: [vencida], lidas: [expirada]);
      expect(await outraVm.pagarComPix(), isNull);
      expect(outraVm.situacao, SituacaoDoPagamento.encerrada);
      expect(outraVm.motivoDoFim, MotivoDoCancelamento.reservaExpirada);
    });

    test('503 PAGAMENTO_INDISPONIVEL: a mensagem da API, sem reler; o botão continua, para tentar de novo', () async {
      const indisponivel = ErroDaApi(
        status: 503,
        codigo: 'PAGAMENTO_INDISPONIVEL',
        mensagem: 'O pagamento está indisponível agora. Tente de novo em instantes.',
      );
      final reservaVm = vm(pedir: [indisponivel, pix]);

      expect(await reservaVm.pagarComPix(), isNull);
      expect(reservaVm.erro, indisponivel.mensagem);
      expect(consultas.pedidosDeConsulta, isEmpty);
      expect(reservaVm.podePagarComPix, isTrue);

      expect(await reservaVm.pagarComPix(), same(pix));
      expect(reservaVm.erro, isNull);
    });

    test('a decisão que a tela do Pix trouxe é aplicada como a da volta da página', () async {
      final reservaVm = vm(pedir: [pix]);
      await reservaVm.pagarComPix();

      reservaVm.aplicarDecisao(paga);

      expect(reservaVm.situacao, SituacaoDoPagamento.confirmada);
      expect(reservaVm.confirmada, same(paga));
    });

    test('ainda esperando não decide nada', () async {
      final reservaVm = vm(pedir: [pix]);
      await reservaVm.pagarComPix();

      reservaVm.aplicarDecisao(aguardando);

      expect(reservaVm.situacao, SituacaoDoPagamento.aguardando);
    });
  });

  group('a espera, no view model do Pix', () {
    late ConsultasFalso consultas;

    PixViewModel espera(FakeAsync tempo, {List<Object?> conferir = const []}) {
      consultas = ConsultasFalso(conferirPix: conferir);
      return PixViewModel(pix, consultaId: 50, consultas: consultas, relogio: () => agora);
    }

    /// Adianta o relógio e o tempo juntos.
    void passar(FakeAsync tempo, Duration quanto) {
      agora = agora.add(quanto);
      tempo.elapse(quanto);
    }

    test('pergunta a cada 5 segundos, e não antes', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: varias(aguardando));

        passar(tempo, const Duration(seconds: 4, milliseconds: 900));
        expect(consultas.pedidosDeConferirPix, isEmpty);
        passar(tempo, const Duration(milliseconds: 100));
        expect(consultas.pedidosDeConferirPix, [50]);
        passar(tempo, const Duration(seconds: 5));
        expect(consultas.pedidosDeConferirPix, [50, 50]);
        expect(vm.esperando, isTrue);
        vm.dispose();
      });
    });

    test('para na confirmada, com a consulta, e não pergunta mais', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: [aguardando, paga]);
        var avisos = 0;
        vm.addListener(() => avisos++);

        passar(tempo, const Duration(seconds: 10));
        expect(vm.decidida, same(paga));
        expect(vm.esperando, isFalse);
        expect(avisos, 1);

        passar(tempo, const Duration(minutes: 1));
        expect(consultas.pedidosDeConferirPix, hasLength(2));
        vm.dispose();
      });
    });

    test('para na cancelada pelo prazo, do mesmo jeito', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: [expirada]);

        passar(tempo, const Duration(seconds: 5));
        expect(vm.decidida, same(expirada));

        passar(tempo, const Duration(minutes: 1));
        expect(consultas.pedidosDeConferirPix, hasLength(1));
        vm.dispose();
      });
    });

    test('sem conexão, ou o servidor fora do ar, tenta de novo no próximo intervalo', () {
      fakeAsync((tempo) {
        const foraDoAr = ErroDaApi(status: 503, codigo: 'SERVIDOR_INDISPONIVEL', mensagem: 'Fora do ar.');
        final vm = espera(tempo, conferir: [semConexao, foraDoAr, paga]);

        passar(tempo, const Duration(seconds: 10));
        expect(vm.esperando, isTrue);
        expect(vm.indisponivel, isFalse);
        passar(tempo, const Duration(seconds: 5));
        expect(vm.decidida, same(paga));
        vm.dispose();
      });
    });

    test('404 ROTA_NAO_ENCONTRADA: o Pix foi desligado no meio da espera, e ela para', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: [desligado]);

        passar(tempo, const Duration(seconds: 5));
        expect(vm.indisponivel, isTrue);
        expect(vm.esperando, isFalse);

        passar(tempo, const Duration(minutes: 1));
        expect(consultas.pedidosDeConferirPix, hasLength(1));
        vm.dispose();
      });
    });

    test('a volta do app do banco pergunta na hora; a resposta antiga que chega depois não vale', () {
      fakeAsync((tempo) {
        final antiga = Completer<Consulta>();
        final vm = espera(tempo, conferir: [antiga, ...varias(aguardando)]);

        passar(tempo, const Duration(seconds: 5));
        expect(consultas.pedidosDeConferirPix, hasLength(1));
        vm.aoVoltar();
        tempo.flushMicrotasks();
        expect(consultas.pedidosDeConferirPix, hasLength(2));

        // A antiga chega depois, com o Pix desligado: a rodada já é outra.
        antiga.completeError(desligado);
        tempo.flushMicrotasks();
        expect(vm.indisponivel, isFalse);
        expect(vm.esperando, isTrue);
        vm.dispose();
      });
    });

    test('o teto: o prazo mais 3 minutos sem decisão, e a espera acaba', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: varias(aguardando));

        passar(tempo, const Duration(minutes: 15));
        expect(vm.esperando, isTrue, reason: 'no prazo, um Pix pago no último instante ainda confirma');
        passar(tempo, const Duration(minutes: 2, seconds: 55));
        expect(vm.esperando, isTrue);
        final antes = consultas.pedidosDeConferirPix.length;
        passar(tempo, const Duration(seconds: 5));
        expect(vm.esgotou, isTrue);

        passar(tempo, const Duration(minutes: 1));
        expect(consultas.pedidosDeConferirPix.length, antes + 1);
        vm.dispose();
      });
    });

    test('descartada, não pergunta mais', () {
      fakeAsync((tempo) {
        final vm = espera(tempo, conferir: varias(aguardando));
        vm.dispose();

        passar(tempo, const Duration(minutes: 1));
        expect(consultas.pedidosDeConferirPix, isEmpty);
      });
    });
  });

  group('o Pix, nas telas', () {
    late ConsultasFalso consultas;
    late AbridorDeLinksFalso abridor;
    late List<String> copiados;

    Future<void> abrir(
      WidgetTester tester, {
      List<Object?> pedir = const [],
      List<Object?> conferir = const [],
      List<Object?> lidas = const [],
      List<Object?> pagar = const [],
      double altura = 1400,
    }) async {
      tester.view.physicalSize = Size(411, altura);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      copiados = [];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (chamada) async {
        if (chamada.method == 'Clipboard.setData') {
          copiados.add((chamada.arguments as Map)['text'] as String);
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      consultas = ConsultasFalso(pagarComPix: pedir, conferirPix: conferir, consulta: lidas, pagar: pagar);
      final abas = AbasDoShell()..mostrar(AbaDoShell.buscar);
      addTearDown(abas.dispose);
      abridor = AbridorDeLinksFalso();
      final sessao = SessaoViewModel(autenticacao: AutenticacaoFalsa(), pacientes: RepositorioDoPacienteFalso());
      addTearDown(sessao.dispose);
      final lembretes = LembretesViewModel(
        notificacoes: NotificacoesFalsas(permitido: true),
        dispositivos: DispositivosFalso(),
        sessao: sessao,
      )..iniciar();
      addTearDown(lembretes.dispose);
      await tester.pumpWidget(MultiProvider(
        providers: [
          Provider<RepositorioDoCatalogo>.value(value: CatalogoFalso()),
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
                    rotaDoPagamento(reserva, profissional: timbo, horario: escolhido, relogio: () => agora),
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

    Future<void> passar(WidgetTester tester, Duration tempo) async {
      agora = agora.add(tempo);
      await tester.pump(tempo);
    }

    Future<void> tocarNoPix(WidgetTester tester) async {
      await tester.tap(find.text(pagarComPix));
      await tester.pumpAndSettle();
    }

    final naTelaDoPix = find.text(copiar);

    testWidgets('o Pagamento oferece o Pix e a página do Mercado Pago, com o aviso de ambiente de teste', (tester) async {
      await abrir(tester);

      expect(find.text(pagarComPix), findsOneWidget);
      expect(find.text(pagarNaPagina), findsOneWidget);
      expect(find.text('Ambiente de teste: nenhum valor real é cobrado.'), findsOneWidget);
    });

    testWidgets('de ponta a ponta: o QR Code, o código copiado, e a confirmação que chega sozinha', (tester) async {
      await abrir(tester, pedir: [pix], conferir: [aguardando, paga]);

      await tocarNoPix(tester);

      expect(consultas.pedidosDePagarComPix, [50]);
      expect(find.widgetWithText(AppBar, pagarComPix), findsOneWidget);
      expect(find.text('Valor: R\$ 200,00'), findsOneWidget);
      expect(find.text('Pague até 12:15 (faltam 15 minutos).'), findsOneWidget);
      expect(find.bySemanticsLabel('QR Code do Pix'), findsOneWidget);
      expect(find.text('Aguardando o pagamento… A confirmação aparece aqui sozinha.'), findsOneWidget);
      expect(find.text('Ambiente de teste: nenhum valor real é cobrado.'), findsOneWidget);

      await tester.tap(naTelaDoPix);
      await tester.pump();
      expect(copiados, [codigo]);
      expect(find.text('Código copiado.'), findsOneWidget);

      await passar(tester, const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(naTelaDoPix, findsOneWidget, reason: 'a primeira conferência ainda espera');

      await passar(tester, const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(naTelaDoPix, findsNothing);
      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('a imagem que não veio: fica o código, com o aviso', (tester) async {
      await abrir(tester, pedir: [Pix(copiaECola: codigo, qrCode: null, expiraEm: prazo, valorFormatado: 'R\$ 200,00')]);

      await tocarNoPix(tester);

      expect(find.bySemanticsLabel('QR Code do Pix'), findsNothing);
      expect(find.textContaining('Não foi possível mostrar o QR Code.'), findsOneWidget);
      expect(naTelaDoPix, findsOneWidget);
    });

    testWidgets('voltar do Pix não perde nada: "Ver o Pix de novo" traz o mesmo', (tester) async {
      await abrir(tester, pedir: [pix, pix], conferir: varias(aguardando));

      await tocarNoPix(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Ver o Pix de novo'), findsOneWidget);

      await tester.tap(find.text('Ver o Pix de novo'));
      await tester.pumpAndSettle();
      expect(naTelaDoPix, findsOneWidget);
      expect(consultas.pedidosDePagarComPix, [50, 50]);
    });

    testWidgets('o Pix desligado (404): o aviso, o botão some, e a página do Mercado Pago ainda abre', (tester) async {
      await abrir(tester, pedir: [desligado], pagar: [checkout]);

      await tocarNoPix(tester);

      expect(naTelaDoPix, findsNothing);
      expect(find.text(ReservaViewModel.pixIndisponivel), findsOneWidget);
      expect(find.text(pagarComPix), findsNothing);

      await tester.tap(find.text(pagarNaPagina));
      await tester.pumpAndSettle();
      expect(abridor.pagamentos, [checkout.endereco]);
    });

    testWidgets('o Pix desligado no meio da espera: a tela diz, e para de perguntar', (tester) async {
      await abrir(tester, pedir: [pix], conferir: [desligado]);
      await tocarNoPix(tester);

      await passar(tester, const Duration(seconds: 5));
      await tester.pumpAndSettle();

      expect(find.text('O Pix não está disponível agora. Volte e use a página do Mercado Pago.'), findsOneWidget);
      await passar(tester, const Duration(minutes: 1));
      expect(consultas.pedidosDeConferirPix, hasLength(1));
    });

    testWidgets('409: a página do Mercado Pago aberta antes, e o Pix recusado com a mensagem da API', (tester) async {
      await abrir(tester, pagar: [checkout], pedir: [emAndamento], lidas: [aguardando]);

      await tester.tap(find.text(pagarNaPagina));
      await tester.pumpAndSettle();
      await tocarNoPix(tester);

      expect(naTelaDoPix, findsNothing);
      expect(find.text(emAndamento.mensagem), findsOneWidget);
    });

    testWidgets('409 no outro sentido: o Pix aberto antes, e a página do Mercado Pago recusada', (tester) async {
      await abrir(tester, pedir: [pix], conferir: varias(aguardando), pagar: [emAndamento], lidas: [aguardando]);

      await tocarNoPix(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text(pagarNaPagina));
      await tester.pumpAndSettle();

      expect(abridor.pagamentos, isEmpty);
      expect(find.text(emAndamento.mensagem), findsOneWidget);
    });

    testWidgets('o prazo vence com a tela do Pix aberta: ela fica até a API decidir, e então a folha', (tester) async {
      // A conferência do Pix espera até depois do prazo, e então a API diz que
      // a reserva venceu. O Pagamento, por baixo, também confere no prazo.
      await abrir(
        tester,
        pedir: [pix],
        conferir: [...varias(aguardando, 180), expirada],
        lidas: varias(expirada, 40),
      );
      await tocarNoPix(tester);

      await passar(tester, const Duration(minutes: 14, seconds: 59));
      await passar(tester, const Duration(seconds: 1));
      await tester.pump();
      expect(naTelaDoPix, findsOneWidget, reason: 'o Pagamento não decide com a tela do Pix por cima');
      expect(find.text(tituloDaFolha), findsNothing);

      await passar(tester, const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(naTelaDoPix, findsNothing);
      expect(find.text(tituloDaFolha), findsOneWidget);
    });

    testWidgets('Pix pago no último instante, de volta ao Pagamento: o prazo confere antes de vencer', (tester) async {
      await abrir(tester, pedir: [pix], conferir: varias(aguardando), lidas: [paga]);
      await tocarNoPix(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await passar(tester, const Duration(minutes: 14, seconds: 59));
      await passar(tester, const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeConsulta, [50]);
      expect(find.text(tituloDaFolha), findsNothing);
      expect(find.text('Consulta confirmada'), findsOneWidget);
    });

    testWidgets('sair do Pagamento depois de abrir o Pix pergunta como quem começou a pagar', (tester) async {
      await abrir(tester, pedir: [pix], conferir: varias(aguardando));
      await tocarNoPix(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Sair do pagamento?'), findsOneWidget);
    });

    group('acessibilidade nos quatro aparelhos', () {
      testWidgets('a tela do Pix: nada estoura, nem a 200%', (tester) async {
        await abrir(tester, pedir: [pix], conferir: varias(aguardando, 2000));
        await tocarNoPix(tester);

        await conferirNosQuatroAparelhos(tester);

        // A conferência rolou a tela toda, e ela continua aberta, esperando.
        expect(find.widgetWithText(AppBar, pagarComPix), findsOneWidget);
      });

      testWidgets('o Pagamento com os dois botões: nada estoura', (tester) async {
        await abrir(tester);

        await conferirNosQuatroAparelhos(tester);
      });
    });
  });
}
