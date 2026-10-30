import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/pagina.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/agendamento/pagamento_screen.dart';
import 'package:agendamento_clinico/ui/busca/busca_view_model.dart';
import 'package:agendamento_clinico/ui/comum/textos.dart';
import 'package:agendamento_clinico/ui/consultas/consultas_view_model.dart';
import 'package:agendamento_clinico/ui/consultas/detalhes_da_consulta_screen.dart';
import 'package:agendamento_clinico/ui/consultas/detalhes_da_consulta_view_model.dart';
import 'package:agendamento_clinico/ui/consultas/minhas_consultas_screen.dart';
import 'package:agendamento_clinico/ui/consultas/situacao_da_consulta.dart';
import 'package:agendamento_clinico/ui/inicio/inicio_screen.dart';
import 'package:agendamento_clinico/ui/profissional/profissional_screen.dart';
import 'package:agendamento_clinico/ui/shell/abas_do_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../apoio/acessibilidade.dart';
import '../../apoio/agenda.dart';
import '../../apoio/falsos.dart';

/// Quarta, 14/10, meio-dia na clínica. Os testes adiantam o relógio.
late DateTime agora;

const cardiologia = Especialidade(id: 2, nome: 'Cardiologia');
const pediatria = Especialidade(id: 6, nome: 'Pediatria');

Pagina<Consulta> pagina(List<Consulta> itens, {int numero = 1, int paginas = 1, int? total}) =>
    Pagina(itens: itens, pagina: numero, paginas: paginas, total: total ?? itens.length);

// Quinta, 15/10, às 14:30 — amanhã.
final amanha = horario(7, 15, 14, minuto: 30);
final reservada = consultaNa(
  amanha,
  status: StatusDaConsulta.pendentePagamento,
  expiraEm: meioDiaDeQuarta.add(const Duration(minutes: 15)),
);
final confirmada = consultaNa(amanha);
final cancelada = consultaNa(amanha, status: StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.paciente);
final expirada = consultaNa(amanha, status: StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.reservaExpirada);

late ConsultasFalso consultas;
late CatalogoFalso catalogo;
late AbridorDeLinksFalso abridor;
late AbasDoShell abas;

/// Monta uma aba do shell — o Início, Minhas consultas — com as listas que o
/// shell lhe daria, ou, com [abrirDetalhes], os detalhes de uma consulta.
Future<void> montar(
  WidgetTester tester, {
  Widget? aba,
  ConsultaNaLista? abrirDetalhes,
  List<Object?> minhas = const [],
  List<Object?> cancelar = const [],
  List<Object?> lidas = const [],
  // O Início mostra as especialidades da busca, que pede as duas coisas.
  List<Object?> especialidades = const [<Especialidade>[]],
  List<Object?> profissionais = const [Pagina<Profissional>(itens: [], pagina: 1, paginas: 1, total: 0)],
  List<Object?> horarios = const [],
  double altura = 1400,
  bool assentar = true,
}) async {
  tester.view.physicalSize = Size(411, altura);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  consultas = ConsultasFalso(minhas: minhas, cancelar: cancelar, consulta: lidas);
  catalogo = CatalogoFalso(especialidades: especialidades, profissionais: profissionais, horarios: horarios);
  abridor = AbridorDeLinksFalso();
  abas = AbasDoShell();
  addTearDown(abas.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<RepositorioDeConsultas>.value(value: consultas),
      Provider<RepositorioDoCatalogo>.value(value: catalogo),
      Provider<AbridorDeLinks>.value(value: abridor),
      ChangeNotifierProvider<AbasDoShell>.value(value: abas),
      ChangeNotifierProvider(create: (_) => ConsultasViewModel(consultas, relogio: () => agora)..carregar()),
      ChangeNotifierProvider(create: (_) => BuscaViewModel(catalogo)..carregar()),
    ],
    child: MaterialApp(
      theme: temaDoApp(),
      home: aba ??
          Builder(
            builder: (contexto) => Scaffold(
              body: Center(
                child: TextButton(
                  onPressed: () => Navigator.of(contexto).push(rotaDosDetalhes(abrirDetalhes!, relogio: () => agora)),
                  child: const Text('Ir aos detalhes'),
                ),
              ),
            ),
          ),
    ),
  ));
  // Com uma resposta presa, o indicador de carga não para de girar.
  if (assentar) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  if (abrirDetalhes != null) {
    await tester.tap(find.text('Ir aos detalhes'));
    await tester.pumpAndSettle();
  }
}

/// O botão do rodapé dos detalhes, e não o do diálogo, que tem o mesmo texto.
Finder botaoDoRodape(String texto) => find.ancestor(of: find.text(texto), matching: find.byType(OutlinedButton));

/// O botão do diálogo de confirmação.
Finder noDialogo(String texto) => find.descendant(of: find.byType(AlertDialog), matching: find.text(texto));

/// Adianta o relógio das telas e o tempo do teste juntos.
Future<void> passar(WidgetTester tester, Duration tempo) async {
  agora = agora.add(tempo);
  await tester.pump(tempo);
}

void main() {
  setUp(() => agora = meioDiaDeQuarta);

  group('Início', () {
    testWidgets('a reserva aguardando: o aviso com o prazo, e "Pagar agora" reabre o pagamento sem a etapa', (
      tester,
    ) async {
      await montar(tester, aba: const InicioScreen(), minhas: [pagina([reservada])]);

      expect(
        find.text('Reserva aguardando pagamento. Carlos Eduardo Timbó, Amanhã, quinta-feira, 15/10\u00a0·\u00a014:30. '
            'Seu horário fica reservado até 12:15.'),
        findsOneWidget,
      );
      expect(find.text('Você ainda não tem consultas'), findsNothing);

      await tester.tap(find.text('Pagar agora'));
      await tester.pumpAndSettle();
      expect(find.byType(PagamentoScreen), findsOneWidget);
      expect(find.text('Etapa 3 de 3'), findsNothing);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sair'));
      await tester.pumpAndSettle();
    });

    testWidgets('a próxima consulta é a confirmada mais cedo, com o endereço; tocar abre os detalhes', (tester) async {
      final depois = consultaNa(horario(8, 21, 9), id: 51);
      await montar(tester, aba: const InicioScreen(), minhas: [pagina([depois, confirmada])]);

      expect(find.text('Sua próxima consulta'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10\u00a0·\u00a014:30'), findsOneWidget);
      expect(find.text('Quarta-feira, 21/10\u00a0·\u00a009:00'), findsNothing);
      expect(find.text('Clínica Exemplo Quixadá · Centro, Quixadá - CE'), findsOneWidget);

      await tester.tap(find.text('Amanhã, quinta-feira, 15/10\u00a0·\u00a014:30'));
      await tester.pumpAndSettle();
      expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
    });

    testWidgets('"Ver todas" abre Minhas consultas', (tester) async {
      await montar(tester, aba: const InicioScreen(), minhas: [pagina([confirmada])]);

      await tester.tap(find.text('Ver todas'));
      expect(abas.aba, AbaDoShell.consultas);
    });

    testWidgets('o convite para agendar só aparece com a carga pronta, e leva à busca', (tester) async {
      final resposta = Completer<Pagina<Consulta>>();
      await montar(tester, aba: const InicioScreen(), minhas: [resposta], assentar: false);
      expect(find.text('Você ainda não tem consultas'), findsNothing);

      resposta.complete(pagina([]));
      await tester.pumpAndSettle();
      expect(find.text('Você ainda não tem consultas'), findsOneWidget);

      await tester.tap(find.text('Agendar consulta'));
      expect(abas.aba, AbaDoShell.buscar);
    });

    testWidgets('as especialidades, com o nome comum; tocar escolhe a especialidade na busca', (tester) async {
      await montar(
        tester,
        aba: const InicioScreen(),
        minhas: [pagina([])],
        especialidades: [
          [cardiologia, pediatria],
        ],
        profissionais: [paginaDe([]), paginaDe([timbo])],
      );

      expect(find.text('Especialidades'), findsOneWidget);
      expect(find.text('Coração'), findsOneWidget);
      expect(find.text('Crianças'), findsOneWidget);

      await tester.tap(find.text('Cardiologia'));
      await tester.pump();
      expect(abas.aba, AbaDoShell.buscar);
      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: null, pagina: 1));
    });

    testWidgets('a lista que não carrega: a mensagem e "Tentar de novo"', (tester) async {
      await montar(tester, aba: const InicioScreen(), minhas: [const ErroDaApi.semConexao(), pagina([confirmada])]);

      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
      await tester.tap(find.text(Textos.tentarDeNovo));
      await tester.pumpAndSettle();
      expect(find.text('Sua próxima consulta'), findsOneWidget);
    });

    testWidgets('toque, rótulos e contraste, com a reserva e a próxima consulta', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(
        tester,
        aba: const InicioScreen(),
        minhas: [
          pagina([consultaNa(horario(8, 16, 9), id: 51), reservada]),
        ],
        especialidades: [
          [cardiologia],
        ],
        profissionais: [paginaDe([])],
      );

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  });

  group('Minhas consultas', () {
    testWidgets('as próximas, da mais cedo para a mais tarde, e a contagem das duas listas', (tester) async {
      final depois = consultaNa(horario(8, 21, 9), id: 51);
      final passada = consultaNa(horario(9, 13, 9), id: 52);
      await montar(tester, aba: const MinhasConsultasScreen(), minhas: [pagina([depois, confirmada, passada])]);

      expect(find.text('Próximas (2)'), findsOneWidget);
      expect(find.text('Anteriores (1)'), findsOneWidget);
      final primeira = tester.getTopLeft(find.text('Amanhã, quinta-feira, 15/10\u00a0·\u00a014:30'));
      final segunda = tester.getTopLeft(find.text('Quarta-feira, 21/10\u00a0·\u00a009:00'));
      expect(primeira.dy, lessThan(segunda.dy));
      expect(find.text('Terça-feira, 13/10\u00a0·\u00a009:00'), findsNothing);
    });

    testWidgets('as anteriores, com o selo, e "Agendar de novo" abre a grade do profissional', (tester) async {
      await montar(
        tester,
        aba: const MinhasConsultasScreen(),
        minhas: [pagina([cancelada])],
        horarios: [<Horario>[]],
      );

      expect(find.text('Próximas (0)'), findsOneWidget);
      await tester.tap(find.text('Anteriores (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelada'), findsOneWidget);

      await tester.tap(find.text('Agendar de novo com Carlos Eduardo Timbó'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfissionalScreen), findsOneWidget);
    });

    testWidgets('as listas vazias convidam a agendar', (tester) async {
      await montar(tester, aba: const MinhasConsultasScreen(), minhas: [pagina([])]);

      expect(find.text('Você ainda não tem consultas marcadas'), findsOneWidget);
      await tester.tap(find.text('Anteriores (0)'));
      await tester.pumpAndSettle();
      expect(find.text('Nenhuma consulta anterior'), findsOneWidget);

      await tester.tap(find.text('Agendar consulta'));
      expect(abas.aba, AbaDoShell.buscar);
    });

    testWidgets('"Mostrar mais consultas" traz as anteriores que faltam', (tester) async {
      final passada = consultaNa(horario(9, 13, 9), id: 52);
      final antes = consultaNa(horario(10, 12, 9), id: 53, status: StatusDaConsulta.cancelada);
      await montar(
        tester,
        aba: const MinhasConsultasScreen(),
        minhas: [
          pagina([confirmada, passada], paginas: 2, total: 3),
          pagina([antes], numero: 2, paginas: 2, total: 3),
        ],
      );

      await tester.tap(find.text('Anteriores (2)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar mais consultas'));
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeMinhas, [1, 2]);
      expect(find.text('Segunda-feira, 12/10\u00a0·\u00a009:00'), findsOneWidget);
      expect(find.text('Mostrar mais consultas'), findsNothing);
    });

    testWidgets('puxar para atualizar pede a lista de novo, também vazia', (tester) async {
      await montar(tester, aba: const MinhasConsultasScreen(), minhas: [pagina([]), pagina([confirmada])]);

      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeMinhas, [1, 1]);
      expect(find.text('Próximas (1)'), findsOneWidget);
    });

    testWidgets('toque, rótulos e contraste, nas duas listas', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, aba: const MinhasConsultasScreen(), minhas: [pagina([confirmada, cancelada])]);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.text('Anteriores (1)'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  });

  group('detalhes', () {
    testWidgets('aguardando pagamento: o prazo, "Pagar agora" e "Cancelar consulta"', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(reservada));

      // Em destaque no topo, sem quebra entre a data e a hora; e de novo no
      // cartão da consulta.
      expect(find.text('Amanhã, quinta-feira, 15/10\u00a0·\u00a014:30'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 14:30'), findsOneWidget);
      expect(find.text('Aguardando pagamento'), findsOneWidget);
      expect(find.text('Seu horário fica reservado até 12:15.'), findsOneWidget);
      expect(find.text('Pagar agora'), findsOneWidget);
      expect(botaoDoRodape('Cancelar consulta'), findsOneWidget);
      expect(find.text('Agendar de novo'), findsNothing);
    });

    testWidgets('confirmada, antes do horário: só "Cancelar consulta", e as regras de cancelamento', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(confirmada));

      expect(find.text('Confirmada'), findsOneWidget);
      expect(find.text('Pagar agora'), findsNothing);
      expect(botaoDoRodape('Cancelar consulta'), findsOneWidget);

      await tester.tap(find.text('Regras de cancelamento'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Se faltar sem cancelar, o valor não é devolvido.'), findsOneWidget);
      expect(find.textContaining('ligue para a clínica: (88)\u00a03000-0000.'), findsOneWidget);
    });

    testWidgets('cancelada por você: a nota da devolução, e "Agendar de novo"', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(cancelada));

      expect(find.text('Cancelada'), findsOneWidget);
      expect(
        find.text('Você cancelou esta consulta. Se ela já estava paga, o valor é devolvido integralmente.'),
        findsOneWidget,
      );
      expect(find.text('Agendar de novo'), findsOneWidget);
      expect(find.text('Cancelar consulta'), findsNothing);
    });

    testWidgets('reserva expirada: a nota, e "Agendar de novo"', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(expirada));

      expect(find.text('Reserva expirada'), findsOneWidget);
      expect(find.text('O prazo para pagar esta reserva terminou, e o horário voltou a ficar livre.'), findsOneWidget);
      expect(find.text('Agendar de novo'), findsOneWidget);
    });

    testWidgets('reserva vencida, ainda aguardando na API: a confirmação pode chegar, e nem pagar nem cancelar', (
      tester,
    ) async {
      agora = meioDiaDeQuarta.add(const Duration(minutes: 16));
      await montar(tester, abrirDetalhes: itemDe(reservada));

      expect(
        find.text('O prazo para pagar esta reserva terminou. Se você já pagou, a confirmação ainda pode chegar.'),
        findsOneWidget,
      );
      expect(find.text('Pagar agora'), findsNothing);
      expect(find.text('Cancelar consulta'), findsNothing);
    });

    testWidgets('"Abrir no mapa" e "Ligar para a clínica", só com os dados da clínica', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(confirmada));
      await tester.tap(find.text('Abrir no mapa'));
      await tester.tap(find.text('Ligar para a clínica'));
      await tester.pump();
      expect(abridor.mapas, ['Clínica Exemplo Quixadá, Centro, Quixadá - CE']);
      expect(abridor.ligacoes, ['(88) 3000-0000']);
    });

    testWidgets('sem endereço nem telefone, os dois somem', (tester) async {
      final semDados = consultaNa(amanha, profissional: timboNa(const Clinica(nome: 'Clínica Exemplo Quixadá')));
      await montar(tester, abrirDetalhes: itemDe(semDados));

      expect(find.text('Abrir no mapa'), findsNothing);
      expect(find.text('Ligar para a clínica'), findsNothing);
    });

    testWidgets('cancelar a confirmada: pergunta, cancela, diz "Consulta cancelada." e mostra a nota', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(confirmada), cancelar: [cancelada]);

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      expect(find.text('Cancelar esta consulta?'), findsOneWidget);
      expect(find.textContaining('O valor pago é devolvido integralmente.'), findsOneWidget);
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeCancelar, [50]);
      expect(find.text('Consulta cancelada.'), findsOneWidget);
      expect(find.text('Cancelada'), findsOneWidget);
      expect(find.textContaining('Você cancelou esta consulta.'), findsOneWidget);
      expect(find.text('Agendar de novo'), findsOneWidget);
    });

    testWidgets('cancelar a reserva que aguarda: o diálogo não diz que estava paga; "Manter consulta" não cancela', (
      tester,
    ) async {
      await montar(tester, abrirDetalhes: itemDe(reservada));

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Esta consulta ainda aguarda a confirmação do pagamento.'), findsOneWidget);

      await tester.tap(noDialogo('Manter consulta'));
      await tester.pumpAndSettle();
      expect(consultas.pedidosDeCancelar, isEmpty);
      expect(botaoDoRodape('Cancelar consulta'), findsOneWidget);
    });

    testWidgets('dois toques, um pedido: o botão trava e diz "Cancelando…"', (tester) async {
      final resposta = Completer<Consulta>();
      await montar(tester, abrirDetalhes: itemDe(confirmada), cancelar: [resposta]);

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      // O diálogo termina de sair; o pedido continua no ar.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Cancelando…'), findsOneWidget);
      await tester.tap(find.text('Cancelando…'));
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      // Voltar, com o pedido no ar, deixaria a pessoa sem saber se cancelou.
      // Esperando o tempo de uma tela sair, se ela fosse sair.
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);

      resposta.complete(cancelada);
      await tester.pumpAndSettle();
      expect(consultas.pedidosDeCancelar, [50]);
    });

    testWidgets('a reserva que a API já tinha expirado: a nota dela, sem "Consulta cancelada."', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(reservada), cancelar: [expirada]);

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Consulta cancelada.'), findsNothing);
      expect(find.text('Reserva expirada'), findsOneWidget);
    });

    testWidgets('a recusa: a mensagem da API, e a consulta como ela a tem', (tester) async {
      const naoCancelavel = ErroDaApi(
        status: 422,
        codigo: 'CONSULTA_NAO_CANCELAVEL',
        mensagem: 'Consultas já realizadas não podem ser canceladas.',
      );
      await montar(tester, abrirDetalhes: itemDe(confirmada), cancelar: [naoCancelavel], lidas: [confirmada]);

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(find.text('Consultas já realizadas não podem ser canceladas.'), findsOneWidget);
      expect(find.text('Consulta cancelada.'), findsNothing);
      expect(find.text('Confirmada'), findsOneWidget);
    });

    testWidgets('no começo do horário, "Cancelar consulta" some sozinho, sem pedir nada', (tester) async {
      agora = amanha.inicio.subtract(const Duration(minutes: 1));
      await montar(tester, abrirDetalhes: itemDe(confirmada));
      expect(botaoDoRodape('Cancelar consulta'), findsOneWidget);

      await passar(tester, const Duration(minutes: 1));

      expect(find.text('Cancelar consulta'), findsNothing);
      expect(find.text('Agendar de novo'), findsOneWidget);
      expect(consultas.pedidosDeCancelar, isEmpty);
    });

    testWidgets('o diálogo aberto até depois do horário: nada é enviado, e a tela diz por quê', (tester) async {
      agora = amanha.inicio.subtract(const Duration(minutes: 1));
      await montar(tester, abrirDetalhes: itemDe(confirmada));

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await passar(tester, const Duration(minutes: 1));
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();

      expect(consultas.pedidosDeCancelar, isEmpty);
      expect(find.text(DetalhesDaConsultaViewModel.jaComecou), findsOneWidget);
    });

    testWidgets('servidor demorando: o aviso, depois de quatro segundos', (tester) async {
      final resposta = Completer<Consulta>();
      await montar(tester, abrirDetalhes: itemDe(confirmada), cancelar: [resposta]);

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pump();
      await tester.pump(const Duration(seconds: 4));
      expect(find.text(Textos.servidorDemorando), findsOneWidget);

      resposta.complete(cancelada);
      await tester.pumpAndSettle();
      expect(find.text(Textos.servidorDemorando), findsNothing);
    });

    testWidgets('toque, rótulos e contraste, aguardando e cancelada', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, abrirDetalhes: itemDe(reservada), cancelar: [cancelada]);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      await tester.tap(noDialogo('Cancelar consulta'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('a 200%, numa tela pequena, nada estoura, e os botões ficam ao alcance', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await montar(tester, abrirDetalhes: itemDe(reservada), altura: 640);

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Pagar agora').hitTestable(), findsOneWidget);
      expect(botaoDoRodape('Cancelar consulta').hitTestable(), findsOneWidget);
    });
  });

  group('acessibilidade nos quatro aparelhos', () {
    testWidgets('o Início, com a reserva, a próxima consulta e as especialidades', (tester) async {
      await montar(
        tester,
        aba: const InicioScreen(),
        minhas: [
          pagina([consultaNa(horario(8, 16, 9), id: 51), reservada]),
        ],
        especialidades: [
          [cardiologia],
        ],
        profissionais: [paginaDe([])],
      );

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('Minhas consultas, nas duas listas', (tester) async {
      await montar(tester, aba: const MinhasConsultasScreen(), minhas: [pagina([confirmada, cancelada])]);
      await conferirNosQuatroAparelhos(tester);

      await tester.tap(find.text('Anteriores (1)'));
      await tester.pumpAndSettle();
      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('os detalhes: os botões ficam fixos em pé e vão para a lista deitado', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(reservada));

      await conferirNosQuatroAparelhos(tester);

      await usarAparelho(tester, aparelhoEmPe);
      expect(find.descendant(of: listaVertical(), matching: find.text('Pagar agora')), findsNothing);
      await conferirAvisoAcimaDoRodape(tester, botaoDoRodape('Cancelar consulta'));

      // A data é o título da tela, para quem navega pelos cabeçalhos.
      final semantica = tester.ensureSemantics();
      final data = tester.getSemantics(find.text('Amanhã, quinta-feira, 15/10 · 14:30'));
      expect(data.getSemanticsData().flagsCollection.isHeader, isTrue);
      semantica.dispose();
      await usarAparelho(tester, aparelhoDeitado);
      await tester.scrollUntilVisible(find.text('Pagar agora'), 200, scrollable: listaVertical().first);
      expect(find.descendant(of: listaVertical(), matching: find.text('Pagar agora')), findsOneWidget);
    });

    testWidgets('o diálogo de cancelar e a folha das regras, abaixo da barra de status', (tester) async {
      await montar(tester, abrirDetalhes: itemDe(confirmada));
      await tester.tap(botaoDoRodape('Cancelar consulta'));
      await tester.pumpAndSettle();
      for (final aparelho in aparelhos) {
        await usarAparelho(tester, aparelho);
        await conferirAcessibilidade(
          tester,
          lista: find.descendant(of: find.byType(AlertDialog), matching: listaVertical()),
          motivo: aparelho.nome,
        );
      }
      await tester.tap(noDialogo('Manter consulta'));
      await tester.pumpAndSettle();

      await usarAparelho(tester, aparelhoEmPe);
      await tester.scrollUntilVisible(find.text('Regras de cancelamento'), 200, scrollable: listaVertical().first);
      await tester.tap(find.text('Regras de cancelamento'));
      await tester.pumpAndSettle();
      for (final aparelho in aparelhos) {
        await usarAparelho(tester, aparelho);
        expect(tester.getTopLeft(find.byType(BottomSheet)).dy, greaterThanOrEqualTo(24), reason: aparelho.nome);
        await conferirAcessibilidade(
          tester,
          lista: find.descendant(of: find.byType(BottomSheet), matching: listaVertical()),
          motivo: aparelho.nome,
        );
      }
    });
  });
}
