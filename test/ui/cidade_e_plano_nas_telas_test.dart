import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/cidade.dart';
import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/forma_de_pagamento.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/plano.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/busca/busca_screen.dart';
import 'package:agendamento_clinico/ui/busca/busca_view_model.dart';
import 'package:agendamento_clinico/ui/busca/seletores.dart';
import 'package:agendamento_clinico/ui/comum/card_do_profissional.dart';
import 'package:agendamento_clinico/ui/profissional/horarios_view_model.dart';
import 'package:agendamento_clinico/ui/profissional/profissional_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/acessibilidade.dart';
import '../apoio/falsos.dart';

const quixada = Cidade(id: 1, nome: 'Quixadá', uf: 'CE');
const fortaleza = Cidade(id: 3, nome: 'Fortaleza', uf: 'CE');
const unimed = Plano(id: 3, nome: 'Unimed');
const hapvida = Plano(id: 4, nome: 'Hapvida');
const bradesco = Plano(id: 5, nome: 'Bradesco Saúde');
const cardiologia = Especialidade(id: 2, nome: 'Cardiologia');

/// Quarta-feira, 11/11/2026, meio-dia em Quixadá.
final meioDia = DateTime.utc(2026, 11, 11, 15);
final hoje = DataCivil.tentar(2026, 11, 11)!;

/// Um instante dito no relógio da clínica (UTC−3).
DateTime naClinica(int dia, int hora, [int minuto = 0]) => DateTime.utc(2026, 11, dia, hora + 3, minuto);

Profissional profissional({
  int id = 2,
  String nome = 'Carlos Eduardo Timbó',
  Cidade? cidade = quixada,
  List<Plano> planos = const [unimed, hapvida],
  List<FormaDePagamento> formas = const [FormaDePagamento.app, FormaDePagamento.plano],
  ProximoHorario? proximo,
  bool informa = true,
}) => Profissional(
  id: id,
  nome: nome,
  registroConselho: 'CRM-CE 12345',
  valorFormatado: 'R\$ 250,00',
  especialidade: cardiologia,
  clinica: Clinica(nome: 'Clínica Exemplo', endereco: 'Centro', telefone: '(88) 3000-0000', cidade: cidade),
  planos: planos,
  formasDePagamento: formas,
  proximoHorario: proximo,
  informaProximoHorario: informa,
);

final amanhaAsNove = ProximoHorario(id: 9, inicio: naClinica(12, 9));

Future<void> montarCard(
  WidgetTester tester,
  Profissional profissional, {
  bool mostrarCidade = false,
  DataCivil? dia,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: temaDoApp(),
      home: Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CardDoProfissional(
              profissional: profissional,
              aoTocar: () {},
              hoje: dia ?? hoje,
              mostrarCidade: mostrarCidade,
            ),
          ],
        ),
      ),
    ),
  );
}

/// A Busca, com o relógio parado no meio-dia de quarta.
Future<BuscaViewModel> montarBusca(
  WidgetTester tester,
  CatalogoFalso catalogo, {
  PreferenciasFalsas? preferencias,
}) async {
  final vm = BuscaViewModel(catalogo, preferencias: preferencias, relogio: () => meioDia);
  unawaited(vm.carregar());
  await tester.pumpWidget(
    MaterialApp(
      theme: temaDoApp(),
      home: ChangeNotifierProvider.value(
        value: vm,
        child: BuscaScreen(aoAbrir: (_) {}),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(vm.dispose);
  return vm;
}

void main() {
  group('o próximo horário, em texto', () {
    test('hoje e amanhã pelo nome; os outros dias, abreviados; a hora, a da clínica', () {
      expect(
        textoDoProximoHorario(ProximoHorario(id: 1, inicio: naClinica(11, 16, 30)), hoje: hoje),
        'Próximo horário: hoje, 16:30',
      );
      expect(textoDoProximoHorario(amanhaAsNove, hoje: hoje), 'Próximo horário: amanhã, 09:00');
      expect(
        textoDoProximoHorario(ProximoHorario(id: 1, inicio: naClinica(16, 14)), hoje: hoje),
        'Próximo horário: seg, 16/11, 14:00',
      );
    });

    test('22:30 na clínica ainda é o dia de hoje, embora em UTC já seja o seguinte', () {
      expect(
        textoDoProximoHorario(ProximoHorario(id: 1, inicio: naClinica(11, 22, 30)), hoje: hoje),
        'Próximo horário: hoje, 22:30',
      );
    });

    test('sem horário livre', () {
      expect(textoDoProximoHorario(null, hoje: hoje), 'Sem horário livre nos próximos dias');
    });
  });

  group('os planos, em texto', () {
    test('um, dois, ou a quantidade; nenhum, nada', () {
      expect(planosAceitos(const []), isNull);
      expect(planosAceitos(const [unimed]), 'Aceita Unimed');
      expect(planosAceitos(const [unimed, hapvida]), 'Aceita Unimed e Hapvida');
      expect(planosAceitos(const [unimed, hapvida, bradesco]), 'Aceita 3 planos');
    });
  });

  group('o card', () {
    testWidgets('mostra os planos e o próximo horário, e lê tudo numa frase', (tester) async {
      final semantica = tester.ensureSemantics();
      await montarCard(tester, profissional(proximo: amanhaAsNove));

      expect(find.text('Aceita Unimed e Hapvida'), findsOneWidget);
      expect(find.text('Próximo horário: amanhã, 09:00'), findsOneWidget);
      final leitura = tester.getSemantics(find.text('Carlos Eduardo Timbó')).getSemanticsData().label;
      expect(leitura, contains('Aceita Unimed e Hapvida'));
      expect(leitura, contains('Próximo horário: amanhã'));
      semantica.dispose();
    });

    testWidgets('sem horário livre, diz isso', (tester) async {
      await montarCard(tester, profissional());

      expect(find.text('Sem horário livre nos próximos dias'), findsOneWidget);
    });

    testWidgets('a API de produção (v1) não informa o próximo horário: a linha não aparece', (tester) async {
      await montarCard(tester, profissional(informa: false, planos: const []));

      expect(find.textContaining('horário'), findsNothing);
      expect(find.textContaining('Aceita'), findsNothing);
    });

    testWidgets('a cidade aparece só quando a busca está em todas as cidades', (tester) async {
      await montarCard(tester, profissional(), mostrarCidade: true);
      expect(find.text('Quixadá, CE'), findsOneWidget);

      await montarCard(tester, profissional());
      expect(find.text('Quixadá, CE'), findsNothing);
    });

    testWidgets('com tudo, a 200% numa tela estreita, nada estoura nem é cortado', (tester) async {
      await usarAparelho(tester, aparelhos[1]);
      await montarCard(tester, profissional(proximo: amanhaAsNove), mostrarCidade: true);

      await conferirAcessibilidade(tester);
    });
  });

  group('os seletores na Busca', () {
    CatalogoFalso catalogo({List<Object?>? cidades, List<Profissional> lista = const []}) => CatalogoFalso(
      especialidades: [
        [cardiologia],
      ],
      cidades:
          cidades ??
          [
            [fortaleza, quixada],
          ],
      planos: [
        [hapvida, unimed],
      ],
      profissionais: [
        for (var i = 0; i < 4; i++) paginaDe([profissional(proximo: amanhaAsNove), ...lista]),
      ],
    );

    testWidgets('começam em "Todas as cidades" e "Plano", com o card mostrando a cidade', (tester) async {
      await montarBusca(tester, catalogo());

      expect(find.text('Todas as cidades'), findsOneWidget);
      expect(find.text('Plano'), findsOneWidget);
      expect(find.text('Quixadá, CE'), findsOneWidget);
      expect(find.bySemanticsLabel('Cidade: Todas as cidades. Trocar'), findsOneWidget);
      expect(find.bySemanticsLabel('Plano de saúde: qualquer um. Escolher'), findsOneWidget);
    });

    testWidgets('escolher a cidade na folha: a busca vai nela, guarda, e o card não repete a cidade', (tester) async {
      final preferencias = PreferenciasFalsas();
      final falso = catalogo();
      final vm = await montarBusca(tester, falso, preferencias: preferencias);

      await tester.tap(find.byType(SeletorDaCidade));
      await tester.pumpAndSettle();
      expect(find.text('Onde você quer se consultar?'), findsOneWidget);
      await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('Quixadá, CE')));
      await tester.pumpAndSettle();

      expect(vm.cidade, quixada);
      expect(falso.filtrosDosPedidos.last.cidadeId, 1);
      expect(preferencias.guardadas, [1]);
      // No seletor, sim; no card, não.
      expect(find.text('Quixadá, CE'), findsOneWidget);
      expect(find.bySemanticsLabel('Cidade: Quixadá, CE. Trocar'), findsOneWidget);
    });

    testWidgets('a folha marca a escolhida; fechar sem escolher não muda nada', (tester) async {
      final falso = catalogo();
      final vm = await montarBusca(tester, falso, preferencias: PreferenciasFalsas(cidade: 3));

      await tester.tap(find.byType(SeletorDaCidade));
      await tester.pumpAndSettle();
      final marcada = tester.widget<ListTile>(
        find.ancestor(
          of: find.descendant(of: find.byType(BottomSheet), matching: find.text('Fortaleza, CE')),
          matching: find.byType(ListTile),
        ),
      );
      expect(marcada.selected, isTrue);

      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(vm.cidade, fortaleza);
      expect(falso.pedidosDeProfissionais, hasLength(1));
    });

    testWidgets('escolher o plano: o seletor diz qual, e "Limpar filtros" o tira', (tester) async {
      final falso = catalogo();
      await montarBusca(tester, falso);

      await tester.tap(find.byType(SeletorDoPlano));
      await tester.pumpAndSettle();
      expect(find.text('Qual o seu plano de saúde?'), findsOneWidget);
      await tester.tap(find.text('Unimed'));
      await tester.pumpAndSettle();

      expect(find.text('Plano: Unimed'), findsOneWidget);
      expect(falso.filtrosDosPedidos.last.planoId, 3);

      await tester.tap(find.text('Limpar filtros'));
      await tester.pumpAndSettle();
      expect(find.text('Plano'), findsOneWidget);
      expect(falso.filtrosDosPedidos.last.planoId, isNull);
    });

    testWidgets('sem a lista de cidades, a folha tenta de novo e, sem sucesso, diz isso', (tester) async {
      await montarBusca(tester, catalogo(cidades: [const ErroDaApi.semConexao(), const ErroDaApi.semConexao()]));

      await tester.tap(find.byType(SeletorDaCidade));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível carregar as cidades agora. A busca mostra todas.'), findsOneWidget);
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('Todas as cidades')), findsOneWidget);
    });

    testWidgets('lista vazia com plano e cidade: diz o que foi pedido, e a saída', (tester) async {
      final falso = CatalogoFalso(
        especialidades: [
          [cardiologia],
        ],
        cidades: [
          [quixada],
        ],
        planos: [
          [unimed],
        ],
        profissionais: [paginaDe([]), paginaDe([]), paginaDe([])],
      );
      final vm = await montarBusca(tester, falso, preferencias: PreferenciasFalsas(cidade: 1));
      vm.escolherPlano(3);
      await tester.pumpAndSettle();
      vm.escolherEspecialidade(2);
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Nenhum profissional de Cardiologia que aceite Unimed em Quixadá. Tente outro plano, ou qualquer plano.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nos quatro aparelhos, com os seletores escolhidos e o card completo', (tester) async {
      final falso = CatalogoFalso(
        especialidades: [
          [cardiologia],
        ],
        cidades: [
          [quixada],
        ],
        planos: [
          [bradesco],
        ],
        profissionais: [
          for (var i = 0; i < 10; i++)
            paginaDe([
              profissional(proximo: amanhaAsNove, planos: const [unimed, hapvida, bradesco]),
              profissional(id: 5, nome: 'Ana Beatriz Lopes', proximo: null),
            ]),
        ],
      );
      final vm = await montarBusca(tester, falso, preferencias: PreferenciasFalsas(cidade: 1));
      vm.escolherPlano(5);
      await tester.pumpAndSettle();

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('a folha dos planos, nos quatro aparelhos', (tester) async {
      await montarBusca(
        tester,
        catalogo(),
      );
      await tester.tap(find.byType(SeletorDoPlano));
      await tester.pumpAndSettle();

      for (final aparelho in aparelhos) {
        await usarAparelho(tester, aparelho);
        await conferirAcessibilidade(
          tester,
          lista: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
          motivo: aparelho.nome,
        );
      }
    });

    testWidgets('a folha das cidades, nos quatro aparelhos', (tester) async {
      await montarBusca(
        tester,
        catalogo(
          cidades: [
            [for (var i = 1; i <= 12; i++) Cidade(id: i, nome: 'Cidade número $i do Sertão Central', uf: 'CE')],
          ],
        ),
      );
      await tester.tap(find.byType(SeletorDaCidade));
      await tester.pumpAndSettle();

      for (final aparelho in aparelhos) {
        await usarAparelho(tester, aparelho);
        await conferirAcessibilidade(
          tester,
          lista: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
        );
      }
    });
  });

  group('o perfil do profissional', () {
    Future<void> montarPerfil(WidgetTester tester, Profissional profissional) async {
      tester.view.physicalSize = const Size(400, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final catalogo = CatalogoFalso(horarios: [<Horario>[]]);
      final vm = HorariosViewModel(catalogo, profissional, agora: () => meioDia);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AbridorDeLinks>.value(value: AbridorDeLinksFalso()),
            Provider<RepositorioDoCatalogo>.value(value: catalogo),
            Provider<RepositorioDeConsultas>.value(value: ConsultasFalso()),
          ],
          child: MaterialApp(
            theme: temaDoApp(),
            home: ChangeNotifierProvider(create: (_) => vm..carregar(), child: const ProfissionalScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('a cidade da clínica, as formas de pagamento e os planos aceitos', (tester) async {
      await montarPerfil(
        tester,
        profissional(formas: const [FormaDePagamento.app, FormaDePagamento.plano, FormaDePagamento.clinica]),
      );

      expect(find.text('Quixadá, CE'), findsOneWidget);
      expect(find.text('Pagamento pelo aplicativo, pelo plano de saúde ou na clínica.'), findsOneWidget);
      expect(find.text('Planos aceitos'), findsOneWidget);
      expect(find.text('Unimed, Hapvida'), findsOneWidget);
      expect(find.textContaining('Pagamento antecipado'), findsNothing);
    });

    testWidgets('sem o aplicativo, com a cidade, as formas e três planos: "Etapa 1 de 2", nos quatro aparelhos', (
      tester,
    ) async {
      await montarPerfil(
        tester,
        profissional(
          formas: const [FormaDePagamento.plano, FormaDePagamento.clinica],
          planos: const [unimed, hapvida, bradesco],
        ),
      );
      expect(find.text('Etapa 1 de 2'), findsOneWidget);

      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('só o aplicativo e nenhum plano: a frase de sempre, e sem a linha dos planos', (tester) async {
      await montarPerfil(tester, profissional(formas: const [FormaDePagamento.app], planos: const [], cidade: null));

      expect(find.text('Pagamento antecipado, feito pelo aplicativo.'), findsOneWidget);
      expect(find.text('Planos aceitos'), findsNothing);
    });

    test('as formas numa frase', () {
      expect(textoDasFormas(const [FormaDePagamento.clinica]), 'Pagamento na clínica.');
      expect(
        textoDasFormas(const [FormaDePagamento.app, FormaDePagamento.clinica]),
        'Pagamento pelo aplicativo ou na clínica.',
      );
    });
  });
}
