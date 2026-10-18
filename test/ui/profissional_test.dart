import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/profissional/horarios_view_model.dart';
import 'package:agendamento_clinico/ui/profissional/profissional_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/agenda.dart';
import '../apoio/falsos.dart';

/// A grade de sempre: nada hoje, três horários amanhã (quinta) e um na sexta.
final gradeComum = [
  horario(1, 15, 8),
  horario(2, 15, 11, minuto: 30),
  horario(3, 15, 14, minuto: 30),
  horario(4, 16, 9),
];

const mensagemDeDemora = 'O servidor está demorando para responder.';
const resumoVazio = 'Escolha um horário';

class Montagem {
  Montagem(this.catalogo, this.abridor, this.vm, this.consultas);

  final CatalogoFalso catalogo;
  final AbridorDeLinksFalso abridor;
  final HorariosViewModel vm;
  final ConsultasFalso consultas;

  /// O relógio que o view model lê: o teste o adianta para virar o dia.
  static DateTime agora = meioDiaDeQuarta;
}

/// Monta a tela e espera a primeira resposta. A tela é alta, para a grade
/// caber inteira sem rolar — os testes de tamanho de tela dizem o deles.
Future<Montagem> montar(
  WidgetTester tester, {
  required List<Object?> horarios,
  Profissional? profissional,
  bool abre = true,
  Size tela = const Size(400, 1600),
  DateTime? agora,
  ConsultasFalso? consultas,
}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  Montagem.agora = agora ?? meioDiaDeQuarta;

  final catalogo = CatalogoFalso(horarios: horarios);
  final abridor = AbridorDeLinksFalso(consegue: abre);
  final agendamentos = consultas ?? ConsultasFalso();
  final vm = HorariosViewModel(catalogo, profissional ?? timbo, agora: () => Montagem.agora);
  // Os repositórios ficam acima do MaterialApp, como no aplicativo: as telas
  // abertas por cima da grade — o resumo, o pagamento — também os enxergam.
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<AbridorDeLinks>.value(value: abridor),
      Provider<RepositorioDoCatalogo>.value(value: catalogo),
      Provider<RepositorioDeConsultas>.value(value: agendamentos),
    ],
    child: MaterialApp(
      theme: temaDoApp(),
      home: ChangeNotifierProvider(create: (_) => vm..carregar(), child: const ProfissionalScreen()),
    ),
  ));
  await tester.pump();
  // A faixa de dias traz o dia escolhido para a vista depois de desenhada.
  await tester.pump();
  return Montagem(catalogo, abridor, vm, agendamentos);
}

/// O botão de um dia da faixa, achado pela data escrita nele — esteja ele à
/// vista ou logo fora dela.
Finder dia(String diaEMes) => find.ancestor(
      of: find.text(diaEMes, skipOffstage: false),
      matching: find.byType(InkWell, skipOffstage: false),
    );

/// O botão de um horário, achado pela hora escrita nele.
Finder hora(String hora) => find.ancestor(
      of: find.text(hora, skipOffstage: false),
      matching: find.byType(InkWell, skipOffstage: false),
    );

bool marcado(WidgetTester tester, Finder botao) =>
    tester.any(find.descendant(of: botao, matching: find.byIcon(Icons.check)));

/// As datas da faixa de dias, na ordem.
List<String> diasDaFaixa(WidgetTester tester) => [
      for (final texto in tester.widgetList<Text>(find.byType(Text)))
        if (RegExp(r'^\d{2}/\d{2}$').hasMatch(texto.data ?? '')) texto.data!,
    ];

/// Rola a tela até o alvo — a lista só constrói o que está perto da vista — e
/// toca nele.
Future<void> tocar(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(alvo, 200, scrollable: find.byType(Scrollable).first);
  await tester.pump();
  await tester.tap(alvo);
  await tester.pump();
  await tester.pump();
}

/// Puxa a lista para baixo, como o dedo faria, até disparar a atualização.
Future<void> puxarParaAtualizar(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  group('quem atende e onde', () {
    testWidgets('o profissional: nome, especialidade e registro, sem selo de verificado', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(find.text('Carlos Eduardo Timbó'), findsWidgets);
      expect(find.text('Cardiologia'), findsOneWidget);
      expect(find.text('CRM-CE 12345'), findsOneWidget);
      expect(find.textContaining(RegExp('verificad', caseSensitive: false)), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
    });

    testWidgets('a clínica, com endereço e telefone, e o valor antes de qualquer horário', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(find.text('Clínica Exemplo Quixadá'), findsOneWidget);
      expect(find.text('Centro, Quixadá - CE'), findsOneWidget);
      expect(find.text('(88) 3000-0000'), findsOneWidget);
      expect(find.text('R\$ 250,00 por consulta'), findsOneWidget);
      expect(find.text('Pagamento antecipado, feito pelo aplicativo.'), findsOneWidget);
      // O valor vem antes da grade na tela.
      final valor = tester.getTopLeft(find.text('R\$ 250,00 por consulta')).dy;
      expect(valor, lessThan(tester.getTopLeft(find.text('Escolha o dia')).dy));
    });

    testWidgets('"Abrir no mapa" procura a clínica pelo nome e pelo endereço', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      await tocar(tester, find.text('Abrir no mapa'));

      expect(montagem.abridor.mapas, ['Clínica Exemplo Quixadá, Centro, Quixadá - CE']);
      expect(montagem.abridor.ligacoes, isEmpty);
    });

    testWidgets('"Ligar" abre o discador com o telefone da clínica', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      await tocar(tester, find.text('Ligar'));

      expect(montagem.abridor.ligacoes, ['(88) 3000-0000']);
      expect(montagem.abridor.mapas, isEmpty);
    });

    testWidgets('aparelho sem com o que abrir: a mensagem traz o telefone, ou o endereço', (tester) async {
      await montar(tester, horarios: [gradeComum], abre: false);

      await tocar(tester, find.text('Ligar'));
      expect(
        find.text('Não foi possível abrir o telefone. O número da clínica é (88) 3000-0000.'),
        findsOneWidget,
      );

      await tocar(tester, find.text('Abrir no mapa'));
      await tester.pumpAndSettle();
      expect(find.text('Não foi possível abrir o mapa. O endereço é Centro, Quixadá - CE.'), findsOneWidget);
    });

    testWidgets('sem telefone, não há "Ligar"', (tester) async {
      await montar(
        tester,
        horarios: [gradeComum],
        profissional: timboNa(const Clinica(nome: 'Clínica Exemplo Quixadá', endereco: 'Centro, Quixadá - CE')),
      );

      expect(find.text('Abrir no mapa'), findsOneWidget);
      expect(find.text('Ligar'), findsNothing);
    });

    testWidgets('sem endereço, não há "Abrir no mapa"', (tester) async {
      await montar(
        tester,
        horarios: [gradeComum],
        profissional: timboNa(const Clinica(nome: 'Clínica Exemplo Quixadá', telefone: '(88) 3000-0000')),
      );

      expect(find.text('Abrir no mapa'), findsNothing);
      expect(find.text('Ligar'), findsOneWidget);
    });

    testWidgets('clínica só com o nome: o nome, e nenhum atalho', (tester) async {
      await montar(
        tester,
        horarios: [gradeComum],
        profissional: timboNa(const Clinica(nome: 'Clínica Exemplo Quixadá')),
      );

      expect(find.text('Clínica Exemplo Quixadá'), findsOneWidget);
      expect(find.byType(TextButton), findsNothing);
      // Uma divisória só, entre a clínica e o valor: nenhuma linha vazia de atalhos.
      expect(find.byType(Divider), findsOneWidget);
    });

    testWidgets('profissional sem clínica: só o valor, sem linha vazia no lugar dela', (tester) async {
      await montar(tester, horarios: [gradeComum], profissional: timboNa(null));

      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
      expect(find.byType(TextButton), findsNothing);
      expect(find.text('R\$ 250,00 por consulta'), findsOneWidget);
    });

    testWidgets('quem atende, onde e quanto custa já aparecem enquanto a grade carrega, e se ela falha', (
      tester,
    ) async {
      final demora = Completer<List<Horario>>();
      await montar(tester, horarios: [demora]);

      expect(find.text('Carregando…'), findsOneWidget);
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Ligar'), findsOneWidget);
      expect(find.text('R\$ 250,00 por consulta'), findsOneWidget);

      demora.completeError(const ErroDaApi.semConexao());
      await tester.pump();
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.text('Ligar'), findsOneWidget);
    });
  });

  group('dias', () {
    testWidgets('pede a grade do profissional até o fim do 14º dia, contando de hoje', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      // De 14/10 a 27/10: a janela vai até o começo do dia 28.
      expect(montagem.catalogo.pedidosDeHorarios, [(profissionalId: 2, ate: DataCivil.tentar(2026, 10, 28)!)]);
    });

    testWidgets('a faixa tem 14 dias, de hoje em diante, com "Hoje", "Amanhã" e o dia da semana', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(diasDaFaixa(tester), [
        '14/10', '15/10', '16/10', '17/10', '18/10', '19/10', '20/10', //
        '21/10', '22/10', '23/10', '24/10', '25/10', '26/10', '27/10',
      ]);
      expect(find.descendant(of: dia('14/10'), matching: find.text('Hoje')), findsOneWidget);
      expect(find.descendant(of: dia('15/10'), matching: find.text('Amanhã')), findsOneWidget);
      expect(find.descendant(of: dia('16/10'), matching: find.text('sex')), findsOneWidget);
      expect(find.descendant(of: dia('18/10'), matching: find.text('dom')), findsOneWidget);
    });

    testWidgets('hoje é o dia da clínica: às 22:30 de Quixadá ainda é dia 14, mesmo sendo 15 em UTC', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum], agora: DateTime.utc(2026, 10, 15, 1, 30));

      expect(diasDaFaixa(tester).first, '14/10');
      expect(find.descendant(of: dia('14/10'), matching: find.text('Hoje')), findsOneWidget);
      expect(montagem.catalogo.pedidosDeHorarios.last.ate, DataCivil.tentar(2026, 10, 28));
    });

    testWidgets('o mês do dia escolhido aparece ao lado de "Escolha o dia", e muda com ele', (tester) async {
      await montar(tester, horarios: [
        gradeComum,
        [...gradeComum, horario(20, 3, 10, mes: 11)],
      ]);
      expect(find.text('Outubro'), findsOneWidget);

      await tocar(tester, find.text('Ver mais dias'));
      await tocar(tester, dia('03/11'));

      expect(find.text('Novembro'), findsOneWidget);
      expect(find.text('Outubro'), findsNothing);
    });

    testWidgets('na virada do ano, o mês leva o ano', (tester) async {
      // Meio-dia de 30/12/2026, com o primeiro horário em janeiro.
      await montar(
        tester,
        horarios: [
          [horario(1, 4, 9, mes: 1, ano: 2027)],
        ],
        agora: DateTime.utc(2026, 12, 30, 15),
      );

      expect(find.text('Janeiro de 2027'), findsOneWidget);
    });

    testWidgets('cada dia diz quantos horários livres tem', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(find.descendant(of: dia('14/10'), matching: find.text('sem horários')), findsOneWidget);
      expect(find.descendant(of: dia('15/10'), matching: find.text('3 horários')), findsOneWidget);
      expect(find.descendant(of: dia('16/10'), matching: find.text('1 horário')), findsOneWidget);
    });

    testWidgets('o primeiro dia com horário já vem escolhido, com o ícone, e os horários dele na tela', (
      tester,
    ) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 15));
      expect(marcado(tester, dia('15/10')), isTrue);
      expect(marcado(tester, dia('16/10')), isFalse);
      expect(find.text('Amanhã, quinta-feira, 15/10'), findsOneWidget);
      for (final horaLivre in ['08:00', '11:30', '14:30']) {
        expect(find.text(horaLivre), findsOneWidget, reason: horaLivre);
      }
      expect(find.text('09:00'), findsNothing);
    });

    testWidgets('tocar em outro dia mostra os horários dele, e o ícone muda de dia', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      await tocar(tester, dia('16/10'));

      expect(marcado(tester, dia('16/10')), isTrue);
      expect(marcado(tester, dia('15/10')), isFalse);
      expect(find.text('Sexta-feira, 16/10'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('08:00'), findsNothing);
    });

    testWidgets('dia sem horário fica desativado: o toque não muda nada', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      await tester.tap(find.text('17/10'), warnIfMissed: false);
      await tester.pump();

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 15));
      expect(marcado(tester, dia('17/10')), isFalse);
      expect(find.text('Amanhã, quinta-feira, 15/10'), findsOneWidget);
    });

    testWidgets('o leitor de tela lê o dia inteiro num botão só, e sabe qual está escolhido e qual não dá', (
      tester,
    ) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, horarios: [gradeComum]);

      final hoje = tester.getSemantics(find.bySemanticsLabel('Hoje, quarta-feira, 14/10, sem horários'));
      final amanha = tester.getSemantics(find.bySemanticsLabel('Amanhã, quinta-feira, 15/10, 3 horários'));
      final sexta = tester.getSemantics(find.bySemanticsLabel('Sexta-feira, 16/10, 1 horário'));
      expect(amanha.getSemanticsData().flagsCollection.isButton, isTrue);
      expect(amanha.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(amanha.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(), isTrue);
      expect(sexta.getSemanticsData().flagsCollection.isSelected.toBoolOrNull(), isFalse);
      expect(sexta.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      expect(hoje.getSemanticsData().flagsCollection.isEnabled.toBoolOrNull(), isFalse);
      expect(hoje.getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
      semantica.dispose();
    });

    testWidgets('o primeiro dia com horário, se está adiante do que cabe na faixa, é trazido para a vista', (
      tester,
    ) async {
      await montar(tester, horarios: [
        [horario(9, 26, 10)],
      ]);

      final botao = tester.getRect(dia('26/10'));
      expect(marcado(tester, dia('26/10')), isTrue);
      expect(botao.left, greaterThanOrEqualTo(0));
      expect(botao.right, lessThanOrEqualTo(400));
    });
  });

  group('horários', () {
    testWidgets('divididos em manhã e tarde, na ordem, com o meio-dia já na tarde', (tester) async {
      await montar(tester, horarios: [
        [horario(1, 15, 8), horario(2, 15, 11, minuto: 30), horario(3, 15, 12), horario(4, 15, 14, minuto: 30)],
      ]);

      double y(String texto) => tester.getTopLeft(find.text(texto)).dy;
      expect(y('Manhã'), lessThan(y('08:00')));
      expect(y('11:30'), lessThan(y('Tarde')));
      expect(y('Tarde'), lessThan(y('12:00')));
      expect(y('12:00'), lessThanOrEqualTo(y('14:30')));
      // Na mesma linha, o mais cedo vem antes.
      expect(tester.getTopLeft(find.text('08:00')).dx, lessThan(tester.getTopLeft(find.text('11:30')).dx));
    });

    testWidgets('dia só com horários à tarde não mostra "Manhã" vazia', (tester) async {
      await montar(tester, horarios: [
        [horario(1, 15, 14)],
      ]);

      expect(find.text('Manhã'), findsNothing);
      expect(find.text('Tarde'), findsOneWidget);
    });

    testWidgets('horário das 22:30 fica no dia da clínica, e não no seguinte, que é o dele em UTC', (tester) async {
      await montar(tester, horarios: [
        [horario(1, 15, 22, minuto: 30)],
      ]);

      expect(find.descendant(of: dia('15/10'), matching: find.text('1 horário')), findsOneWidget);
      expect(find.descendant(of: dia('16/10'), matching: find.text('sem horários')), findsOneWidget);
      expect(find.text('22:30'), findsOneWidget);
    });

    testWidgets('antes da escolha, o resumo diz o que fazer', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(find.text(resumoVazio), findsOneWidget);
      expect(find.text('Toque em um horário livre'), findsOneWidget);
      expect(marcado(tester, hora('14:30')), isFalse);
    });

    testWidgets('o horário escolhido leva o ícone, e o resumo diz o dia, a hora, a duração, quem e quanto', (
      tester,
    ) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      await tocar(tester, hora('14:30'));

      expect(marcado(tester, hora('14:30')), isTrue);
      expect(marcado(tester, hora('08:00')), isFalse);
      expect(find.text('Qui, 15/10 · 14:30 · 30 min'), findsOneWidget);
      expect(find.text('Carlos Eduardo Timbó · R\$ 250,00'), findsOneWidget);
      expect(find.text(resumoVazio), findsNothing);
      // É o horário inteiro que fica guardado, com a versão dele.
      expect(montagem.vm.horarioEscolhido?.id, 3);
    });

    testWidgets('escolher outro horário troca a escolha', (tester) async {
      await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      await tocar(tester, hora('08:00'));

      expect(marcado(tester, hora('08:00')), isTrue);
      expect(marcado(tester, hora('14:30')), isFalse);
      expect(find.text('Qui, 15/10 · 08:00 · 30 min'), findsOneWidget);
    });

    testWidgets('trocar de dia desfaz a escolha do horário, que era do outro dia', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      await tocar(tester, dia('16/10'));

      expect(montagem.vm.horarioEscolhido, isNull);
      expect(find.text(resumoVazio), findsOneWidget);
    });

    testWidgets('tocar no dia que já está escolhido não desfaz a escolha do horário', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      await tocar(tester, dia('15/10'));

      expect(montagem.vm.horarioEscolhido?.id, 3);
    });

    testWidgets('o leitor de tela sabe que o horário é botão, e qual está escolhido', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      final escolhido = tester.getSemantics(find.text('14:30')).getSemanticsData();
      final outro = tester.getSemantics(find.text('08:00')).getSemanticsData();
      expect(escolhido.label, '14:30');
      expect(escolhido.flagsCollection.isButton, isTrue);
      expect(escolhido.flagsCollection.isSelected.toBoolOrNull(), isTrue);
      expect(outro.flagsCollection.isSelected.toBoolOrNull(), isFalse);
      // E a escolha é anunciada: o resumo muda sem a pessoa ter ido até ele.
      final resumo = tester.getSemantics(find.text('Qui, 15/10 · 14:30 · 30 min')).getSemanticsData();
      expect(resumo.flagsCollection.isLiveRegion, isTrue);
      semantica.dispose();
    });
  });

  group('ver mais dias', () {
    testWidgets('o botão no fim da faixa pede mais 14 dias de cada vez, e some aos 60', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum, gradeComum, gradeComum, gradeComum, gradeComum]);

      final ate = <String>[];
      final tamanhos = <int>[];
      for (var vez = 0; vez < 4; vez++) {
        await tocar(tester, find.text('Ver mais dias'));
        ate.add(montagem.catalogo.pedidosDeHorarios.last.ate.paraApi());
        tamanhos.add(diasDaFaixa(tester).length);
      }

      // 28, 42 e 56 dias; depois 60, que é o teto da API, e não 70.
      expect(ate, ['2026-11-11', '2026-11-25', '2026-12-09', '2026-12-13']);
      expect(tamanhos, [28, 42, 56, 60]);
      expect(diasDaFaixa(tester).last, '12/12');
      expect(find.text('Ver mais dias'), findsNothing);
    });

    testWidgets('os horários dos dias novos aparecem, e os que já estavam continuam', (tester) async {
      await montar(tester, horarios: [
        gradeComum,
        [...gradeComum, horario(20, 3, 10, mes: 11)],
      ]);

      await tocar(tester, find.text('Ver mais dias'));

      expect(find.descendant(of: dia('03/11'), matching: find.text('1 horário')), findsOneWidget);
      expect(find.descendant(of: dia('15/10'), matching: find.text('3 horários')), findsOneWidget);
    });

    testWidgets('enquanto os dias não chegam, o botão dá lugar ao indicador, e a grade continua na tela', (
      tester,
    ) async {
      final demora = Completer<List<Horario>>();
      await montar(tester, horarios: [gradeComum, demora]);

      await tocar(tester, find.text('Ver mais dias'));

      expect(find.text('Ver mais dias'), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);
      expect(diasDaFaixa(tester), hasLength(14));

      demora.complete(gradeComum);
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(diasDaFaixa(tester), hasLength(28));
    });

    testWidgets('se falhar, a grade fica como estava, um aviso diz por quê, e o botão continua lá', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum, const ErroDaApi.semConexao(), gradeComum]);

      await tocar(tester, find.text('Ver mais dias'));

      expect(find.textContaining('Não foi possível ver mais dias.'), findsOneWidget);
      expect(diasDaFaixa(tester), hasLength(14));
      expect(find.text('14:30'), findsOneWidget);

      // A segunda tentativa pede os mesmos 28 dias, e não 42.
      await tocar(tester, find.text('Ver mais dias'));
      expect(montagem.catalogo.pedidosDeHorarios.last.ate.paraApi(), '2026-11-11');
      expect(find.textContaining('Não foi possível ver mais dias.'), findsNothing);
      expect(diasDaFaixa(tester), hasLength(28));
    });

    testWidgets('o dia e o horário escolhidos continuam escolhidos', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum, gradeComum]);
      await tocar(tester, dia('16/10'));
      await tocar(tester, hora('09:00'));

      await tocar(tester, find.text('Ver mais dias'));

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 16));
      expect(marcado(tester, hora('09:00')), isTrue);
      expect(find.text('Sex, 16/10 · 09:00 · 30 min'), findsOneWidget);
    });
  });

  group('sem horário nenhum', () {
    testWidgets('diz em quantos dias procurou, e oferece ver mais dias', (tester) async {
      final montagem = await montar(tester, horarios: [
        const <Horario>[],
        [horario(20, 3, 10, mes: 11)],
      ]);

      expect(find.text('Sem horários livres'), findsOneWidget);
      expect(find.text('Este profissional não tem horários livres nos próximos 14 dias.'), findsOneWidget);
      // Sem o que escolher, o resumo não manda tocar em horário.
      expect(find.text(resumoVazio), findsNothing);
      // Uma saída só, a do aviso: a faixa não repete o botão.
      expect(find.text('Ver mais dias', skipOffstage: false), findsOneWidget);

      await tocar(tester, find.widgetWithText(OutlinedButton, 'Ver mais dias').last);

      expect(find.text('Sem horários livres'), findsNothing);
      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 11, 3));
      expect(find.text('10:00'), findsOneWidget);
      expect(find.text(resumoVazio), findsOneWidget);
    });

    testWidgets('enquanto os dias a mais não chegam, a tela diz que carrega, e não que não há horário', (
      tester,
    ) async {
      final demora = Completer<List<Horario>>();
      await montar(tester, horarios: [const <Horario>[], demora]);

      await tocar(tester, find.widgetWithText(OutlinedButton, 'Ver mais dias').last);

      expect(find.text('Sem horários livres'), findsNothing);
      expect(find.text('Carregando…'), findsOneWidget);
      demora.complete(const <Horario>[]);
      await tester.pump();
      expect(find.text('Este profissional não tem horários livres nos próximos 28 dias.'), findsOneWidget);
    });

    testWidgets('aos 60 dias, não há mais o que oferecer: o aviso fica sem botão', (tester) async {
      final montagem = await montar(tester, horarios: List.filled(5, const <Horario>[]));
      for (var vez = 0; vez < 4; vez++) {
        await montagem.vm.verMaisDias();
      }
      await tester.pump();

      expect(find.text('Este profissional não tem horários livres nos próximos 60 dias.'), findsOneWidget);
      expect(find.text('Ver mais dias'), findsNothing);
    });
  });

  group('horário que já começou', () {
    // 14:00 de quinta, 15/10, em Quixadá: hoje é o dia 15.
    final duasDaTarde = DateTime.utc(2026, 10, 15, 17);
    const perdeuAs1430 = 'O horário de qui, 15/10 às 14:30 não está mais livre. Escolha outro.';

    testWidgets('não aparece, nem conta no dia', (tester) async {
      await montar(
        tester,
        horarios: [
          [horario(1, 15, 8), horario(2, 15, 13), horario(3, 15, 14, minuto: 30), horario(4, 15, 16)],
        ],
        agora: duasDaTarde,
      );

      expect(find.descendant(of: dia('15/10'), matching: find.text('2 horários')), findsOneWidget);
      expect(find.text('08:00'), findsNothing);
      expect(find.text('13:00'), findsNothing);
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('16:00'), findsOneWidget);
    });

    testWidgets('o escolhido que começa com a tela aberta sai da grade, com aviso, sem precisar atualizar', (
      tester,
    ) async {
      final montagem = await montar(
        tester,
        horarios: [
          [horario(1, 15, 14, minuto: 30), horario(2, 15, 16)],
        ],
        agora: duasDaTarde,
      );
      await tocar(tester, hora('14:30'));
      expect(montagem.vm.horarioEscolhido?.id, 1);

      Montagem.agora = DateTime.utc(2026, 10, 15, 17, 30);
      await tester.pump(const Duration(minutes: 30));
      await tester.pump();

      expect(montagem.vm.horarioEscolhido, isNull);
      expect(find.text('14:30'), findsNothing);
      expect(find.text(perdeuAs1430), findsOneWidget);
      expect(find.text(resumoVazio), findsOneWidget);
      expect(find.descendant(of: dia('15/10'), matching: find.text('1 horário')), findsOneWidget);
      // Uma só ida à API: foi o relógio, e não uma atualização.
      expect(montagem.catalogo.pedidosDeHorarios, hasLength(1));
    });

    testWidgets('o dia que fica sem horário pelo relógio dá lugar ao primeiro dia com horário', (tester) async {
      final montagem = await montar(
        tester,
        horarios: [
          [horario(1, 15, 14, minuto: 30), horario(2, 16, 9)],
        ],
        agora: duasDaTarde,
      );
      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 15));

      Montagem.agora = DateTime.utc(2026, 10, 15, 17, 30);
      await tester.pump(const Duration(minutes: 30));
      await tester.pump();

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 16));
      expect(marcado(tester, dia('16/10')), isTrue);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('tocado depois de começar, antes de o relógio tirá-lo da tela, não é escolhido', (tester) async {
      final montagem = await montar(
        tester,
        horarios: [
          [horario(1, 15, 14, minuto: 30), horario(2, 15, 16)],
        ],
        agora: duasDaTarde,
      );

      // Um minuto depois das 14:30, sem o relógio do teste ter andado.
      Montagem.agora = DateTime.utc(2026, 10, 15, 17, 31);
      await tocar(tester, hora('14:30'));

      expect(montagem.vm.horarioEscolhido, isNull);
      expect(find.text(perdeuAs1430), findsOneWidget);
      expect(find.text('14:30'), findsNothing);
      expect(find.text(resumoVazio), findsOneWidget);
    });

    testWidgets('só se escolhe horário desta grade, e com a versão que veio nela', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);

      montagem.vm.escolherHorario(horario(99, 16, 10));
      await tester.pump();
      expect(montagem.vm.horarioEscolhido, isNull);
      expect(find.text('O horário de sex, 16/10 às 10:00 não está mais livre. Escolha outro.'), findsOneWidget);

      // Mesmo id da grade, com outra versão: vale a da grade, que é a que a API mandou.
      montagem.vm.escolherHorario(horario(3, 15, 14, minuto: 30, versao: 9));
      await tester.pump();
      expect(montagem.vm.horarioEscolhido?.id, 3);
      expect(montagem.vm.horarioEscolhido?.versao, 0);
    });
  });

  group('servidor demorando, com a grade na tela', () {
    testWidgets('atualizar: depois de 4 s, avisa, e a grade continua', (tester) async {
      final segunda = Completer<List<Horario>>();
      await montar(tester, horarios: [gradeComum, segunda]);

      await puxarParaAtualizar(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);
      expect(find.text('14:30'), findsOneWidget);

      segunda.complete(gradeComum);
      await tester.pumpAndSettle();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
    });

    testWidgets('ver mais dias: depois de 4 s, avisa', (tester) async {
      final maisDias = Completer<List<Horario>>();
      await montar(tester, horarios: [gradeComum, maisDias]);

      await tocar(tester, find.text('Ver mais dias'));
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);

      maisDias.complete(gradeComum);
      await tester.pump();
      await tester.pump();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
    });
  });

  group('atualizar', () {
    testWidgets('puxar para baixo pede a grade de novo, com a anterior na tela enquanto a nova chega', (
      tester,
    ) async {
      final segunda = Completer<List<Horario>>();
      final montagem = await montar(tester, horarios: [gradeComum, segunda]);

      await puxarParaAtualizar(tester);

      expect(montagem.catalogo.pedidosDeHorarios, hasLength(2));
      expect(montagem.catalogo.pedidosDeHorarios.last.ate.paraApi(), '2026-10-28');
      expect(find.text('14:30'), findsOneWidget);
      expect(find.text('Carregando…'), findsNothing);

      segunda.complete([...gradeComum, horario(5, 15, 16)]);
      await tester.pumpAndSettle();
      expect(find.text('16:00'), findsOneWidget);
      expect(find.descendant(of: dia('15/10'), matching: find.text('4 horários')), findsOneWidget);
    });

    testWidgets('depois de ver mais dias, atualizar pede os mesmos dias, e não volta a 14', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum, gradeComum, gradeComum]);
      await tocar(tester, find.text('Ver mais dias'));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(montagem.catalogo.pedidosDeHorarios.last.ate.paraApi(), '2026-11-11');
      expect(diasDaFaixa(tester), hasLength(28));
    });

    testWidgets('o horário escolhido que continua livre continua escolhido, com a versão que veio agora', (
      tester,
    ) async {
      final montagem = await montar(tester, horarios: [
        gradeComum,
        [horario(1, 15, 8), horario(3, 15, 14, minuto: 30, versao: 7)],
      ]);
      await tocar(tester, hora('14:30'));
      expect(montagem.vm.horarioEscolhido?.versao, 0);

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(marcado(tester, hora('14:30')), isTrue);
      expect(find.text('Qui, 15/10 · 14:30 · 30 min'), findsOneWidget);
      // É a versão que a Etapa 14 devolve ao agendar.
      expect(montagem.vm.horarioEscolhido?.versao, 7);
      expect(find.textContaining('não está mais livre'), findsNothing);
    });

    testWidgets('o horário escolhido que deixou de estar livre é desfeito, e um aviso diz qual era', (tester) async {
      final montagem = await montar(tester, horarios: [
        gradeComum,
        [horario(1, 15, 8), horario(4, 16, 9)],
      ]);
      await tocar(tester, hora('14:30'));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(montagem.vm.horarioEscolhido, isNull);
      expect(find.text('14:30'), findsNothing);
      expect(find.text('O horário de qui, 15/10 às 14:30 não está mais livre. Escolha outro.'), findsOneWidget);
      expect(find.text(resumoVazio), findsOneWidget);

      // Escolhido outro, o aviso some.
      await tocar(tester, hora('08:00'));
      expect(find.textContaining('não está mais livre'), findsNothing);
    });

    testWidgets('trocar de dia também tira o aviso do horário perdido', (tester) async {
      await montar(tester, horarios: [
        gradeComum,
        [horario(1, 15, 8), horario(4, 16, 9)],
      ]);
      await tocar(tester, hora('14:30'));
      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      await tocar(tester, dia('16/10'));

      expect(find.textContaining('não está mais livre'), findsNothing);
    });

    testWidgets('o dia mostrado que ficou sem horário dá lugar ao primeiro que tem', (tester) async {
      final montagem = await montar(tester, horarios: [
        gradeComum,
        [horario(4, 16, 9)],
      ]);
      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 15));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 16));
      expect(marcado(tester, dia('16/10')), isTrue);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('o dia mostrado que continua com horário continua mostrado, mesmo não sendo o primeiro', (
      tester,
    ) async {
      final montagem = await montar(tester, horarios: [gradeComum, gradeComum]);
      await tocar(tester, dia('16/10'));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 16));
    });

    testWidgets('atualização que falha mantém a grade e diz por quê', (tester) async {
      await montar(tester, horarios: [gradeComum, const ErroDaApi.semConexao()]);

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(find.text('14:30'), findsOneWidget);
      expect(find.textContaining('Não foi possível atualizar.'), findsOneWidget);
    });

    testWidgets('virou o dia com a tela aberta: a grade atualizada começa no hoje de agora', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum, gradeComum]);

      // 00:10 de quinta, 15/10, em Quixadá.
      Montagem.agora = DateTime.utc(2026, 10, 15, 3, 10);
      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(diasDaFaixa(tester).first, '15/10');
      expect(diasDaFaixa(tester).last, '28/10');
      expect(find.descendant(of: dia('15/10'), matching: find.text('Hoje')), findsOneWidget);
      expect(montagem.catalogo.pedidosDeHorarios.last.ate.paraApi(), '2026-10-29');
    });

    testWidgets('na tela de falha, puxar para baixo é tentar de novo', (tester) async {
      await montar(tester, horarios: [const ErroDaApi.semConexao(), gradeComum]);

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(find.text('14:30'), findsOneWidget);
      expect(find.textContaining('Não foi possível'), findsNothing);
    });

    testWidgets('"ver mais dias" que chega depois de uma atualização não bagunça a grade', (tester) async {
      final maisDias = Completer<List<Horario>>();
      await montar(tester, horarios: [gradeComum, maisDias, gradeComum]);
      await tocar(tester, find.text('Ver mais dias'));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();
      maisDias.complete([...gradeComum, horario(20, 3, 10, mes: 11)]);
      // Sem nada animando, um pump só não desenharia o que a resposta mudasse.
      await tester.pumpAndSettle();

      // Vale o último pedido, o de 14 dias: a faixa não fica com dias sem os horários deles,
      // nem presa no indicador de "carregando".
      expect(diasDaFaixa(tester), hasLength(14));
      expect(find.text('Ver mais dias'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('atualização que chega depois de um "ver mais dias" não esconde os dias a mais', (tester) async {
      final atualizacao = Completer<List<Horario>>();
      final comNovembro = [...gradeComum, horario(20, 3, 10, mes: 11)];
      await montar(tester, horarios: [gradeComum, atualizacao, comNovembro]);
      await puxarParaAtualizar(tester);

      await tocar(tester, find.text('Ver mais dias'));
      atualizacao.complete(gradeComum);
      await tester.pumpAndSettle();

      expect(diasDaFaixa(tester), hasLength(28));
      expect(find.descendant(of: dia('03/11'), matching: find.text('1 horário')), findsOneWidget);
    });
  });

  group('primeira carga', () {
    testWidgets('servidor demorando: depois de 4 s, avisa — sem afirmar a causa', (tester) async {
      final demora = Completer<List<Horario>>();
      await montar(tester, horarios: [demora]);

      await tester.pump(const Duration(seconds: 3));
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);

      demora.complete(gradeComum);
      await tester.pump();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('falha mostra a mensagem da API e deixa tentar de novo', (tester) async {
      final montagem = await montar(tester, horarios: [const ErroDaApi.semConexao(), gradeComum]);

      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
      expect(find.text('Escolha o dia'), findsNothing);

      await tocar(tester, find.text('Tentar de novo'));

      expect(montagem.catalogo.pedidosDeHorarios, hasLength(2));
      expect(find.text('14:30'), findsOneWidget);
    });

    testWidgets('defeito do aplicativo não deixa a tela presa carregando, e é relatado', (tester) async {
      await montar(tester, horarios: [StateError('defeito')]);

      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Carregando…'), findsNothing);
      expect(find.text(const ErroDaApi.falhaNoAplicativo().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });

    testWidgets('sair da tela no meio da carga não deixa relógio contando', (tester) async {
      await montar(tester, horarios: [Completer<List<Horario>>()]);

      await tester.pumpWidget(const SizedBox());

      // O teste cai sozinho se o relógio do aviso de demora sobrar contando.
      expect(tester.takeException(), isNull);
    });

    testWidgets('a resposta que chega depois de sair da tela não tem mais a quem avisar', (tester) async {
      final demora = Completer<List<Horario>>();
      await montar(tester, horarios: [demora]);

      await tester.pumpWidget(const SizedBox());
      demora.complete(gradeComum);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });

  group('acessibilidade', () {
    testWidgets('toque, rótulos e contraste, com dia e horário escolhidos', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('toque, rótulos e contraste, sem horário nenhum', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, horarios: [const <Horario>[]]);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('com texto a 200% numa tela estreita, nada estoura, e rolando se chega ao último horário', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, horarios: [gradeComum], tela: const Size(320, 640));
      expect(tester.takeException(), isNull);

      await tocar(tester, hora('14:30'));
      expect(marcado(tester, hora('14:30')), isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com texto a 200%, os dias e os horários crescem junto com o texto', (tester) async {
      await montar(tester, horarios: [gradeComum], tela: const Size(360, 2400));
      final diaNormal = tester.getSize(dia('15/10'));
      final horaNormal = tester.getSize(hora('08:00'));

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pump();

      expect(tester.getSize(dia('15/10')).width, diaNormal.width * 2);
      expect(tester.getSize(hora('08:00')).height, horaNormal.height * 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com o aparelho deitado, nada estoura; o resumo fica à vista, e rolando se chega aos horários', (
      tester,
    ) async {
      await montar(tester, horarios: [gradeComum], tela: const Size(800, 360));
      expect(tester.takeException(), isNull);

      await tocar(tester, hora('14:30'));

      expect(find.text('Qui, 15/10 · 14:30 · 30 min').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('os botões de horário têm 48 dp ou mais de altura, e os de dia, 88', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(tester.getSize(hora('08:00')).height, greaterThanOrEqualTo(48));
      expect(tester.getSize(dia('15/10')).height, greaterThanOrEqualTo(88));
      // Os dias têm todos a mesma altura, o de uma linha e o de duas.
      expect(tester.getSize(dia('14/10')).height, tester.getSize(dia('15/10')).height);
    });
  });

  group('continuar e conflito', () {
    const conflito = ErroDaApi(
      status: 409,
      codigo: 'HORARIO_INDISPONIVEL',
      mensagem: 'Este horário acabou de ser reservado por outro paciente.',
      acao: AcaoSugerida.recarregarHorarios,
    );

    /// A grade depois que outra pessoa reservou as 14:30: entrou um horário às
    /// 15:00, que a grade antiga não tinha.
    final gradeNova = [horario(1, 15, 8), horario(2, 15, 11, minuto: 30), horario(5, 15, 15), horario(4, 16, 9)];

    Finder continuar() => find.text('Continuar');
    Finder confirmar() => find.text('Confirmar e ir para o pagamento');
    Finder naFolha(String texto) => find.descendant(of: find.byType(BottomSheet), matching: find.text(texto));
    const tituloDoConflito = 'Esse horário não está mais livre';

    /// Escolhe as 14:30, abre o resumo e confirma — e a API diz que outra
    /// pessoa chegou antes.
    Future<void> perderAs1430(WidgetTester tester) async {
      await tocar(tester, hora('14:30'));
      await tester.tap(continuar());
      await tester.pumpAndSettle();
      await tester.tap(confirmar());
      await tester.pumpAndSettle();
    }

    testWidgets('a barra diz em que etapa do agendamento se está', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      expect(find.text('Etapa 1 de 3'), findsOneWidget);
    });

    testWidgets('"Continuar" sem horário diz o que falta, e não abre o resumo', (tester) async {
      await montar(tester, horarios: [gradeComum]);

      await tester.tap(continuar());
      await tester.pumpAndSettle();

      expect(find.text('Escolha um horário para continuar.'), findsOneWidget);
      expect(find.text('Resumo da consulta'), findsNothing);
    });

    testWidgets('"Continuar" abre o resumo do horário escolhido; voltar devolve a grade com a escolha', (tester) async {
      final montagem = await montar(tester, horarios: [gradeComum]);
      await tocar(tester, hora('14:30'));

      await tester.tap(continuar());
      await tester.pumpAndSettle();
      expect(find.text('Resumo da consulta'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 14:30'), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Escolher horário'), findsOneWidget);
      expect(marcado(tester, hora('14:30')), isTrue);
      expect(montagem.vm.diaEscolhido, DataCivil.tentar(2026, 10, 15));
      expect(montagem.vm.horarioEscolhido?.id, 3);
      // Voltar não pede a grade de novo.
      expect(montagem.catalogo.pedidosDeHorarios, hasLength(1));
    });

    testWidgets('o resumo agenda o horário da grade, com a versão que veio nela', (tester) async {
      // A recarga que vem depois do conflito volta vazia: o que importa aqui é
      // o pedido.
      final montagem = await montar(
        tester,
        horarios: [
          [horario(3, 15, 14, minuto: 30, versao: 9)],
          <Horario>[],
        ],
        consultas: ConsultasFalso(agendar: [conflito]),
      );

      await perderAs1430(tester);

      expect(montagem.consultas.pedidosDeAgendar, [(horarioId: 3, versao: 9)]);
    });

    testWidgets('conflito: o horário sai da grade na hora, e a folha só aparece com a grade recarregada', (
      tester,
    ) async {
      final recarga = Completer<List<Horario>>();
      final montagem = await montar(
        tester,
        horarios: [gradeComum, recarga],
        consultas: ConsultasFalso(agendar: [conflito]),
      );

      await perderAs1430(tester);

      // De volta à grade, o resumo fechado, a recarga no ar.
      expect(find.text('Resumo da consulta'), findsNothing);
      expect(montagem.catalogo.pedidosDeHorarios, hasLength(2));
      expect(find.text('14:30', skipOffstage: false), findsNothing);
      expect(find.text(tituloDoConflito), findsNothing);

      recarga.complete(gradeNova);
      await tester.pumpAndSettle();

      expect(find.text(tituloDoConflito), findsOneWidget);
      expect(
        find.text('Este horário acabou de ser reservado por outro paciente. A lista de horários já foi atualizada.'),
        findsOneWidget,
      );
      expect(montagem.vm.horarioEscolhido, isNull);
    });

    testWidgets('as sugestões são os horários livres mais próximos, da grade nova, a partir do dia perdido', (
      tester,
    ) async {
      await montar(tester, horarios: [gradeComum, gradeNova], consultas: ConsultasFalso(agendar: [conflito]));

      await perderAs1430(tester);

      expect(find.text('Horários livres mais próximos'), findsOneWidget);
      // Cada uma em duas linhas: a hora, e o dia embaixo.
      for (final hora in ['08:00', '11:30', '15:00', '09:00']) {
        expect(naFolha(hora), findsOneWidget, reason: hora);
      }
      expect(naFolha('Qui, 15/10'), findsNWidgets(3));
      expect(naFolha('Sex, 16/10'), findsOneWidget);
      expect(naFolha('14:30'), findsNothing);
    });

    testWidgets('tocar numa sugestão escolhe o horário e já abre o resumo dele', (tester) async {
      final montagem = await montar(
        tester,
        horarios: [gradeComum, gradeNova],
        consultas: ConsultasFalso(agendar: [conflito]),
      );
      await perderAs1430(tester);

      await tester.tap(naFolha('15:00'));
      await tester.pumpAndSettle();

      expect(find.text(tituloDoConflito), findsNothing);
      expect(find.text('Resumo da consulta'), findsOneWidget);
      expect(find.text('Amanhã, quinta-feira, 15/10 · 15:00'), findsOneWidget);
      expect(montagem.vm.horarioEscolhido?.id, 5);
    });

    testWidgets('"Ver todos os horários" fecha a folha e deixa a grade nova, sem escolha', (tester) async {
      await montar(tester, horarios: [gradeComum, gradeNova], consultas: ConsultasFalso(agendar: [conflito]));
      await perderAs1430(tester);

      await tester.tap(find.text('Ver todos os horários'));
      await tester.pumpAndSettle();

      expect(find.text(tituloDoConflito), findsNothing);
      expect(find.text('Escolher horário'), findsOneWidget);
      expect(find.text(resumoVazio), findsOneWidget);
      expect(find.text('15:00'), findsOneWidget);
    });

    testWidgets('a recarga que falha: o horário perdido não volta, e a folha diz que a lista não foi atualizada', (
      tester,
    ) async {
      await montar(
        tester,
        horarios: [gradeComum, const ErroDaApi.semConexao()],
        consultas: ConsultasFalso(agendar: [conflito]),
      );

      await perderAs1430(tester);

      expect(find.text(tituloDoConflito), findsOneWidget);
      expect(find.text('Este horário acabou de ser reservado por outro paciente.'), findsOneWidget);
      expect(find.textContaining('A lista de horários já foi atualizada'), findsNothing);
      expect(find.textContaining('Não foi possível atualizar a lista de horários.'), findsOneWidget);
      expect(find.text('Horários livres mais próximos'), findsNothing);

      await tester.tap(find.text('Ver todos os horários'));
      await tester.pumpAndSettle();
      expect(find.text('14:30', skipOffstage: false), findsNothing);
      expect(find.textContaining('Não foi possível atualizar.'), findsOneWidget);
      // Quem explicou foi a folha: a grade não repete que o horário se perdeu.
      expect(find.textContaining('não está mais livre. Escolha outro.'), findsNothing);
    });

    testWidgets('as sugestões começam no dia do horário perdido, e são quatro no máximo', (tester) async {
      final montagem = await montar(
        tester,
        horarios: [
          [
            horario(1, 15, 8),
            for (final (id, hora) in [(4, 9), (5, 10), (6, 11), (7, 14), (8, 15)]) horario(id, 16, hora),
          ],
        ],
      );

      expect(
        montagem.vm.proximosLivres(aPartirDe: DataCivil.tentar(2026, 10, 16)!).map((h) => h.id),
        [4, 5, 6, 7],
      );
    });

    testWidgets('o leitor de tela anuncia a escolha, e não o botão', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, horarios: [gradeComum]);

      final anunciado = tester.getSemantics(find.text(resumoVazio));
      expect(anunciado.flagsCollection.isLiveRegion, isTrue);
      expect(anunciado.label, isNot(contains('Continuar')));
      semantica.dispose();
    });

    testWidgets('a 200%, a escolha e o botão ficam um embaixo do outro, só com a escolha', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await montar(tester, horarios: [gradeComum], tela: const Size(411, 1600));
      await tocar(tester, hora('14:30'));

      expect(tester.takeException(), isNull);
      expect(tester.getRect(continuar()).top, greaterThan(tester.getRect(find.textContaining('14:30 ·')).bottom));
      expect(find.textContaining('Carlos Eduardo Timbó ·'), findsNothing);
    });
  });
}
