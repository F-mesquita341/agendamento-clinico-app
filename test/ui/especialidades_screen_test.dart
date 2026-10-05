import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/ui/especialidades/especialidades_screen.dart';
import 'package:agendamento_clinico/ui/especialidades/especialidades_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Catálogo em memória: cada pedido devolve a próxima resposta da fila, que
/// pode ser uma lista, um erro da API, um defeito (`Error`), ou um Completer
/// que o teste resolve quando quiser — é assim que se simula o servidor
/// demorando.
class CatalogoFalso implements RepositorioDoCatalogo {
  CatalogoFalso(this.respostas);

  final List<Object> respostas;
  int pedidos = 0;

  @override
  Future<List<Especialidade>> especialidades() {
    final resposta = respostas[pedidos++];
    return switch (resposta) {
      final Completer<List<Especialidade>> c => c.future,
      final ErroDaApi e => Future.error(e),
      final Error e => Future.error(e),
      final List<Especialidade> l => Future.value(l),
      _ => throw StateError('resposta de teste inválida'),
    };
  }
}

const cardiologia = Especialidade(id: 1, nome: 'Cardiologia');
const pediatria = Especialidade(id: 2, nome: 'Pediatria');
const mensagemDeDemora = 'O servidor está demorando para responder.';

Future<void> montar(WidgetTester tester, CatalogoFalso catalogo) async {
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: ChangeNotifierProvider(
      create: (_) => EspecialidadesViewModel(catalogo)..carregar(),
      child: const EspecialidadesScreen(),
    ),
  ));
}

/// Puxa a lista para baixo, como o dedo faria, até disparar a atualização.
Future<void> puxarParaAtualizar(WidgetTester tester) async {
  await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('lista as especialidades que a API devolve', (tester) async {
    await montar(tester, CatalogoFalso([
      const [cardiologia, pediatria],
    ]));
    await tester.pump();

    expect(find.text('Cardiologia'), findsOneWidget);
    expect(find.text('Pediatria'), findsOneWidget);
  });

  testWidgets('servidor demorando: depois de 4 s, avisa — sem afirmar a causa', (tester) async {
    final demora = Completer<List<Especialidade>>();
    await montar(tester, CatalogoFalso([demora]));

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Carregando…'), findsOneWidget);
    expect(find.textContaining(mensagemDeDemora), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining(mensagemDeDemora), findsOneWidget);
    // Com o servidor fora do ar a conexão também fica pendurada: a tela não
    // pode dizer que ele está acordando.
    expect(find.textContaining('Acordando'), findsNothing);

    demora.complete(const [cardiologia]);
    await tester.pump();
    expect(find.textContaining(mensagemDeDemora), findsNothing);
    expect(find.text('Cardiologia'), findsOneWidget);
  });

  testWidgets('falha mostra a mensagem da API e deixa tentar de novo', (tester) async {
    final catalogo = CatalogoFalso([
      const ErroDaApi.semConexao(),
      const [cardiologia],
    ]);
    await montar(tester, catalogo);
    await tester.pump();

    expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);

    await tester.tap(find.text('Tentar de novo'));
    await tester.pump();

    expect(catalogo.pedidos, 2);
    expect(find.text('Cardiologia'), findsOneWidget);
  });

  testWidgets('defeito do aplicativo não deixa a tela presa carregando, e é relatado', (tester) async {
    await montar(tester, CatalogoFalso([StateError('defeito de teste')]));
    await tester.pump();

    // Relatado: um defeito não pode sumir em silêncio.
    expect(tester.takeException(), isA<StateError>());
    // E a tela saiu do carregando, com saída para a pessoa.
    expect(find.text('Carregando…'), findsNothing);
    expect(find.text(const ErroDaApi.falhaNoAplicativo().mensagem), findsOneWidget);
    expect(find.text('Tentar de novo'), findsOneWidget);
  });

  testWidgets('atualizar mantém a lista na tela enquanto a nova chega', (tester) async {
    final segunda = Completer<List<Especialidade>>();
    final catalogo = CatalogoFalso([const [cardiologia], segunda]);
    await montar(tester, catalogo);
    await tester.pump();

    await puxarParaAtualizar(tester);

    expect(catalogo.pedidos, 2);
    expect(find.text('Cardiologia'), findsOneWidget);
    expect(find.text('Carregando…'), findsNothing);

    segunda.complete(const [cardiologia, pediatria]);
    await tester.pumpAndSettle();
    expect(find.text('Pediatria'), findsOneWidget);
  });

  testWidgets('atualização que falha mantém a lista e diz por quê', (tester) async {
    final catalogo = CatalogoFalso([const [cardiologia], const ErroDaApi.semConexao()]);
    await montar(tester, catalogo);
    await tester.pump();

    await puxarParaAtualizar(tester);
    await tester.pumpAndSettle();

    expect(find.text('Cardiologia'), findsOneWidget);
    expect(find.textContaining('Não foi possível atualizar.'), findsOneWidget);
  });

  testWidgets('lista vazia diz que não há especialidades, em vez de tela em branco', (tester) async {
    await montar(tester, CatalogoFalso([const <Especialidade>[]]));
    await tester.pump();

    expect(find.text('Nenhuma especialidade cadastrada ainda.'), findsOneWidget);
  });

  testWidgets('o botão de tentar de novo tem área de toque de 48 dp ou mais', (tester) async {
    await montar(tester, CatalogoFalso([const ErroDaApi.semConexao()]));
    await tester.pump();

    final tamanho = tester.getSize(find.widgetWithText(FilledButton, 'Tentar de novo'));
    expect(tamanho.height, greaterThanOrEqualTo(48));
  });

  testWidgets('a tela respeita o texto ampliado a 200% sem estourar', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await montar(tester, CatalogoFalso([const ErroDaApi.semConexao()]));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}
