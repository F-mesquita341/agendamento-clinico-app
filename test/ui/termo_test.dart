import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_consentimento.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/ui/termo/termo_lido_screen.dart';
import 'package:agendamento_clinico/ui/termo/termo_screen.dart';
import 'package:agendamento_clinico/ui/termo/termo_view_model.dart';
import 'package:agendamento_clinico/ui/termo/termos_conhecidos.dart';
import 'package:agendamento_clinico/ui/termo/texto_do_termo.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';

import '../apoio/acessibilidade.dart';
import '../apoio/falsos.dart';

/// O conteúdo de cada arquivo de cada versão do termo, fixado. Mudar uma
/// vírgula do texto de uma versão que já existe derruba este teste: quem
/// aceitou aquela versão aceitou aquele texto. Texto novo é versão nova — e
/// a API precisa trocar a versão vigente junto.
///
/// As quebras de linha são normalizadas antes do hash: o Git no Windows pode
/// entregar o arquivo com CRLF, e o texto é o mesmo.
const conteudoFixado = {
  'assets/termos/termo-2026-09-v2.md': '357f80062d704fd458034312918f7b3f34ac6b2ec1385182e08b04d3ea8a7397',
  'assets/termos/resumo-2026-09-v2.md': '5a5845e88a1f9ad836be2700695822f36eaa5f514c2fa81ee1f2b47129e166f1',
};

String hash(String caminho) =>
    sha256.convert(utf8.encode(File(caminho).readAsStringSync().replaceAll('\r\n', '\n'))).toString();

/// Todo o texto que a tela mostra, junto.
String textoNaTela(WidgetTester tester) =>
    tester.widgetList<RichText>(find.byType(RichText)).map((r) => r.text.toPlainText()).join('\n');

Future<TermoViewModel> montar(
  WidgetTester tester,
  List<Object?> versoes, {
  void Function(String versao)? aoContinuar,
  VoidCallback? aoSair,
  Map<String, ({String termo, String resumo})> conhecidos = termosConhecidos,
}) async {
  final vm = TermoViewModel(ConsentimentoFalso(versoes), lerArquivo: lerDoDisco, conhecidos: conhecidos);
  unawaited(vm.carregar());
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    home: ChangeNotifierProvider.value(
      value: vm,
      child: TermoScreen(aoContinuar: aoContinuar ?? (_) {}, aoSair: aoSair ?? () {}),
    ),
  ));
  await tester.pump();
  return vm;
}

Finder caixaDoAceite() => find.byType(CheckboxListTile);

/// O aceite fica no fim do texto: para chegar a ele, rola-se o termo inteiro,
/// como a pessoa faria. A lista só constrói o que está perto da tela.
Future<void> rolarAte(WidgetTester tester, Finder alvo) async {
  await tester.scrollUntilVisible(alvo, 300, scrollable: find.byType(Scrollable).first);
  await tester.pump();
}

Future<void> marcar(WidgetTester tester) async {
  await rolarAte(tester, caixaDoAceite());
  await tester.tap(caixaDoAceite());
  await tester.pump();
}

Future<FilledButton> botaoContinuar(WidgetTester tester) async {
  final botao = find.widgetWithText(FilledButton, 'Continuar');
  await rolarAte(tester, botao);
  return tester.widget<FilledButton>(botao);
}

void main() {
  group('os textos de cada versão', () {
    for (final MapEntry(key: versao, value: arquivos) in termosConhecidos.entries) {
      test('$versao: os arquivos existem e não mudaram', () {
        for (final caminho in [arquivos.termo, arquivos.resumo]) {
          expect(conteudoFixado, contains(caminho), reason: 'arquivo novo sem conteúdo fixado: $caminho');
          expect(hash(caminho), conteudoFixado[caminho], reason: caminho);
        }
      });

      test('$versao: o texto diz a própria versão', () {
        expect(File(arquivos.termo).readAsStringSync(), contains('**Versão:** `$versao`'));
      });
    }
  });

  group('leitura do texto', () {
    test('parágrafo de várias linhas vira um parágrafo só', () {
      final blocos = lerBlocos('Este aplicativo é\num protótipo.\n\nOutro.');

      expect(blocos.map((b) => (b as Paragrafo).texto), ['Este aplicativo é um protótipo.', 'Outro.']);
    });

    test('item de lista continua na linha recuada seguinte', () {
      final lista = lerBlocos('- primeiro\n  continua\n- segundo').single as Lista;

      expect(lista.itens, ['primeiro continua', 'segundo']);
    });

    test('títulos, régua, negrito e crases', () {
      final blocos = lerBlocos('# Termo\n\n**Versão:** `2026-09-v2`\n\n---\n\n## Seção');

      expect(blocos[0], isA<Titulo>().having((t) => t.nivel, 'nivel', 1));
      expect(trechos((blocos[1] as Paragrafo).texto), [
        (texto: 'Versão:', negrito: true),
        (texto: ' 2026-09-v2', negrito: false),
      ]);
      expect(blocos[2], isA<Separador>());
      expect(blocos[3], isA<Titulo>().having((t) => t.nivel, 'nivel', 2));
    });

    testWidgets('o termo de verdade aparece sem sobrar nenhum símbolo de Markdown', (tester) async {
      for (final arquivos in termosConhecidos.values) {
        for (final caminho in [arquivos.termo, arquivos.resumo]) {
          await tester.pumpWidget(MaterialApp(
            home: SingleChildScrollView(child: TextoDoTermo(File(caminho).readAsStringSync())),
          ));
          final texto = textoNaTela(tester);

          expect(texto, isNot(contains('**')), reason: caminho);
          expect(texto, isNot(contains('`')), reason: caminho);
          expect(RegExp(r'^\s*(#|- |---)', multiLine: true).hasMatch(texto), isFalse, reason: caminho);
        }
      }
    });
  });

  group('versão vigente', () {
    test('lida da API, em rota pública', () async {
      late http.Request pedido;
      final repositorio = RepositorioDoConsentimentoRemoto(ApiClient(
        cliente: MockClient((p) async {
          pedido = p;
          return http.Response('{"termo":{"versao":"2026-09-v2"}}', 200);
        }),
        base: Uri.parse('https://api.exemplo.test'),
        token: ({bool renovar = false}) async => 'token-de-teste',
      ));

      expect(await repositorio.versaoVigente(), '2026-09-v2');
      expect(pedido.url.path, '/consentimento/termo-vigente');
      expect(pedido.headers, isNot(contains('Authorization')));
    });

    test('resposta sem versão vira RESPOSTA_INESPERADA', () async {
      final repositorio = RepositorioDoConsentimentoRemoto(ApiClient(
        cliente: MockClient((_) async => http.Response('{"termo":{}}', 200)),
        base: Uri.parse('https://api.exemplo.test'),
      ));

      await expectLater(
        repositorio.versaoVigente(),
        throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')),
      );
    });
  });

  group('tela do termo', () {
    testWidgets('mostra o resumo e o texto inteiro, com a caixa do aceite desmarcada', (tester) async {
      await montar(tester, ['2026-09-v2']);

      expect(find.text('Em resumo'), findsOneWidget);
      await rolarAte(tester, find.text('Termo de consentimento para tratamento de dados'));
      await rolarAte(tester, caixaDoAceite());
      expect(tester.widget<CheckboxListTile>(caixaDoAceite()).value, isFalse);
      expect((await botaoContinuar(tester)).onPressed, isNull);
      expect(find.text('Marque a caixa acima para continuar.'), findsOneWidget);
    });

    testWidgets('marcar o aceite libera o Continuar, que segue com a versão mostrada', (tester) async {
      String? aceita;
      // Duas versões conhecidas, e a vigente é a segunda: o aceite segue com a
      // versão que a API disse e cujo texto está na tela — não com uma fixa.
      await montar(
        tester,
        ['2099-01-teste'],
        aoContinuar: (versao) => aceita = versao,
        conhecidos: {...termosConhecidos, '2099-01-teste': termosConhecidos.values.first},
      );

      await marcar(tester);
      expect((await botaoContinuar(tester)).onPressed, isNotNull);
      await tester.tap(find.text('Continuar'));

      expect(aceita, '2099-01-teste');
    });

    testWidgets('versão que o aplicativo não tem: pede atualização, e não há aceite possível', (tester) async {
      var saiu = false;
      final vm = await montar(tester, ['2027-01-v3'], aoSair: () => saiu = true);

      expect(vm.estado, EstadoDoTermo.desatualizado);
      expect(find.text('Atualize o aplicativo'), findsOneWidget);
      expect(caixaDoAceite(), findsNothing);
      vm.marcarAceite(true);
      expect(vm.podeContinuar, isFalse);

      await tester.tap(find.text('Sair da conta'));
      expect(saiu, isTrue);
    });

    testWidgets('falha ao carregar: tentar de novo, ou sair da conta', (tester) async {
      final vm = await montar(tester, [const ErroDaApi.semConexao(), '2026-09-v2']);

      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
      expect(find.text('Sair da conta'), findsOneWidget);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      expect(vm.estado, EstadoDoTermo.pronto);
    });

    testWidgets('carga substituída não sobrescreve a mais nova, mesmo chegando depois', (tester) async {
      final antiga = Completer<String>();
      final nova = Completer<String>();
      final vm = TermoViewModel(ConsentimentoFalso([antiga, nova]), lerArquivo: lerDoDisco);

      unawaited(vm.carregar());
      unawaited(vm.carregar());
      nova.complete('2026-09-v2');
      await tester.pump();
      // A primeira chega por último, dizendo uma versão que já não vale.
      antiga.complete('2027-01-v3');
      await tester.pump();

      expect(vm.estado, EstadoDoTermo.pronto);
      expect(vm.versao, '2026-09-v2');
      vm.dispose();
    });

    testWidgets('reler o termo: falha ao abrir o arquivo é relatada e deixa tentar de novo', (tester) async {
      var tentativas = 0;
      Future<String> lerQueFalhaUmaVez(String caminho) async {
        if (tentativas++ == 0) throw const FileSystemException('arquivo de teste');
        return File(caminho).readAsStringSync();
      }

      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: TermoLidoScreen(versao: '2026-09-v2', lerArquivo: lerQueFalhaUmaVez),
      ));
      await tester.pump();

      expect(tester.takeException(), isA<FileSystemException>());
      expect(find.text('Não foi possível abrir o texto do termo. Tente de novo.'), findsOneWidget);
      expect(find.textContaining('não está nesta versão'), findsNothing);

      await tester.tap(find.text('Tentar de novo'));
      await tester.pump();
      await tester.pump();
      expect(find.text('Termo de consentimento para tratamento de dados'), findsOneWidget);
    });

    testWidgets('carregar de novo desmarca o aceite', (tester) async {
      final vm = await montar(tester, ['2026-09-v2', '2026-09-v2']);
      await marcar(tester);

      await vm.carregar();

      expect(vm.aceito, isFalse);
    });

    testWidgets('servidor demorando: avisa depois de 4 s', (tester) async {
      await montar(tester, [Completer<String>()]);

      await tester.pump(const Duration(seconds: 5));

      expect(find.textContaining('O servidor está demorando'), findsOneWidget);
    });

    testWidgets('acessibilidade: toque de 48 dp, rótulos e contraste', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, ['2026-09-v2']);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('nos quatro aparelhos, do resumo ao aceite', (tester) async {
      await montar(tester, ['2026-09-v2']);
      await tester.pumpAndSettle();
      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('texto ampliado a 200% sem estourar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, ['2026-09-v2']);

      expect(tester.takeException(), isNull);
    });
  });
}
