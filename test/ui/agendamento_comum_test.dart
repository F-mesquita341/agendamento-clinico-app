import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/ui/agendamento/cartao_da_consulta.dart';
import 'package:agendamento_clinico/ui/agendamento/etapa_do_agendamento.dart';
import 'package:agendamento_clinico/ui/agendamento/pagamento_antecipado.dart';
import 'package:agendamento_clinico/ui/comum/nota.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio/agenda.dart';

/// Quarta-feira, 14/10/2026: o horário 1 é amanhã, quinta, às 09:00.
final hoje = DataCivil.naClinica(meioDiaDeQuarta);
final amanha = horario(1, 15, 9);

Future<void> montar(WidgetTester tester, Widget corpo, {double fonte = 1, Size tela = const Size(411, 900)}) async {
  tester.view.physicalSize = tela;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    builder: (contexto, filho) => MediaQuery(
      data: MediaQuery.of(contexto).copyWith(textScaler: TextScaler.linear(fonte)),
      child: filho!,
    ),
    home: Scaffold(body: SingleChildScrollView(padding: const EdgeInsets.all(16), child: corpo)),
  ));
}

void main() {
  group('cartão da consulta', () {
    testWidgets('quem atende, quando, onde e quanto custa, cada linha com o que a explica', (tester) async {
      await montar(tester, CartaoDaConsulta(profissional: timbo, horario: amanha, valorFormatado: 'R\$ 250,00', hoje: hoje));

      for (final texto in [
        'Profissional',
        'Carlos Eduardo Timbó',
        'Cardiologia',
        'Data e horário',
        'Amanhã, quinta-feira, 15/10 · 09:00',
        '30\u00a0minutos',
        'Local',
        'Clínica Exemplo Quixadá',
        'Centro, Quixadá - CE',
        'Valor da consulta',
        'R\$ 250,00',
      ]) {
        expect(find.text(texto), findsOneWidget, reason: texto);
      }
    });

    testWidgets('cada linha é lida de uma vez pelo leitor de tela', (tester) async {
      await montar(tester, CartaoDaConsulta(profissional: timbo, horario: amanha, valorFormatado: 'R\$ 250,00', hoje: hoje));

      expect(find.bySemanticsLabel('Profissional\nCarlos Eduardo Timbó\nCardiologia'), findsOneWidget);
      expect(find.bySemanticsLabel('Local\nClínica Exemplo Quixadá\nCentro, Quixadá - CE'), findsOneWidget);
    });

    testWidgets('sem a clínica, não há linha de local', (tester) async {
      await montar(
        tester,
        CartaoDaConsulta(profissional: timboNa(null), horario: amanha, valorFormatado: 'R\$ 250,00', hoje: hoje),
      );

      expect(find.text('Local'), findsNothing);
      expect(find.text('Valor da consulta'), findsOneWidget);
    });

    testWidgets('em outro ano, a data leva o ano', (tester) async {
      await montar(
        tester,
        CartaoDaConsulta(
          profissional: timbo,
          horario: horario(1, 4, 9, mes: 1, ano: 2027),
          valorFormatado: 'R\$ 250,00',
          hoje: hoje,
        ),
      );

      expect(find.text('Segunda-feira, 04/01/2027 · 09:00'), findsOneWidget);
    });

    testWidgets('a 200%, cabe na tela', (tester) async {
      await montar(
        tester,
        CartaoDaConsulta(profissional: timbo, horario: amanha, valorFormatado: 'R\$ 250,00', hoje: hoje),
        fonte: 2,
        tela: const Size(411, 2000),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('indicador de etapa', () {
    /// A barra numa tela aberta por cima de outra — com o botão de voltar, como
    /// no aplicativo —, ou na primeira tela, sem ele.
    Future<void> barra(WidgetTester tester, {double fonte = 1, bool comVoltar = true}) async {
      tester.view.physicalSize = const Size(411, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Widget tela(BuildContext contexto) => Scaffold(
            appBar: AppBar(title: const Text('Resumo da consulta'), bottom: etapaDoAgendamento(contexto, 2)),
          );
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        builder: (contexto, filho) => MediaQuery(
          data: MediaQuery.of(contexto).copyWith(textScaler: TextScaler.linear(fonte)),
          child: filho!,
        ),
        home: comVoltar
            ? Builder(
                builder: (contexto) => Scaffold(
                  body: TextButton(
                    onPressed: () => Navigator.of(contexto).push(MaterialPageRoute<void>(builder: tela)),
                    child: const Text('Abrir'),
                  ),
                ),
              )
            : Builder(builder: tela),
      ));
      if (comVoltar) {
        await tester.tap(find.text('Abrir'));
        await tester.pumpAndSettle();
      }
    }

    testWidgets('sem o botão de voltar, a etapa também começa onde começa o título', (tester) async {
      await barra(tester, comVoltar: false);

      expect(find.byType(BackButton), findsNothing);
      expect(tester.getRect(find.text('Etapa 2 de 3')).left, tester.getRect(find.text('Resumo da consulta')).left);
    });

    testWidgets('diz a etapa e quantas são, embaixo do título e alinhado com ele', (tester) async {
      await barra(tester);

      expect(find.text('Etapa 2 de 3'), findsOneWidget);
      final titulo = tester.getRect(find.text('Resumo da consulta'));
      final etapa = tester.getRect(find.text('Etapa 2 de 3'));
      expect(etapa.left, titulo.left);
      expect(etapa.top, greaterThanOrEqualTo(titulo.bottom));
    });

    // Se o título cabe, quem confere são as imagens com a fonte de verdade: a
    // fonte dos testes é bem mais larga, e o Flutter limita a escala do título
    // da barra. Aqui, o que o indicador garante: ele não divide a linha com o
    // título, e a barra cresce com ele.
    testWidgets('a 200%, a etapa fica inteira dentro da barra, e não ao lado do título', (tester) async {
      await barra(tester, fonte: 2);

      expect(tester.takeException(), isNull);
      final titulo = tester.getRect(find.text('Resumo da consulta'));
      final etapa = tester.getRect(find.text('Etapa 2 de 3'));
      final barraInteira = tester.getRect(find.byType(AppBar));
      expect(etapa.top, greaterThanOrEqualTo(titulo.bottom));
      expect(etapa.bottom, lessThanOrEqualTo(barraInteira.bottom));
      expect(tester.renderObject<RenderParagraph>(find.text('Etapa 2 de 3')).didExceedMaxLines, isFalse);
    });
  });

  group('pagamento antecipado', () {
    testWidgets('a frase e o caminho para a explicação, sem "caução"', (tester) async {
      await montar(tester, const PagamentoAntecipado());

      expect(find.text('O pagamento antecipado garante o seu horário.'), findsOneWidget);
      expect(find.text('Saiba mais sobre o pagamento antecipado'), findsOneWidget);
    });

    testWidgets('"Saiba mais" explica o porquê, a reserva e o que acontece com o valor, e "Entendi" fecha', (tester) async {
      await montar(tester, const PagamentoAntecipado());

      await tester.tap(find.text('Saiba mais sobre o pagamento antecipado'));
      await tester.pumpAndSettle();

      expect(find.text('Por que o pagamento é antecipado?'), findsOneWidget);
      expect(find.textContaining('reservado para você por 15 minutos'), findsOneWidget);
      expect(find.textContaining('a reserva expira e o horário volta a ficar livre'), findsOneWidget);
      expect(
        find.text('Se você cancelar até o horário da consulta, o valor pago é devolvido integralmente. '
            'Se faltar sem cancelar, o valor não é devolvido.'),
        findsOneWidget,
      );
      expect(find.text('Nesta versão de teste, nenhum valor real é cobrado.'), findsOneWidget);
      expect(find.textContaining(RegExp('cau[çc][ãa]o', caseSensitive: false)), findsNothing);

      await tester.tap(find.text('Entendi'));
      await tester.pumpAndSettle();

      expect(find.text('Por que o pagamento é antecipado?'), findsNothing);
    });

    testWidgets('a explicação rola a 200%, sem estourar', (tester) async {
      await montar(tester, const PagamentoAntecipado(), fonte: 2, tela: const Size(411, 480));

      await tester.tap(find.text('Saiba mais sobre o pagamento antecipado'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Rolando com o dedo — e não por código, que rolaria mesmo sem a pessoa
      // conseguir.
      expect(find.text('Entendi').hitTestable(), findsNothing);
      await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(find.text('Entendi').hitTestable(), findsOneWidget);
    });
  });

  group('nota', () {
    testWidgets('mostra o texto e não é anunciada ao aparecer, como um aviso seria', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, const Nota(icone: Icons.lock_clock, texto: 'O horário fica reservado.'));

      expect(find.text('O horário fica reservado.'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('O horário fica reservado.')).flagsCollection.isLiveRegion,
        isFalse,
      );
      semantica.dispose();
    });
  });
}
