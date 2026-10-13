import 'dart:async';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/ui/conta/criar_conta_screen.dart';
import 'package:agendamento_clinico/ui/conta/entrar_screen.dart';
import 'package:agendamento_clinico/ui/conta/envio_de_conta.dart';
import 'package:agendamento_clinico/ui/conta/esqueci_a_senha_screen.dart';
import 'package:agendamento_clinico/ui/conta/validacoes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/falsos.dart';

Future<void> montar(WidgetTester tester, AutenticacaoFalsa autenticacao, Widget tela) async {
  await tester.pumpWidget(Provider<ServicoDeAutenticacao>.value(
    value: autenticacao,
    child: MaterialApp(theme: temaDoApp(), home: tela),
  ));
}

Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);

TextField textoDo(WidgetTester tester, String rotulo) =>
    tester.widget<TextField>(find.descendant(of: campo(rotulo), matching: find.byType(TextField)));

/// A mensagem aparece embaixo do próprio campo, e não solta na tela.
Finder erroNoCampo(String rotulo, String mensagem) =>
    find.descendant(of: campo(rotulo), matching: find.text(mensagem));

Future<void> preencher(WidgetTester tester, {String? email, String? senha}) async {
  if (email != null) await tester.enterText(campo('E-mail'), email);
  if (senha != null) await tester.enterText(campo('Senha'), senha);
  // Um quadro, como entre a digitação e o próximo toque de verdade.
  await tester.pump();
}

/// Toca no botão com este texto — e não no título da barra, que pode ter o
/// mesmo texto ("Entrar", "Criar conta").
Future<void> tocar(WidgetTester tester, String texto) async {
  final botao = find.ancestor(
    of: find.text(texto),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  await tester.ensureVisible(botao);
  await tester.tap(botao);
  await tester.pump();
}

void main() {
  group('validações', () {
    test('e-mail: vazio, sem arroba e sem domínio são recusados', () {
      expect(validarEmail(''), 'Informe o e-mail.');
      expect(validarEmail('ana.exemplo.test'), isNotNull);
      expect(validarEmail('ana@exemplo'), isNotNull);
      expect(validarEmail('ana@exemplo.test'), isNull);
    });

    test('senha nova: a regra é a do Firebase, 6 caracteres', () {
      expect(validarSenhaNova(''), 'Crie uma senha.');
      expect(validarSenhaNova('12345'), 'A senha precisa ter pelo menos 6 caracteres.');
      expect(validarSenhaNova('123456'), isNull);
    });

    test('ao entrar, a senha só precisa estar preenchida', () {
      expect(validarSenha(''), 'Informe a senha.');
      expect(validarSenha('1'), isNull);
    });
  });

  test('defeito do aplicativo no envio vira aviso geral, e é relatado', () async {
    final relatados = <FlutterErrorDetails>[];
    final anterior = FlutterError.onError;
    FlutterError.onError = relatados.add;
    addTearDown(() => FlutterError.onError = anterior);
    final envio = EnvioDeConta();

    final deuCerto = await envio.enviar(() async => throw StateError('defeito de teste'));

    expect(deuCerto, isFalse);
    expect(relatados.single.exception, isA<StateError>());
    expect(envio.erroGeral, 'Algo deu errado no aplicativo. Tente de novo.');
    expect(envio.enviando, isFalse);
  });

  group('entrar', () {
    testWidgets('campos com rótulo, teclado de e-mail e preenchimento automático', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen());

      final email = textoDo(tester, 'E-mail');
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(email.autofillHints, contains(AutofillHints.email));
      final senha = textoDo(tester, 'Senha');
      expect(senha.obscureText, isTrue);
      expect(senha.autofillHints, contains(AutofillHints.password));
      // Nada de visiblePassword: ele se sobreporia à variação de senha, e o
      // teclado trataria a senha oculta como texto visível.
      expect(senha.keyboardType, isNot(TextInputType.visiblePassword));
      // "Esqueci minha senha" visível já na entrada (checklist 3.10).
      expect(find.text('Esqueci minha senha'), findsOneWidget);
    });

    testWidgets('vazio: diz o que falta embaixo de cada campo, e nada sai do aparelho', (tester) async {
      final autenticacao = AutenticacaoFalsa();
      await montar(tester, autenticacao, const EntrarScreen());

      await tocar(tester, 'Entrar');

      expect(erroNoCampo('E-mail', 'Informe o e-mail.'), findsOneWidget);
      expect(erroNoCampo('Senha', 'Informe a senha.'), findsOneWidget);
      expect(autenticacao.pedidosDeEntrar, isEmpty);
    });

    testWidgets('envia o e-mail e a senha digitados', (tester) async {
      final autenticacao = AutenticacaoFalsa(entrar: [null]);
      await montar(tester, autenticacao, const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test ', senha: 'segredo1');
      await tocar(tester, 'Entrar');

      expect(autenticacao.pedidosDeEntrar.single, (email: 'ana@exemplo.test', senha: 'segredo1'));
    });

    testWidgets('enquanto entra, o botão trava e mostra que está ocupado: dois toques, um pedido', (tester) async {
      final autenticacao = AutenticacaoFalsa(entrar: [Completer<void>()]);
      await montar(tester, autenticacao, const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: 'segredo1');
      await tocar(tester, 'Entrar');
      await tester.tap(find.byType(FilledButton));
      await tester.pump();

      expect(autenticacao.pedidosDeEntrar, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('"concluir" no teclado durante o envio também não manda outro pedido', (tester) async {
      final autenticacao = AutenticacaoFalsa(entrar: [Completer<void>()]);
      await montar(tester, autenticacao, const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: 'segredo1');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      // O botão já está travado; o teclado é o outro caminho até o envio. O
      // "concluir" fecha o teclado, então a pessoa toca no campo de novo.
      await tester.showKeyboard(campo('Senha'));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(autenticacao.pedidosDeEntrar, hasLength(1));
    });

    testWidgets('credencial errada: um aviso geral, que não diz qual dos dois está errado', (tester) async {
      final autenticacao = AutenticacaoFalsa(entrar: [const ErroDeAutenticacao('invalid-credential')]);
      await montar(tester, autenticacao, const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: 'errada1');
      await tocar(tester, 'Entrar');

      expect(find.text('E-mail ou senha incorretos.'), findsOneWidget);
      expect(erroNoCampo('E-mail', 'E-mail ou senha incorretos.'), findsNothing);
    });

    testWidgets('e-mail recusado pelo provedor aparece embaixo do campo, e some ao corrigir', (tester) async {
      const mensagem = 'Confira o e-mail digitado (ex.: nome@email.com).';
      final autenticacao = AutenticacaoFalsa(entrar: [const ErroDeAutenticacao('invalid-email')]);
      await montar(tester, autenticacao, const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: 'segredo1');
      await tocar(tester, 'Entrar');
      expect(erroNoCampo('E-mail', mensagem), findsOneWidget);

      await preencher(tester, email: 'ana@exemplo.tst');
      await tester.pump();
      expect(erroNoCampo('E-mail', mensagem), findsNothing);
    });

    testWidgets('mostrar e ocultar a senha', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen());

      await tester.tap(find.byTooltip('Mostrar senha'));
      await tester.pump();

      expect(textoDo(tester, 'Senha').obscureText, isFalse);
      expect(find.byTooltip('Ocultar senha'), findsOneWidget);
    });

    testWidgets('quando a sessão terminou sem a pessoa pedir, diz por quê', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen(aviso: 'Sua sessão terminou. Entre de novo para continuar.'));

      expect(find.text('Sua sessão terminou. Entre de novo para continuar.'), findsOneWidget);
    });

    testWidgets('"Esqueci minha senha" leva o e-mail já digitado', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen());

      await preencher(tester, email: 'ana@exemplo.test');
      await tocar(tester, 'Esqueci minha senha');
      await tester.pumpAndSettle();

      expect(find.byType(EsqueciASenhaScreen), findsOneWidget);
      expect(textoDo(tester, 'E-mail').controller!.text, 'ana@exemplo.test');
    });

    testWidgets('acessibilidade: toque de 48 dp, rótulos e contraste', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen(aviso: 'Sua sessão terminou.'));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('texto ampliado a 200% sem estourar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, AutenticacaoFalsa(), const EntrarScreen(aviso: 'Sua sessão terminou.'));

      expect(tester.takeException(), isNull);
    });
  });

  group('criar conta', () {
    Future<void> abrirAPartirDeEntrar(WidgetTester tester, AutenticacaoFalsa autenticacao) async {
      await montar(tester, autenticacao, const EntrarScreen());
      await tocar(tester, 'Criar conta');
      await tester.pumpAndSettle();
      expect(find.byType(CriarContaScreen), findsOneWidget);
    }

    testWidgets('a regra da senha aparece antes de qualquer erro', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const CriarContaScreen());

      expect(find.text('Mínimo de 6 caracteres.'), findsOneWidget);
      expect(textoDo(tester, 'Senha').autofillHints, contains(AutofillHints.newPassword));
    });

    testWidgets('senha curta é recusada antes de sair do aparelho', (tester) async {
      final autenticacao = AutenticacaoFalsa();
      await montar(tester, autenticacao, const CriarContaScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: '123');
      await tocar(tester, 'Criar conta');

      expect(erroNoCampo('Senha', 'A senha precisa ter pelo menos 6 caracteres.'), findsOneWidget);
      expect(autenticacao.pedidosDeCriarConta, isEmpty);
    });

    testWidgets('senha recusada pelo provedor aparece embaixo da senha', (tester) async {
      final autenticacao = AutenticacaoFalsa(criarConta: [const ErroDeAutenticacao('weak-password')]);
      await montar(tester, autenticacao, const CriarContaScreen());

      await preencher(tester, email: 'ana@exemplo.test', senha: '123456');
      await tocar(tester, 'Criar conta');

      expect(erroNoCampo('Senha', 'Senha muito curta. Use pelo menos 6 caracteres.'), findsOneWidget);
      expect(autenticacao.pedidosDeCriarConta.single, (email: 'ana@exemplo.test', senha: '123456'));
    });

    testWidgets('e-mail já cadastrado: oferece entrar com ele, e volta com o e-mail preenchido', (tester) async {
      final autenticacao = AutenticacaoFalsa(criarConta: [const ErroDeAutenticacao('email-already-in-use')]);
      await abrirAPartirDeEntrar(tester, autenticacao);

      await preencher(tester, email: 'ana@exemplo.test', senha: '123456');
      await tocar(tester, 'Criar conta');
      expect(erroNoCampo('E-mail', 'Este e-mail já tem cadastro. Quer entrar ou recuperar a senha?'), findsOneWidget);
      expect(find.text('Recuperar a senha'), findsOneWidget);

      await tocar(tester, 'Entrar com este e-mail');
      await tester.pumpAndSettle();

      expect(find.byType(CriarContaScreen), findsNothing);
      expect(textoDo(tester, 'E-mail').controller!.text, 'ana@exemplo.test');
    });

    testWidgets('num celular estreito, o erro comprido aparece inteiro, em mais de uma linha (checklist 9.4)',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await montar(
        tester,
        AutenticacaoFalsa(criarConta: [const ErroDeAutenticacao('email-already-in-use')]),
        const CriarContaScreen(),
      );
      await preencher(tester, email: 'ana@exemplo.test', senha: '123456');
      await tocar(tester, 'Criar conta');

      final erro = find.text('Este e-mail já tem cadastro. Quer entrar ou recuperar a senha?');
      final umaLinha = tester.widget<Text>(erro).style!.fontSize! * 1.5;
      expect(tester.getSize(erro).height, greaterThan(umaLinha));
    });

    testWidgets('"Já tenho conta" sem e-mail nenhum não apaga o que estava digitado em entrar', (tester) async {
      await montar(tester, AutenticacaoFalsa(), const EntrarScreen());
      await preencher(tester, email: 'ana@exemplo.test');
      await tocar(tester, 'Criar conta');
      await tester.pumpAndSettle();
      // O e-mail veio de entrar; a pessoa o apaga, e desiste de criar a conta.
      await preencher(tester, email: '');

      await tocar(tester, 'Já tenho conta');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(CriarContaScreen), findsNothing);
      expect(textoDo(tester, 'E-mail').controller!.text, 'ana@exemplo.test');
    });

    testWidgets('voltar com o formulário preenchido pergunta antes de descartar', (tester) async {
      await abrirAPartirDeEntrar(tester, AutenticacaoFalsa());
      await preencher(tester, senha: '123');

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.text('Descartar alterações?'), findsOneWidget);

      await tester.tap(find.text('Continuar editando'));
      await tester.pumpAndSettle();
      expect(find.byType(CriarContaScreen), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Descartar'));
      await tester.pumpAndSettle();
      expect(find.byType(CriarContaScreen), findsNothing);
      expect(find.byType(EntrarScreen), findsOneWidget);
    });

    testWidgets('formulário vazio volta direto, sem perguntar', (tester) async {
      await abrirAPartirDeEntrar(tester, AutenticacaoFalsa());

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.byType(EntrarScreen), findsOneWidget);
    });

    testWidgets('acessibilidade: toque de 48 dp, rótulos e contraste', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, AutenticacaoFalsa(), const CriarContaScreen());

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });
  });

  group('recuperar a senha', () {
    testWidgets('envia o pedido e confirma — do mesmo jeito, exista ou não a conta', (tester) async {
      final autenticacao = AutenticacaoFalsa(redefinicao: [null]);
      await montar(tester, autenticacao, const EsqueciASenhaScreen(emailInicial: 'ana@exemplo.test'));

      await tocar(tester, 'Enviar link');

      expect(autenticacao.pedidosDeRedefinicao.single, 'ana@exemplo.test');
      expect(find.textContaining('Se houver uma conta com ana@exemplo.test'), findsOneWidget);
      expect(find.textContaining('spam'), findsOneWidget);
    });

    testWidgets('falha de rede: aviso, e o formulário continua para tentar de novo', (tester) async {
      final autenticacao = AutenticacaoFalsa(redefinicao: [const ErroDeAutenticacao('network-request-failed')]);
      await montar(tester, autenticacao, const EsqueciASenhaScreen(emailInicial: 'ana@exemplo.test'));

      await tocar(tester, 'Enviar link');

      expect(find.text('Sem conexão com a internet. Verifique e tente de novo.'), findsOneWidget);
      expect(find.text('Enviar link'), findsOneWidget);
    });
  });
}
