import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/pagina.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/busca/busca_screen.dart';
import 'package:agendamento_clinico/ui/busca/busca_view_model.dart';
import 'package:agendamento_clinico/ui/comum/card_do_profissional.dart';
import 'package:agendamento_clinico/ui/comum/chip_de_escolha.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/falsos.dart';

const cardiologia = Especialidade(id: 2, nome: 'Cardiologia');
const ginecologia = Especialidade(id: 4, nome: 'Ginecologia');
const pediatria = Especialidade(id: 6, nome: 'Pediatria');
const especialidades = [cardiologia, ginecologia, pediatria];

const timbo = Profissional(
  id: 2,
  nome: 'Carlos Eduardo Timbó',
  registroConselho: 'CRM-CE 12345',
  valorFormatado: 'R\$ 250,00',
  especialidade: cardiologia,
);
const ana = Profissional(
  id: 5,
  nome: 'Ana Beatriz Lopes',
  registroConselho: 'CRM-CE 54321',
  valorFormatado: 'R\$ 180,00',
  especialidade: pediatria,
);
const antonio = Profissional(
  id: 7,
  nome: 'Antônio Sales',
  registroConselho: 'CRM-CE 11111',
  valorFormatado: 'R\$ 200,00',
  especialidade: cardiologia,
);

const mensagemDeDemora = 'O servidor está demorando para responder.';
const dicaDoCampo = 'Nome do profissional ou especialidade';

/// Monta a tela com o catálogo dado e espera a primeira resposta. Devolve os
/// profissionais em que a pessoa tocou.
Future<List<Profissional>> montar(WidgetTester tester, CatalogoFalso catalogo) async {
  final abertos = <Profissional>[];
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: ChangeNotifierProvider(
      create: (_) => BuscaViewModel(catalogo)..carregar(),
      child: BuscaScreen(aoAbrir: abertos.add),
    ),
  ));
  await tester.pump();
  return abertos;
}

/// Digita no campo de busca, sem esperar o prazo de quem parou de digitar.
Future<void> digitar(WidgetTester tester, String texto) async {
  await tester.enterText(find.byType(TextField), texto);
  await tester.pump();
}

/// Digita e espera os 300 ms sem tecla que disparam a busca.
Future<void> buscarPor(WidgetTester tester, String texto) async {
  await digitar(tester, texto);
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> tocarNoChip(WidgetTester tester, String rotulo) async {
  // A linha de chips rola para o lado: o chip pode estar fora da tela. Só
  // ela rola aqui — a lista, não —, como quando o dedo a arrasta.
  final linha = tester.state<ScrollableState>(find.descendant(
    of: find.byWidgetPredicate((w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal),
    matching: find.byType(Scrollable),
  ));
  await linha.position.ensureVisible(tester.renderObject(find.widgetWithText(ChipDeEscolha, rotulo)));
  await tester.pump();
  await tester.tap(find.widgetWithText(ChipDeEscolha, rotulo));
  await tester.pump();
  await tester.pump();
}

bool chipEscolhido(WidgetTester tester, String rotulo) =>
    tester.widget<ChipDeEscolha>(find.widgetWithText(ChipDeEscolha, rotulo)).escolhido;

String textoDoCampo(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).controller!.text;

/// Puxa a lista para baixo, como o dedo faria, até disparar a atualização.
Future<void> puxarParaAtualizar(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Rola até o que se procura: a lista só constrói o que está perto da tela.
Future<void> rolarAte(WidgetTester tester, Finder alvo) =>
    tester.scrollUntilVisible(alvo, 200, scrollable: find.byType(Scrollable).first);

void main() {
  group('primeira carga', () {
    testWidgets('mostra as especialidades para escolher e os profissionais, com o valor', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
      ]);
      await montar(tester, catalogo);

      for (final chip in ['Todas', 'Cardiologia', 'Ginecologia', 'Pediatria']) {
        expect(find.widgetWithText(ChipDeEscolha, chip), findsOneWidget, reason: chip);
      }
      expect(chipEscolhido(tester, 'Todas'), isTrue);
      expect(find.widgetWithText(CardDoProfissional, 'Ana Beatriz Lopes'), findsOneWidget);
      expect(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Consulta R\$\u00a0250,00', findRichText: true), findsOneWidget);
      expect(find.text('2 profissionais'), findsOneWidget);
      // Sem filtro nenhum: a primeira página de todos.
      expect(catalogo.pedidosDeProfissionais, [(especialidadeId: null, termo: null, pagina: 1)]);
    });

    testWidgets('um profissional só: a contagem no singular', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]));

      expect(find.text('1 profissional'), findsOneWidget);
    });

    testWidgets('servidor demorando: depois de 4 s, avisa — sem afirmar a causa', (tester) async {
      final demora = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [demora]));

      await tester.pump(const Duration(seconds: 3));
      expect(find.text('Carregando…'), findsOneWidget);
      expect(find.textContaining(mensagemDeDemora), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);
      expect(find.textContaining('Acordando'), findsNothing);

      demora.complete(paginaDe([timbo]));
      await tester.pump();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('falha mostra a mensagem da API e deixa tentar de novo', (tester) async {
      final catalogo = CatalogoFalso(
        especialidades: [const ErroDaApi.semConexao(), especialidades],
        profissionais: [paginaDe([timbo])],
      );
      await montar(tester, catalogo);

      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
      // Sem as especialidades não há chips, mas o campo de busca já está lá.
      expect(find.byType(ChipDeEscolha), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.widgetWithText(ChipDeEscolha, 'Cardiologia'), findsOneWidget);
    });

    testWidgets('com as especialidades em mãos, tentar de novo não as pede outra vez', (tester) async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        profissionais: [const ErroDaApi.semConexao(), paginaDe([timbo])],
      );
      await montar(tester, catalogo);

      // Os chips já aparecem, com a falha no lugar da lista.
      expect(find.widgetWithText(ChipDeEscolha, 'Cardiologia'), findsOneWidget);
      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(catalogo.respostasDeEspecialidades.chamadas, 1);
    });

    testWidgets('defeito do aplicativo não deixa a tela presa carregando, e é relatado', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [StateError('defeito')]));

      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Carregando…'), findsNothing);
      expect(find.text(const ErroDaApi.falhaNoAplicativo().mensagem), findsOneWidget);
      expect(find.text('Tentar de novo'), findsOneWidget);
    });
  });

  group('especialidade', () {
    testWidgets('tocar num chip busca os profissionais dela, e o chip fica escolhido', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
      ]);
      await montar(tester, catalogo);

      await tocarNoChip(tester, 'Cardiologia');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: null, pagina: 1));
      expect(chipEscolhido(tester, 'Cardiologia'), isTrue);
      expect(chipEscolhido(tester, 'Todas'), isFalse);
      expect(find.text('Ana Beatriz Lopes'), findsNothing);
      expect(find.text('1 profissional'), findsOneWidget);
    });

    testWidgets('enquanto a busca nova não chega, a lista antiga sai e a tela diz que carrega', (tester) async {
      final demora = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        demora,
      ]));

      await tocarNoChip(tester, 'Cardiologia');

      // A pediatra não fica na tela debaixo do chip de Cardiologia.
      expect(find.text('Ana Beatriz Lopes'), findsNothing);
      expect(find.text('Carregando…'), findsOneWidget);
      // Os filtros continuam à mão durante a espera.
      expect(find.widgetWithText(ChipDeEscolha, 'Pediatria'), findsOneWidget);
      demora.complete(paginaDe([timbo]));
      await tester.pump();
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('tocar no chip que já está escolhido não busca de novo', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]);
      await montar(tester, catalogo);

      await tocarNoChip(tester, 'Todas');

      expect(catalogo.pedidosDeProfissionais, hasLength(1));
    });

    testWidgets('"Todas" tira o filtro de especialidade', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
        paginaDe([ana, timbo]),
      ]);
      await montar(tester, catalogo);
      await tocarNoChip(tester, 'Cardiologia');

      await tocarNoChip(tester, 'Todas');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: null, termo: null, pagina: 1));
      expect(find.text('2 profissionais'), findsOneWidget);
    });
  });

  group('texto', () {
    testWidgets('com uma letra só, a dica e nenhum pedido', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([ana, timbo])]);
      await montar(tester, catalogo);

      await buscarPor(tester, 'a');

      expect(find.text('Busque por ao menos duas letras.'), findsOneWidget);
      expect(catalogo.pedidosDeProfissionais, hasLength(1));
      // A lista que estava na tela continua.
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('com duas letras, busca no nome, e a dica some', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([ana]),
      ]);
      await montar(tester, catalogo);

      await buscarPor(tester, 'an');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: null, termo: 'an', pagina: 1));
      expect(find.text('Busque por ao menos duas letras.'), findsNothing);
      expect(find.text('Carlos Eduardo Timbó'), findsNothing);
      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);
    });

    testWidgets('a busca espera 300 ms sem tecla: digitar "ana" faz um pedido, não três', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([ana]),
      ]);
      await montar(tester, catalogo);

      await digitar(tester, 'a');
      await tester.pump(const Duration(milliseconds: 100));
      await digitar(tester, 'an');
      await tester.pump(const Duration(milliseconds: 100));
      await digitar(tester, 'ana');
      // 299 ms depois da última tecla, ainda nada.
      await tester.pump(const Duration(milliseconds: 299));
      expect(catalogo.pedidosDeProfissionais, hasLength(1));

      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();

      expect(catalogo.pedidosDeProfissionais, hasLength(2));
      expect(catalogo.pedidosDeProfissionais.last.termo, 'ana');
    });

    testWidgets('espaços em volta não contam como letra, nem vão para a API', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([ana]),
      ]);
      await montar(tester, catalogo);

      await buscarPor(tester, ' a ');
      expect(find.text('Busque por ao menos duas letras.'), findsOneWidget);
      expect(catalogo.pedidosDeProfissionais, hasLength(1));

      await buscarPor(tester, '  ana ');
      expect(catalogo.pedidosDeProfissionais.last.termo, 'ana');

      // Um espaço a mais depois não muda a busca: nenhum pedido novo.
      await buscarPor(tester, '  ana  ');
      expect(catalogo.pedidosDeProfissionais, hasLength(2));
    });

    testWidgets('apagar o texto volta à lista sem filtro de nome', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([ana]),
        paginaDe([ana, timbo]),
      ]);
      await montar(tester, catalogo);
      await buscarPor(tester, 'ana');

      await buscarPor(tester, 'a');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: null, termo: null, pagina: 1));
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('o botão de limpar o texto só aparece com texto, e limpa o campo e a busca', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([ana]),
        paginaDe([ana, timbo]),
      ]);
      await montar(tester, catalogo);
      expect(find.byTooltip('Limpar o texto da busca'), findsNothing);
      await buscarPor(tester, 'ana');

      await tester.tap(find.byTooltip('Limpar o texto da busca'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump();

      expect(textoDoCampo(tester), '');
      expect(find.byTooltip('Limpar o texto da busca'), findsNothing);
      expect(catalogo.pedidosDeProfissionais.last.termo, isNull);
    });

    testWidgets('resposta de uma busca antiga, chegando depois, não cobre a nova', (tester) async {
      final an = Completer<Pagina<Profissional>>();
      final anaSo = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        an,
        anaSo,
      ]));
      await buscarPor(tester, 'an');
      await buscarPor(tester, 'ana');

      // A busca nova responde primeiro; a antiga, depois.
      anaSo.complete(paginaDe([ana]));
      await tester.pump();
      an.complete(paginaDe([ana, antonio]));
      // Dois pumps: sem nada animando, o primeiro só entregaria a resposta, e
      // o que ela mudasse ficaria para o quadro seguinte.
      await tester.pump();
      await tester.pump();

      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);
      expect(find.text('Antônio Sales'), findsNothing);
      expect(find.text('1 profissional'), findsOneWidget);
    });

    testWidgets('resposta de uma busca antiga, chegando antes, não aparece: a tela espera a nova', (tester) async {
      final an = Completer<Pagina<Profissional>>();
      final anaSo = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        an,
        anaSo,
      ]));
      await buscarPor(tester, 'an');
      await buscarPor(tester, 'ana');

      an.complete(paginaDe([ana, antonio]));
      await tester.pump();

      expect(find.text('Antônio Sales'), findsNothing);
      expect(find.text('Carregando…'), findsOneWidget);

      anaSo.complete(paginaDe([ana]));
      await tester.pump();
      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);
    });
  });

  group('especialidade e texto juntos', () {
    testWidgets('o texto digitado depois vai com a especialidade escolhida', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        paginaDe([antonio, timbo]),
        paginaDe([antonio]),
      ]);
      await montar(tester, catalogo);
      await tocarNoChip(tester, 'Cardiologia');

      await buscarPor(tester, 'an');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: 'an', pagina: 1));
    });

    testWidgets('a especialidade escolhida depois vai com o texto digitado', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        paginaDe([ana, antonio]),
        paginaDe([antonio]),
      ]);
      await montar(tester, catalogo);
      await buscarPor(tester, 'an');

      await tocarNoChip(tester, 'Cardiologia');

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: 'an', pagina: 1));
    });

    testWidgets('chip tocado com o texto ainda esperando o prazo: busca já, com os dois, uma vez só', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        paginaDe([antonio]),
      ]);
      await montar(tester, catalogo);

      await digitar(tester, 'an');
      await tocarNoChip(tester, 'Cardiologia');
      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: 'an', pagina: 1));

      // O prazo do texto vence, e não dispara uma segunda busca igual.
      await tester.pump(const Duration(milliseconds: 300));
      expect(catalogo.pedidosDeProfissionais, hasLength(2));
    });
  });

  group('limpar filtros', () {
    testWidgets('sem filtro, o botão não aparece', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]));

      expect(find.text('Limpar filtros'), findsNothing);
    });

    testWidgets('aparece com a especialidade escolhida, e com texto no campo — mesmo uma letra só', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
        paginaDe([ana, timbo]),
      ]));

      await digitar(tester, 'a');
      expect(find.text('Limpar filtros'), findsOneWidget);
      await digitar(tester, '');
      expect(find.text('Limpar filtros'), findsNothing);

      await tocarNoChip(tester, 'Cardiologia');
      expect(find.text('Limpar filtros'), findsOneWidget);
    });

    testWidgets('limpa os dois: o campo fica vazio, "Todas" volta, e a busca é sem filtro', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        paginaDe([antonio, timbo]),
        paginaDe([antonio]),
        paginaDe([ana, antonio, timbo]),
      ]);
      await montar(tester, catalogo);
      await tocarNoChip(tester, 'Cardiologia');
      await buscarPor(tester, 'an');

      await tester.tap(find.text('Limpar filtros'));
      await tester.pump();
      await tester.pump();

      expect(textoDoCampo(tester), '');
      expect(chipEscolhido(tester, 'Todas'), isTrue);
      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: null, termo: null, pagina: 1));
      expect(find.text('Limpar filtros'), findsNothing);
      expect(find.text('3 profissionais'), findsOneWidget);
    });

    testWidgets('continua à mão enquanto a busca carrega e quando ela falha', (tester) async {
      final demora = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        demora,
      ]));

      await tocarNoChip(tester, 'Cardiologia');
      expect(find.text('Carregando…'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);

      demora.completeError(const ErroDaApi.semConexao());
      await tester.pump();
      expect(find.text('Tentar de novo'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsOneWidget);
    });
  });

  group('sugestão de especialidade', () {
    testWidgets('"coracao" não é nome de ninguém, mas leva a Cardiologia', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([]),
        paginaDe([timbo]),
      ]);
      await montar(tester, catalogo);

      await buscarPor(tester, 'coracao');
      expect(find.text('Ver profissionais de Cardiologia'), findsOneWidget);

      await tester.tap(find.text('Ver profissionais de Cardiologia'));
      await tester.pump();
      await tester.pump();

      // O texto dá lugar à especialidade: senão a busca seria por cardiologistas chamados "coracao".
      expect(textoDoCampo(tester), '');
      expect(chipEscolhido(tester, 'Cardiologia'), isTrue);
      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: null, pagina: 1));
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Ver profissionais de Cardiologia'), findsNothing);
    });

    testWidgets('a sugestão acompanha a busca, e não cada tecla', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
      ]));

      // "ca" começa "Cardiologia", mas a pessoa ainda está digitando "carlos".
      await digitar(tester, 'ca');
      expect(find.textContaining('Ver profissionais de'), findsNothing);
      await buscarPor(tester, 'carlos');
      expect(find.textContaining('Ver profissionais de'), findsNothing);
    });

    testWidgets('não sugere a especialidade que já está escolhida', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
        paginaDe([]),
      ]));
      await tocarNoChip(tester, 'Cardiologia');

      await buscarPor(tester, 'cardio');

      expect(find.textContaining('Ver profissionais de'), findsNothing);
    });
  });

  group('lista vazia', () {
    testWidgets('especialidade sem profissional: diz qual, e oferece limpar os filtros', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([]),
        paginaDe([ana, timbo]),
      ]);
      await montar(tester, catalogo);

      await tocarNoChip(tester, 'Ginecologia');

      expect(find.text('Nenhum profissional encontrado'), findsOneWidget);
      expect(find.text('Ainda não há profissionais de Ginecologia no aplicativo.'), findsOneWidget);
      // Uma saída só, a do próprio aviso.
      expect(find.text('Limpar filtros'), findsOneWidget);

      await tester.tap(find.widgetWithText(OutlinedButton, 'Limpar filtros'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Nenhum profissional encontrado'), findsNothing);
      expect(find.text('2 profissionais'), findsOneWidget);
      expect(chipEscolhido(tester, 'Todas'), isTrue);
    });

    testWidgets('nome que ninguém tem: diz o que foi buscado', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([]),
      ]));

      await buscarPor(tester, 'zz');

      expect(find.text('Nenhum profissional com "zz" no nome. Confira o nome digitado.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Limpar filtros'), findsOneWidget);
    });

    testWidgets('nome que ninguém tem na especialidade escolhida: diz os dois', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
        paginaDe([]),
      ]));
      await tocarNoChip(tester, 'Cardiologia');

      await buscarPor(tester, 'zz');

      expect(
        find.text(
          'Nenhum profissional de Cardiologia com "zz" no nome. '
          'Confira o nome digitado ou escolha outra especialidade.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('nenhum profissional no aplicativo, sem filtro: diz isso, sem botão de limpar', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([])]));

      expect(find.text('Ainda não há profissionais no aplicativo.'), findsOneWidget);
      expect(find.text('Limpar filtros'), findsNothing);
      expect(find.textContaining('profissionais'), findsOneWidget);
    });
  });

  group('mostrar mais', () {
    testWidgets('com mais páginas, o botão acrescenta a seguinte, e some na última', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio], paginas: 2, total: 3),
        paginaDe([timbo], pagina: 2, paginas: 2, total: 3),
      ]);
      await montar(tester, catalogo);
      // A contagem é a da busca inteira, e não a da página.
      expect(find.text('3 profissionais'), findsOneWidget);

      await rolarAte(tester, find.text('Mostrar mais profissionais'));
      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();
      await tester.pump();

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: null, termo: null, pagina: 2));
      await rolarAte(tester, find.text('Carlos Eduardo Timbó'));
      // A página nova entra depois das que já estavam, sem tirá-las.
      final nomes = tester.widgetList<CardDoProfissional>(find.byType(CardDoProfissional, skipOffstage: false));
      expect(nomes.map((card) => card.profissional.nome), containsAllInOrder(['Antônio Sales', 'Carlos Eduardo Timbó']));
      expect(find.text('Mostrar mais profissionais', skipOffstage: false), findsNothing);
    });

    testWidgets('numa página só, o botão não aparece', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([ana, timbo])]));

      expect(find.text('Mostrar mais profissionais', skipOffstage: false), findsNothing);
    });

    testWidgets('a página seguinte leva os filtros da busca', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo]),
        paginaDe([antonio, timbo]),
        paginaDe([antonio], paginas: 2, total: 2),
        paginaDe([timbo], pagina: 2, paginas: 2, total: 2),
      ]);
      await montar(tester, catalogo);
      await tocarNoChip(tester, 'Cardiologia');
      await buscarPor(tester, 'an');

      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: 'an', pagina: 2));
    });

    testWidgets('enquanto a página não chega, o botão dá lugar ao indicador: não há segundo toque', (tester) async {
      final demora = Completer<Pagina<Profissional>>();
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        demora,
      ]);
      await montar(tester, catalogo);

      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();

      expect(find.text('Mostrar mais profissionais'), findsNothing);
      expect(find.text('Carregando…'), findsOneWidget);
      // A lista continua na tela.
      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);

      demora.complete(paginaDe([timbo], pagina: 2, paginas: 2, total: 2));
      await tester.pump();
      expect(find.text('Carregando…'), findsNothing);
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('atualizar a lista tira o aviso de que a página seguinte falhou', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        const ErroDaApi.semConexao(),
        paginaDe([ana], paginas: 2, total: 2),
      ]));
      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Não foi possível mostrar mais.'), findsOneWidget);

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(find.textContaining('Não foi possível mostrar mais.'), findsNothing);
      expect(find.text('Mostrar mais profissionais'), findsOneWidget);
    });

    testWidgets('falha na página seguinte: a lista fica, um aviso diz por quê, e o botão continua lá', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        const ErroDaApi.semConexao(),
        paginaDe([timbo], pagina: 2, paginas: 2, total: 2),
      ]);
      await montar(tester, catalogo);

      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);
      expect(find.textContaining('Não foi possível mostrar mais.'), findsOneWidget);

      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();
      await tester.pump();

      expect(catalogo.pedidosDeProfissionais.last.pagina, 2);
      expect(find.textContaining('Não foi possível mostrar mais.'), findsNothing);
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
    });

    testWidgets('filtro trocado enquanto a página carrega: ela não entra na lista nova', (tester) async {
      final pagina2 = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        pagina2,
        paginaDe([timbo]),
      ]));
      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();

      await tocarNoChip(tester, 'Cardiologia');
      pagina2.complete(paginaDe([antonio], pagina: 2, paginas: 2, total: 2));
      await tester.pump();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Antônio Sales'), findsNothing);
      expect(find.text('1 profissional'), findsOneWidget);
    });
  });

  group('servidor demorando, com a lista na tela', () {
    testWidgets('atualizar: depois de 4 s, avisa no topo, e a lista continua', (tester) async {
      final segunda = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([timbo]),
        segunda,
      ]));

      await puxarParaAtualizar(tester);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      await tester.pump(const Duration(seconds: 2));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);

      segunda.complete(paginaDe([timbo]));
      await tester.pumpAndSettle();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
    });

    testWidgets('mostrar mais: avisa no fim da lista, onde a pessoa está, e o topo não repete', (tester) async {
      final pagina2 = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        pagina2,
      ]));

      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining(mensagemDeDemora), findsOneWidget);
      expect(
        tester.getTopLeft(find.textContaining(mensagemDeDemora)).dy,
        greaterThan(tester.getTopLeft(find.text('Ana Beatriz Lopes')).dy),
      );

      pagina2.complete(paginaDe([timbo], pagina: 2, paginas: 2, total: 2));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining(mensagemDeDemora), findsNothing);
    });

    testWidgets('atualizar com "mostrar mais" no ar: a página antiga não entra na lista nova, e o aviso some com a '
        'atualização', (tester) async {
      final pagina2 = Completer<Pagina<Profissional>>();
      final atualizacao = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        pagina2,
        atualizacao,
      ]));
      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pump();
      await puxarParaAtualizar(tester);
      await tester.pump(const Duration(seconds: 4));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);

      atualizacao.complete(paginaDe([ana], paginas: 2, total: 2));
      await tester.pump();
      await tester.pump();
      // A página seguinte da lista antiga ainda está no ar, mas não conta mais.
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      expect(find.text('Mostrar mais profissionais'), findsOneWidget);

      pagina2.complete(paginaDe([timbo], pagina: 2, paginas: 2, total: 2));
      await tester.pumpAndSettle();
      expect(find.text(timbo.nome), findsNothing);
      expect(find.text('Mostrar mais profissionais'), findsOneWidget);
    });

    testWidgets('durante a atualização, "mostrar mais" some e não pede nada', (tester) async {
      final atualizacao = Completer<Pagina<Profissional>>();
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        atualizacao,
        paginaDe([timbo], pagina: 2, paginas: 2, total: 2),
      ]);
      await montar(tester, catalogo);
      await puxarParaAtualizar(tester);

      expect(find.text('Mostrar mais profissionais'), findsNothing);
      await tester.element(find.byType(BuscaScreen)).read<BuscaViewModel>().mostrarMais();
      expect(catalogo.pedidosDeProfissionais.map((p) => p.pagina), [1, 1]);

      atualizacao.complete(paginaDe([ana], paginas: 2, total: 2));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mostrar mais profissionais'));
      await tester.pumpAndSettle();
      expect(catalogo.pedidosDeProfissionais.map((p) => p.pagina), [1, 1, 2]);
      expect(find.text(timbo.nome), findsOneWidget);
    });

    testWidgets('busca nova: a resposta que vai ser descartada não deixa o aviso na tela', (tester) async {
      final primeira = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        primeira,
        paginaDe([timbo]),
      ]));
      await tester.pump(const Duration(seconds: 5));
      expect(find.textContaining(mensagemDeDemora), findsOneWidget);

      await tocarNoChip(tester, 'Cardiologia');

      // A busca nova respondeu; a primeira ainda está no ar, mas não importa mais.
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.textContaining(mensagemDeDemora), findsNothing);
      primeira.complete(paginaDe([ana]));
      await tester.pump();
    });
  });

  group('mostrar mais, no view model', () {
    // A tela esconde o botão enquanto a página carrega; estes testes chamam o
    // view model direto, sem a tela, para a trava não depender dela.
    test('chamado duas vezes seguidas, pede a página seguinte uma vez só', () async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        paginaDe([timbo], pagina: 2, paginas: 2, total: 2),
      ]);
      final vm = BuscaViewModel(catalogo);
      addTearDown(vm.dispose);
      await vm.carregar();

      await Future.wait([vm.mostrarMais(), vm.mostrarMais()]);

      expect(catalogo.pedidosDeProfissionais.map((pedido) => pedido.pagina), [1, 2]);
      expect(vm.profissionais, [ana, timbo]);
    });

    test('durante uma busca nova, não pede a página seguinte da lista que está saindo', () async {
      final novaBusca = Completer<Pagina<Profissional>>();
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana], paginas: 2, total: 2),
        novaBusca,
      ]);
      final vm = BuscaViewModel(catalogo);
      addTearDown(vm.dispose);
      await vm.carregar();
      vm.escolherEspecialidade(2);

      await vm.mostrarMais();

      expect(catalogo.pedidosDeProfissionais.map((pedido) => pedido.pagina), [1, 1]);
      novaBusca.complete(paginaDe([timbo]));
    });

    test('na última página, não pede nada', () async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([ana])]);
      final vm = BuscaViewModel(catalogo);
      addTearDown(vm.dispose);
      await vm.carregar();

      await vm.mostrarMais();

      expect(catalogo.pedidosDeProfissionais, hasLength(1));
    });
  });

  group('atualizar', () {
    testWidgets('puxar para baixo pede de novo, com a lista na tela enquanto a nova chega', (tester) async {
      final segunda = Completer<Pagina<Profissional>>();
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo]), segunda]);
      await montar(tester, catalogo);

      await puxarParaAtualizar(tester);

      expect(catalogo.pedidosDeProfissionais, hasLength(2));
      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Carregando…'), findsNothing);

      segunda.complete(paginaDe([ana, timbo]));
      await tester.pumpAndSettle();
      expect(find.text('Ana Beatriz Lopes'), findsOneWidget);
      expect(find.text('2 profissionais'), findsOneWidget);
    });

    testWidgets('atualizar leva os filtros da busca', (tester) async {
      final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo]),
        paginaDe([timbo]),
      ]);
      await montar(tester, catalogo);
      await tocarNoChip(tester, 'Cardiologia');

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(catalogo.pedidosDeProfissionais.last, (especialidadeId: 2, termo: null, pagina: 1));
    });

    testWidgets('atualização que falha mantém a lista e diz por quê', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([timbo]),
        const ErroDaApi.semConexao(),
      ]));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.textContaining('Não foi possível atualizar.'), findsOneWidget);
    });

    testWidgets('filtro trocado enquanto a atualização carrega: ela não cobre a lista nova', (tester) async {
      final atualizacao = Completer<Pagina<Profissional>>();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        atualizacao,
        paginaDe([timbo]),
      ]));
      await puxarParaAtualizar(tester);

      await tocarNoChip(tester, 'Cardiologia');
      atualizacao.complete(paginaDe([ana, antonio, timbo]));
      await tester.pumpAndSettle();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.text('Ana Beatriz Lopes'), findsNothing);
      expect(find.text('1 profissional'), findsOneWidget);
    });

    testWidgets('na tela de falha, puxar para baixo é tentar de novo', (tester) async {
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        const ErroDaApi.semConexao(),
        paginaDe([timbo]),
      ]));

      await puxarParaAtualizar(tester);
      await tester.pumpAndSettle();

      expect(find.text('Carlos Eduardo Timbó'), findsOneWidget);
      expect(find.textContaining('Não foi possível'), findsNothing);
    });
  });

  testWidgets('sair da tela no meio de uma busca não deixa pedido nem relógio para trás', (tester) async {
    final demora = Completer<Pagina<Profissional>>();
    final catalogo = CatalogoFalso(especialidades: [especialidades], profissionais: [
      paginaDe([ana, timbo]),
      demora,
    ]);
    await montar(tester, catalogo);
    // Uma busca no ar, com o aviso de demora contando, e outra esperando o prazo do texto.
    await buscarPor(tester, 'an');
    await digitar(tester, 'ana');

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 300));

    // A busca que esperava o prazo não é feita. E o relógio do aviso de demora
    // parou: o teste cai sozinho se sobrar um contando no fim.
    expect(catalogo.pedidosDeProfissionais, hasLength(2));
  });

  testWidgets('a resposta que chega depois de sair da tela não tem mais a quem avisar', (tester) async {
    final demora = Completer<Pagina<Profissional>>();
    await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
      paginaDe([ana, timbo]),
      demora,
    ]));
    await tocarNoChip(tester, 'Cardiologia');

    await tester.pumpWidget(const SizedBox());
    demora.complete(paginaDe([timbo]));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('tocar num profissional avisa qual foi', (tester) async {
    final abertos = await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
      paginaDe([ana, timbo]),
    ]));

    await tester.tap(find.text('Carlos Eduardo Timbó'));

    expect(abertos, [timbo]);
  });

  group('acessibilidade', () {
    testWidgets('toque, rótulos e contraste, com filtro ativo e lista na tela', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo], paginas: 2, total: 2),
        paginaDe([timbo], paginas: 2, total: 2),
      ]));
      await tocarNoChip(tester, 'Cardiologia');
      await buscarPor(tester, 'cardio');

      // O campo, os chips, a sugestão, limpar filtros, o card e mostrar mais.
      expect(find.text('Limpar filtros'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('toque, rótulos e contraste, na lista vazia e com a dica de duas letras', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([])]));
      await digitar(tester, 'c');

      expect(find.text('Busque por ao menos duas letras.'), findsOneWidget);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('o leitor de tela é avisado do resultado da busca: quantos achou, ou que não achou', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([]),
      ]));
      bool anunciado(String texto) =>
          tester.getSemantics(find.text(texto)).getSemanticsData().flagsCollection.isLiveRegion;

      expect(anunciado('2 profissionais'), isTrue);

      await buscarPor(tester, 'zz');
      expect(anunciado('Nenhum profissional encontrado'), isTrue);
      semantica.dispose();
    });

    testWidgets('o grupo de chips diz ao leitor de tela para que serve', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]));

      expect(find.bySemanticsLabel('Filtrar por especialidade'), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('o campo tem nome para o leitor de tela, com a dica e também depois que ela some', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]));

      var campo = tester.getSemantics(find.byType(TextField)).getSemanticsData();
      expect(campo.flagsCollection.isTextField, isTrue);
      expect(campo.label, 'Buscar\n$dicaDoCampo');

      await digitar(tester, 'c');
      // A dica leva um instante para sumir.
      await tester.pump(const Duration(milliseconds: 300));
      campo = tester.getSemantics(find.byType(TextField)).getSemanticsData();
      expect(campo.label.trim(), 'Buscar');
      expect(campo.value, 'c');
      semantica.dispose();
    });

    testWidgets('com texto a 200%, a dica do campo quebra em linhas em vez de ser cortada numa só', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [paginaDe([timbo])]));

      // O texto do campo tem 17 de corpo: a 200%, uma linha tem perto de 51 de altura.
      expect(tester.getSize(find.text(dicaDoCampo)).height, greaterThan(100));
      expect(tester.takeException(), isNull);
    });

    testWidgets('com texto a 200% numa tela estreita, nada estoura', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([timbo], paginas: 2, total: 2),
        paginaDe([timbo], paginas: 2, total: 2),
      ]));
      await tocarNoChip(tester, 'Cardiologia');
      await buscarPor(tester, 'cardio');
      // A contagem e limpar filtros dividem a linha, e quebram quando não cabem.
      expect(find.text('Limpar filtros'), findsOneWidget);
      await rolarAte(tester, find.text('Mostrar mais profissionais'));

      expect(tester.takeException(), isNull);
    });

    testWidgets('com texto a 200% numa tela estreita, a lista vazia e a sugestão também cabem', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, timbo]),
        paginaDe([]),
      ]));
      await buscarPor(tester, 'coracao');
      await rolarAte(tester, find.widgetWithText(OutlinedButton, 'Limpar filtros'));

      expect(find.text('Ver profissionais de Cardiologia', skipOffstage: false), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('com o aparelho deitado, nada estoura, e rolando se chega ao fim da lista', (tester) async {
      tester.view.physicalSize = const Size(800, 360);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await montar(tester, CatalogoFalso(especialidades: [especialidades], profissionais: [
        paginaDe([ana, antonio, timbo], paginas: 2, total: 4),
      ]));

      expect(tester.takeException(), isNull);
      await rolarAte(tester, find.text('Mostrar mais profissionais'));
      expect(find.text('Mostrar mais profissionais'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
