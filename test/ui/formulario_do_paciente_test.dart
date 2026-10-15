import 'dart:async';
import 'dart:convert';

import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/dados_do_paciente.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/paciente.dart';
import 'package:agendamento_clinico/ui/cadastro/formulario_do_paciente_screen.dart';
import 'package:agendamento_clinico/ui/cadastro/formulario_do_paciente_view_model.dart';
import 'package:agendamento_clinico/ui/cadastro/mascaras.dart';
import 'package:agendamento_clinico/ui/cadastro/validacoes_do_paciente.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../apoio/falsos.dart';

const erroDeCampos = ErroDaApi(
  status: 422,
  codigo: 'DADOS_INVALIDOS',
  mensagem: 'Alguns campos não foram preenchidos corretamente.',
  problemas: [ProblemaDeCampo(campo: 'telefone', mensagem: 'Informe o telefone com DDD, com 10 ou 11 dígitos.')],
);

/// Monta o formulário. Devolve o que a tela entregou ao concluir e ao pedir o
/// termo de novo.
Future<({List<Paciente> concluidos, List<bool> termoMudou})> montar(
  WidgetTester tester,
  FormularioDoPacienteViewModel vm, {
  bool comVolta = false,
}) async {
  final concluidos = <Paciente>[];
  final termoMudou = <bool>[];
  final formulario = FormularioDoPacienteScreen(
    criarVm: () => vm,
    email: 'ana@exemplo.test',
    aoConcluir: concluidos.add,
    aoTermoMudar: () => termoMudou.add(true),
  );
  await tester.pumpWidget(MaterialApp(
    theme: temaDoApp(),
    // Com uma tela por baixo, para o "voltar" ter para onde ir.
    home: comVolta
        ? Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push<void>(MaterialPageRoute(builder: (_) => formulario)),
                child: const Text('abrir'),
              ),
            ),
          )
        : formulario,
  ));
  if (comVolta) {
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }
  return (concluidos: concluidos, termoMudou: termoMudou);
}

Finder campo(String rotulo) => find.widgetWithText(TextFormField, rotulo);
const nome = 'Nome completo';
const telefone = 'Telefone com DDD (opcional)';
const nascimento = 'Data de nascimento (opcional)';

/// Rola até o campo — a lista só constrói o que está perto da tela, e com o
/// texto ampliado os de baixo ficam longe — e digita.
Future<void> preencher(WidgetTester tester, Map<String, String> valores) async {
  for (final MapEntry(key: rotulo, value: texto) in valores.entries) {
    await tester.scrollUntilVisible(campo(rotulo), 100, scrollable: find.byType(Scrollable).first);
    await tester.enterText(campo(rotulo), texto);
  }
  await tester.pump();
}

String textoNoCampo(WidgetTester tester, String rotulo) =>
    tester.widget<EditableText>(find.descendant(of: campo(rotulo), matching: find.byType(EditableText))).controller.text;

Future<void> tocarNoBotao(WidgetTester tester, String texto) async {
  final botao = find.widgetWithText(FilledButton, texto);
  await tester.ensureVisible(botao);
  await tester.tap(botao);
  await tester.pump();
}

Finder erroNoCampo(String rotulo, String mensagem) => find.descendant(of: campo(rotulo), matching: find.text(mensagem));

bool temFoco(WidgetTester tester, String rotulo) =>
    tester.widget<EditableText>(find.descendant(of: campo(rotulo), matching: find.byType(EditableText))).focusNode.hasFocus;

void main() {
  group('máscaras', () {
    test('telefone com o código do país, colado ou do preenchimento automático, perde o 55', () {
      expect(formatarTelefone('+55 88 99999-0000'), '(88) 99999-0000');
      expect(formatarTelefone('+55 (88) 3000-0000'), '(88) 3000-0000');
      expect(formatarTelefone('5588999990000'), '(88) 99999-0000');
      // DDD 55 digitado à mão continua sendo DDD 55, e o excedente é ignorado.
      expect(formatarTelefone('55999990000'), '(55) 99999-0000');
      expect(formatarTelefone('559999900001'), '(55) 99999-0000');
    });

    test('data no formato do preenchimento automático (AAAA-MM-DD) é reordenada', () {
      expect(formatarData('1990-03-15'), '15/03/1990');
    });

    test('telefone: fixo enquanto digita, celular no décimo primeiro dígito', () {
      expect(formatarTelefone(''), '');
      expect(formatarTelefone('8'), '(8');
      expect(formatarTelefone('889'), '(88) 9');
      expect(formatarTelefone('8830000000'), '(88) 3000-0000');
      expect(formatarTelefone('88999990000'), '(88) 99999-0000');
      expect(formatarTelefone('8899999000099'), '(88) 99999-0000');
      expect(formatarTelefone('(88) abc 3000'), '(88) 3000');
    });

    test('data: dd/mm/aaaa, e nunca termina em barra', () {
      expect(formatarData('15'), '15');
      expect(formatarData('150'), '15/0');
      expect(formatarData('1503'), '15/03');
      expect(formatarData('15031990'), '15/03/1990');
      expect(formatarData('150319901'), '15/03/1990');
    });
  });

  group('validações, com as regras da API', () {
    test('nome', () {
      expect(validarNome('   '), 'Informe o nome.');
      expect(validarNome(' A '), 'O nome precisa ter ao menos duas letras.');
      expect(validarNome('A' * 121), 'O nome é longo demais.');
      expect(normalizarNome('  Ana   Lima '), 'Ana Lima');
    });

    test('telefone é opcional, mas, se vier, tem DDD e 10 ou 11 dígitos', () {
      expect(validarTelefone(''), isNull);
      expect(validarTelefone('(88) 9999-999'), 'Informe o telefone com DDD, com 10 ou 11 dígitos.');
      expect(validarTelefone('(88) 3000-0000'), isNull);
      expect(validarTelefone('(88) 99999-0000'), isNull);
    });

    test('data de nascimento é opcional, mas, se vier, existe, é depois de 1900 e não é futura', () {
      // 22h do dia 7 em Quixadá: em UTC, já é dia 8.
      final hoje = DateTime.utc(2026, 10, 8, 1);
      expect(validarDataDeNascimento('', agora: hoje), isNull);
      expect(validarDataDeNascimento('15/03', agora: hoje), 'Informe a data completa, no formato dd/mm/aaaa.');
      expect(validarDataDeNascimento('30/02/2000', agora: hoje), 'Essa data de nascimento não existe no calendário.');
      expect(validarDataDeNascimento('31/12/1899', agora: hoje), 'Confira o ano da data de nascimento.');
      expect(validarDataDeNascimento('08/10/2026', agora: hoje), 'A data de nascimento não pode estar no futuro.');
      expect(validarDataDeNascimento('07/10/2026', agora: hoje), isNull);
      expect(lerDataDeNascimento('15/03/1990'), DataCivil.tentar(1990, 3, 15));
    });
  });

  group('pedidos à API', () {
    late List<http.Request> pedidos;
    const perfil = {
      'paciente': {
        'id': 7,
        'nome': 'Ana Lima',
        'email': 'ana@exemplo.test',
        'telefone': null,
        'dataNascimento': null,
        'consentimento': {'versao': '2026-09-v2', 'aceitoEm': '2026-10-06T12:30:00.000Z'},
      },
    };
    RepositorioDoPacienteRemoto repositorio() {
      pedidos = [];
      return RepositorioDoPacienteRemoto(ApiClient(
        cliente: MockClient((pedido) async {
          pedidos.add(pedido);
          return http.Response.bytes(utf8.encode(jsonEncode(perfil)), pedido.method == 'POST' ? 201 : 200);
        }),
        base: Uri.parse('https://api.exemplo.test'),
        token: ({bool renovar = false}) async => 'token-de-teste',
      ));
    }

    test('cadastro: o corpo exato, com o aceite da versão lida e a data no formato da API', () async {
      await repositorio().cadastrar(
        DadosDoPaciente(nome: 'Ana Lima', telefone: '88999990000', dataNascimento: DataCivil.tentar(1990, 3, 15)),
        versaoDoTermo: '2026-09-v2',
      );

      expect(pedidos.single.method, 'POST');
      expect(pedidos.single.url.path, '/pacientes');
      expect(jsonDecode(pedidos.single.body), {
        'nome': 'Ana Lima',
        'telefone': '88999990000',
        'dataNascimento': '1990-03-15',
        'consentimento': {'aceito': true, 'versao': '2026-09-v2'},
      });
    });

    test('cadastro: opcional vazio fica de fora do corpo', () async {
      await repositorio().cadastrar(const DadosDoPaciente(nome: 'Ana Lima'), versaoDoTermo: '2026-09-v2');

      final corpo = jsonDecode(pedidos.single.body) as Map<String, Object?>;
      expect(corpo.keys, unorderedEquals(['nome', 'consentimento']));
    });

    test('edição: opcional apagado vai como null, que é como a API apaga', () async {
      await repositorio().atualizar(const DadosDoPaciente(nome: 'Ana Lima'));

      expect(pedidos.single.method, 'PATCH');
      expect(pedidos.single.url.path, '/pacientes/me');
      expect(jsonDecode(pedidos.single.body), {'nome': 'Ana Lima', 'telefone': null, 'dataNascimento': null});
    });
  });

  group('completar cadastro', () {
    FormularioDoPacienteViewModel cadastro(RepositorioDoPaciente pacientes) =>
        FormularioDoPacienteViewModel.cadastro(pacientes, versaoDoTermo: '2026-09-v2');

    testWidgets('envia os dados já no formato da API, com a versão do termo aceita', (tester) async {
      final perfil = pacienteDeTeste();
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [perfil]);
      final resultado = await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: '  Ana   Lima ', telefone: '88999990000', nascimento: '15031990'});
      expect(textoNoCampo(tester, telefone), '(88) 99999-0000');
      expect(textoNoCampo(tester, nascimento), '15/03/1990');
      await tocarNoBotao(tester, 'Concluir cadastro');

      final enviado = pacientes.cadastros.single;
      expect(enviado.versaoDoTermo, '2026-09-v2');
      expect(enviado.dados.nome, 'Ana Lima');
      expect(enviado.dados.telefone, '88999990000');
      expect(enviado.dados.dataNascimento, DataCivil.tentar(1990, 3, 15));
      expect(resultado.concluidos.single, same(perfil));
    });

    testWidgets('opcionais em branco vão como ausentes', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [pacienteDeTeste()]);
      await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(pacientes.cadastros.single.dados.telefone, isNull);
      expect(pacientes.cadastros.single.dados.dataNascimento, isNull);
    });

    testWidgets('o e-mail aparece só para leitura', (tester) async {
      await montar(tester, cadastro(RepositorioDoPacienteFalso()));

      expect(find.text('ana@exemplo.test'), findsOneWidget);
      expect(campo('E-mail da conta'), findsNothing);
    });

    testWidgets('campo inválido: diz como corrigir, nada sai do aparelho, e o foco vai para ele', (tester) async {
      final pacientes = RepositorioDoPacienteFalso();
      await montar(tester, cadastro(pacientes));

      // A data errada primeiro, o nome por último: o foco termina no nome, e só
      // o salto para o primeiro erro explica ele voltar para a data.
      await preencher(tester, {nascimento: '30022000', nome: 'Ana Lima'});
      expect(temFoco(tester, nome), isTrue);
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(erroNoCampo(nascimento, 'Essa data de nascimento não existe no calendário.'), findsOneWidget);
      expect(pacientes.cadastros, isEmpty);
      expect(temFoco(tester, nascimento), isTrue);
    });

    testWidgets('cadastro repetido (409): o perfil já existe, e é isso que a pessoa queria', (tester) async {
      final perfil = pacienteDeTeste();
      final pacientes = RepositorioDoPacienteFalso(
        cadastrar: [
          const ErroDaApi(status: 409, codigo: 'PACIENTE_JA_CADASTRADO', mensagem: 'Esta conta já tem um cadastro de paciente.'),
        ],
        meu: [perfil],
      );
      final resultado = await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');
      await tester.pump();

      expect(resultado.concluidos.single, same(perfil));
      expect(find.text('Esta conta já tem um cadastro de paciente.'), findsNothing);
    });

    testWidgets('termo trocado entre a leitura e o envio (exibir_termo): volta ao termo', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [
        const ErroDaApi(
          status: 422,
          codigo: 'CONSENTIMENTO_OBRIGATORIO',
          mensagem: 'O termo de consentimento foi atualizado. Leia e aceite a versão atual para continuar.',
          acao: AcaoSugerida.exibirTermo,
        ),
      ]);
      final resultado = await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(resultado.termoMudou, [true]);
      expect(resultado.concluidos, isEmpty);
    });

    testWidgets('campo recusado pela API aparece embaixo dele, com foco, e some ao corrigir', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [erroDeCampos]);
      await montar(tester, cadastro(pacientes));

      // O telefone primeiro, o nome por último: só o salto explica o foco.
      await preencher(tester, {telefone: '8830000000', nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      const mensagem = 'Informe o telefone com DDD, com 10 ou 11 dígitos.';
      expect(erroNoCampo(telefone, mensagem), findsOneWidget);
      expect(temFoco(tester, telefone), isTrue);

      await preencher(tester, {telefone: '88999990000'});
      expect(erroNoCampo(telefone, mensagem), findsNothing);
    });

    testWidgets('problema que não é de um campo do formulário vai para o aviso geral', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [
        const ErroDaApi(
          status: 422,
          codigo: 'DADOS_INVALIDOS',
          mensagem: 'Alguns campos não foram preenchidos corretamente.',
          problemas: [ProblemaDeCampo(campo: 'consentimento.versao', mensagem: 'A versão do termo precisa ser um texto.')],
        ),
      ]);
      await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(find.text('Alguns campos não foram preenchidos corretamente.'), findsOneWidget);
    });

    testWidgets('sem conexão: aviso geral, e os dados continuam no formulário', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [const ErroDaApi.semConexao()]);
      await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
      expect(find.text('Ana Lima'), findsOneWidget);
    });

    testWidgets('"concluir" no teclado durante o envio não manda outro pedido', (tester) async {
      final pacientes = RepositorioDoPacienteFalso(cadastrar: [Completer<Paciente>()]);
      await montar(tester, cadastro(pacientes));

      await preencher(tester, {nome: 'Ana Lima'});
      await tocarNoBotao(tester, 'Concluir cadastro');
      await tester.showKeyboard(campo(nascimento));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(pacientes.cadastros, hasLength(1));
    });

    testWidgets('voltar com dados digitados pergunta antes de descartar', (tester) async {
      await montar(tester, cadastro(RepositorioDoPacienteFalso()), comVolta: true);

      await preencher(tester, {nome: 'Ana'});
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsOneWidget);
    });

    testWidgets('acessibilidade: toque de 48 dp, rótulos e contraste', (tester) async {
      final semantica = tester.ensureSemantics();
      await montar(tester, cadastro(RepositorioDoPacienteFalso()));

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantica.dispose();
    });

    testWidgets('texto ampliado a 200% sem estourar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      await montar(tester, cadastro(RepositorioDoPacienteFalso(cadastrar: [erroDeCampos])));
      await preencher(tester, {nome: 'Ana Lima', telefone: '8830000000'});
      await tocarNoBotao(tester, 'Concluir cadastro');

      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('defeito ao reler o perfil depois do 409 cai na rede de segurança, e é relatado', (tester) async {
    final pacientes = RepositorioDoPacienteFalso(
      cadastrar: [
        const ErroDaApi(status: 409, codigo: 'PACIENTE_JA_CADASTRADO', mensagem: 'Esta conta já tem um cadastro de paciente.'),
      ],
      meu: [StateError('defeito de teste')],
    );
    final resultado = await montar(tester, FormularioDoPacienteViewModel.cadastro(pacientes, versaoDoTermo: '2026-09-v2'));

    await preencher(tester, {nome: 'Ana Lima'});
    await tocarNoBotao(tester, 'Concluir cadastro');
    await tester.pump();

    expect(tester.takeException(), isA<StateError>());
    expect(find.text(const ErroDaApi.falhaNoAplicativo().mensagem), findsOneWidget);
    expect(resultado.concluidos, isEmpty);
  });

  testWidgets('reconstruir a tela no meio do envio não troca o view model: a trava continua valendo', (tester) async {
    final pacientes = RepositorioDoPacienteFalso(cadastrar: [Completer<Paciente>()]);
    late StateSetter reconstruir;
    await tester.pumpWidget(MaterialApp(
      theme: temaDoApp(),
      home: StatefulBuilder(builder: (context, setState) {
        reconstruir = setState;
        // Como o construtor de uma rota: cada reconstrução traz uma fábrica nova.
        return FormularioDoPacienteScreen(
          criarVm: () => FormularioDoPacienteViewModel.cadastro(pacientes, versaoDoTermo: '2026-09-v2'),
          email: 'ana@exemplo.test',
          aoConcluir: (_) {},
        );
      }),
    ));

    await preencher(tester, {nome: 'Ana Lima'});
    await tocarNoBotao(tester, 'Concluir cadastro');
    reconstruir(() {});
    await tester.pump();
    await tester.showKeyboard(campo(nascimento));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(pacientes.cadastros, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  group('editar dados', () {
    testWidgets('começa com os dados atuais, já formatados, e salva pela edição', (tester) async {
      final atual = pacienteDeTeste();
      final atualizado = pacienteDeTeste(nome: 'Ana Lima Sá');
      final pacientes = RepositorioDoPacienteFalso(atualizar: [atualizado]);
      final resultado = await montar(tester, FormularioDoPacienteViewModel.edicao(pacientes, atual: atual));

      expect(find.text('Editar dados'), findsOneWidget);
      expect(textoNoCampo(tester, telefone), '(88) 99999-0000');
      expect(textoNoCampo(tester, nascimento), '15/03/1990');

      await preencher(tester, {nome: 'Ana Lima Sá', telefone: ''});
      await tocarNoBotao(tester, 'Salvar alterações');

      expect(pacientes.atualizacoes.single.nome, 'Ana Lima Sá');
      // Apagar o telefone é apagá-lo na API.
      expect(pacientes.atualizacoes.single.telefone, isNull);
      expect(pacientes.cadastros, isEmpty);
      expect(resultado.concluidos.single, same(atualizado));
    });

    testWidgets('sem mudança nenhuma, voltar não pergunta nada', (tester) async {
      await montar(
        tester,
        FormularioDoPacienteViewModel.edicao(RepositorioDoPacienteFalso(), atual: pacienteDeTeste()),
        comVolta: true,
      );

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsNothing);
      expect(find.text('abrir'), findsOneWidget);
    });

    testWidgets('com mudança, voltar pergunta', (tester) async {
      await montar(
        tester,
        FormularioDoPacienteViewModel.edicao(RepositorioDoPacienteFalso(), atual: pacienteDeTeste()),
        comVolta: true,
      );

      await preencher(tester, {nome: 'Ana Lima Sá'});
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.text('Descartar alterações?'), findsOneWidget);
    });
  });
}
