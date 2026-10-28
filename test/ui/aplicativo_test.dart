import 'dart:async';
import 'dart:convert';

import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/main.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_screen.dart';
import 'package:agendamento_clinico/ui/lembretes/lembretes_view_model.dart';
import 'package:agendamento_clinico/ui/sessao/portao_da_sessao.dart';
import 'package:agendamento_clinico/ui/sessao/sessao_view_model.dart';
import 'package:provider/provider.dart';
import 'package:agendamento_clinico/ui/cadastro/formulario_do_paciente_screen.dart';
import 'package:agendamento_clinico/ui/busca/busca_screen.dart';
import 'package:agendamento_clinico/ui/comum/card_do_profissional.dart';
import 'package:agendamento_clinico/ui/comum/chip_de_escolha.dart';
import 'package:agendamento_clinico/ui/comum/marca.dart';
import 'package:agendamento_clinico/ui/conta/abertura_screen.dart';
import 'package:agendamento_clinico/ui/conta/criar_conta_screen.dart';
import 'package:agendamento_clinico/ui/conta/entrar_screen.dart';
import 'package:agendamento_clinico/ui/conta/esqueci_a_senha_screen.dart';
import 'package:agendamento_clinico/ui/consultas/detalhes_da_consulta_screen.dart';
import 'package:agendamento_clinico/ui/inicio/inicio_screen.dart';
import 'package:agendamento_clinico/ui/perfil/perfil_screen.dart';
import 'package:agendamento_clinico/ui/profissional/profissional_screen.dart';
import 'package:agendamento_clinico/ui/shell/shell_screen.dart';
import 'package:agendamento_clinico/ui/termo/termo_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../apoio/falsos.dart';

/// A API em memória, com o comportamento da real nas rotas da Etapa 12: o
/// perfil só existe depois do cadastro.
class ApiFalsa {
  ApiFalsa({this.temPerfil = false, this.versaoDoTermo = '2026-09-v2'});

  bool temPerfil;
  String versaoDoTermo;

  /// O status da consulta 90 no detalhe: o teste o muda quando o "Mercado
  /// Pago" confirma o pagamento.
  String statusDaConsulta = 'pendente_pagamento';

  /// O motivo, quando a consulta 90 é cancelada.
  String? motivoDaConsulta;

  /// O horário reservado por último, para o detalhe da consulta.
  int horarioReservado = 0;

  /// O prazo da reserva, como o agendamento o devolveu.
  String? prazoDaReserva;

  /// A consulta 90 como a API a escreve; [completa], com o horário e o
  /// profissional, como a lista e o detalhe a trazem.
  Map<String, Object?> consulta90({bool completa = true, bool comPrazo = true}) => {
        'id': 90,
        'status': statusDaConsulta,
        'motivoCancelamento': motivoDaConsulta,
        'horarioId': horarioReservado,
        'valorCentavos': 25000,
        'valorFormatado': 'R\$ 250,00',
        'reservaExpiraEm': comPrazo ? prazoDaReserva : null,
        'criadoEm': DateTime.now().toUtc().toIso8601String(),
        if (completa) ...{
          'horario': (grade()['horarios']! as List<Object?>)
              .cast<Map<String, Object?>>()
              .firstWhere((h) => h['id'] == horarioReservado),
          'profissional': cardiologista,
        },
      };
  final pedidos = <http.Request>[];

  /// Respostas forçadas, por "MÉTODO /caminho", consumidas uma vez.
  final forcadas = <String, http.Response>{};

  /// Pedidos segurados, por "MÉTODO /caminho": a resposta só sai quando o
  /// teste completar a espera — o servidor demorando.
  final esperas = <String, Completer<void>>{};

  Map<String, Object?> perfil({String nome = 'Ana Lima'}) => {
        'paciente': {
          'id': 7,
          'nome': nome,
          'email': 'ana@exemplo.test',
          'telefone': '88999990000',
          'dataNascimento': '1990-03-15',
          // 22:30 do dia 6 em Quixadá: em UTC, já é dia 7.
          'consentimento': {'versao': '2026-09-v2', 'aceitoEm': '2026-10-07T01:30:00.000Z'},
        },
      };

  static const cardiologista = {
    'id': 2,
    'nome': 'Carlos Eduardo Timbó',
    'registroConselho': 'CRM-CE 12345',
    'especialidade': {'id': 1, 'nome': 'Cardiologia'},
    'valorCentavos': 25000,
    'valorFormatado': 'R\$ 250,00',
    'clinica': {
      'id': 1,
      'nome': 'Clínica Exemplo Quixadá',
      'telefone': '(88) 3000-0000',
      'endereco': 'Centro, Quixadá - CE',
    },
  };

  static http.Response json(int status, Object corpo) =>
      http.Response.bytes(utf8.encode(jsonEncode(corpo)), status, headers: {'content-type': 'application/json'});

  static Map<String, Object?> erro(String codigo, String mensagem, [String? acao]) => {
        'erro': {'codigo': codigo, 'mensagem': mensagem, 'acao': acao},
      };

  late final cliente = MockClient((pedido) async {
    pedidos.add(pedido);
    final rota = '${pedido.method} ${pedido.url.path}';
    if (esperas.remove(rota) case final espera?) await espera.future;
    if (forcadas.remove(rota) case final resposta?) return resposta;
    return switch (rota) {
      'GET /especialidades' => json(200, {
          'especialidades': [
            {'id': 1, 'nome': 'Cardiologia'},
          ],
        }),
      'GET /profissionais' => json(200, {
          'profissionais': [cardiologista],
          'paginacao': {'pagina': 1, 'limite': 20, 'total': 1, 'paginas': 1},
        }),
      'GET /profissionais/2/horarios' => json(200, grade()),
      'GET /consentimento/termo-vigente' => json(200, {
          'termo': {'versao': versaoDoTermo},
        }),
      'GET /pacientes/me' => temPerfil
          ? json(200, perfil())
          : json(404, erro('PERFIL_NAO_CADASTRADO', 'Complete seu cadastro para continuar.', 'completar_cadastro')),
      'POST /pacientes' => () {
          temPerfil = true;
          return json(201, perfil());
        }(),
      'PATCH /pacientes/me' => json(200, perfil(nome: 'Ana Lima Sá')),
      // A reserva do horário pedido, aguardando pagamento por 15 minutos.
      'POST /consultas' => () {
          horarioReservado = (jsonDecode(pedido.body) as Map<String, Object?>)['horarioId']! as int;
          prazoDaReserva = DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String();
          statusDaConsulta = 'pendente_pagamento';
          motivoDaConsulta = null;
          return json(201, {'consulta': consulta90(completa: false)});
        }(),
      // A página de pagamento, em ambiente de teste.
      'POST /consultas/90/pagamento' => json(201, {
          'pagamento': {
            'status': 'aberto',
            'checkoutUrl': 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=teste',
            'expiraEm': DateTime.now().toUtc().add(const Duration(minutes: 15)).toIso8601String(),
            'valorCentavos': 25000,
            'valorFormatado': 'R\$ 250,00',
          },
        }),
      // A consulta como a API a tem: o status é o que o teste disser.
      'GET /consultas/90' => json(200, {'consulta': consulta90(comPrazo: false)}),
      // As consultas do paciente: a 90, depois de reservada.
      'GET /consultas' => json(200, {
          'consultas': [if (horarioReservado != 0) consulta90()],
          'paginacao': {'pagina': 1, 'limite': 20, 'total': horarioReservado != 0 ? 1 : 0, 'paginas': 1},
        }),
      // O cancelamento, como a API o responde: sem o horário nem o profissional.
      'PATCH /consultas/90/cancelamento' => () {
          statusDaConsulta = 'cancelada';
          motivoDaConsulta = 'paciente';
          return json(200, {'consulta': consulta90(completa: false)});
        }(),
      // O aparelho, nos lembretes: o mesmo token, o mesmo id.
      'POST /dispositivos' => json(201, {
          'dispositivo': {'id': 12},
        }),
      'DELETE /dispositivos/12' => http.Response('', 204),
      _ => json(404, erro('ROTA_NAO_ENCONTRADA', 'Não existe $rota nesta API.')),
    };
  });

  /// A grade do cardiologista: três horários livres amanhã, no calendário da
  /// clínica — amanhã de verdade, pelo relógio de quem roda o teste, como o
  /// aplicativo o lê. Sem os de [tirar], que outra pessoa reservou.
  static Map<String, Object?> grade({Set<int> tirar = const {}}) {
    final amanha = DataCivil.naClinica(DateTime.now()).maisDias(1);
    // Hora da clínica mais três: UTC.
    String instante(int hora, int minuto) =>
        DateTime.utc(amanha.ano, amanha.mes, amanha.dia, hora + 3, minuto).toIso8601String();
    return {
      'periodo': {'de': DateTime.now().toUtc().toIso8601String(), 'ate': instante(21, 0)},
      'horarios': [
        for (final (id, hora, minuto) in [(41, 9, 0), (42, 10, 30), (43, 14, 30)])
          if (!tirar.contains(id)) {
            'id': id,
            'inicio': instante(hora, minuto),
            'fim': instante(hora, minuto + 30),
            'duracaoMinutos': 30,
            'versao': 0,
          },
      ],
    };
  }

  Iterable<http.Request> pedidosA(String metodo, String caminho) =>
      pedidos.where((p) => p.method == metodo && p.url.path == caminho);
}

Future<void> montar(
  WidgetTester tester,
  AutenticacaoFalsa autenticacao,
  ApiFalsa api, {
  AbridorDeLinksFalso? abridor,
  NotificacoesFalsas? notificacoes,
}) async {
  await tester.pumpWidget(AplicativoDoPaciente(
    autenticacao: autenticacao,
    cliente: api.cliente,
    base: Uri.parse('https://api.exemplo.test'),
    abridor: abridor ?? AbridorDeLinksFalso(),
    // Sem nada dito, como numa instalação nova no Android 13: sem a permissão.
    notificacoes: notificacoes ?? NotificacoesFalsas(),
    lerArquivo: lerDoDisco,
  ));
  await tester.pump();
}

/// O provedor avisa que há (ou não) sessão, e a tela assenta.
Future<void> sessao(WidgetTester tester, AutenticacaoFalsa autenticacao, UsuarioDaSessao? usuario) async {
  autenticacao.emitir(usuario);
  await tester.pumpAndSettle();
}

/// Rola até o botão com este texto — a lista só constrói o que está perto da
/// tela — e toca nele, e não num título com o mesmo texto. Vale também para a
/// linha que leva a outra tela ("Editar dados", no perfil).
Future<void> tocar(WidgetTester tester, String texto) async {
  final botao = find.ancestor(
    of: find.text(texto),
    matching: find.byWidgetPredicate((w) => w is ButtonStyleButton || (w is ListTile && w.onTap != null)),
  );
  await tester.scrollUntilVisible(botao, 300, scrollable: find.byType(Scrollable).first);
  await tester.tap(botao.first);
  await tester.pumpAndSettle();
}

/// Toca numa aba da barra de baixo — o rótulo dentro da barra, e não o título
/// da tela, que pode ter o mesmo texto.
Future<void> abrirAba(WidgetTester tester, String rotulo) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(rotulo)));
  await tester.pumpAndSettle();
}

/// Pela busca: o cardiologista, as 14:30 de amanhã, o resumo e a reserva —
/// termina na tela do pagamento.
Future<void> reservarAs1430(WidgetTester tester) async {
  await abrirAba(tester, 'Buscar');
  await tester.tap(find.widgetWithText(ChipDeEscolha, 'Cardiologia'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.text('14:30'), 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(find.text('14:30'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continuar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirmar e ir para o pagamento'));
  await tester.pumpAndSettle();
}

/// Sai do pagamento sem pagar, pelo voltar do Android e o "Sair" do diálogo.
Future<void> sairDoPagamento(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
  await tester.tap(find.text('Sair'));
  await tester.pumpAndSettle();
}

int abaEscolhida(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

bool podeVoltar(WidgetTester tester) => tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

void main() {
  testWidgets('enquanto o provedor não diz se há sessão: a marca e o indicador de espera', (tester) async {
    await montar(tester, AutenticacaoFalsa(), ApiFalsa());

    expect(find.byType(Marca), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('o portão em miniatura: criar conta, aceitar o termo, cadastrar, ver o perfil, sair', (tester) async {
    final autenticacao = AutenticacaoFalsa(criarConta: [null]);
    final api = ApiFalsa();
    await montar(tester, autenticacao, api);
    expect(find.byType(Marca), findsOneWidget);

    // Sem sessão: a abertura, e dali criar a conta.
    await sessao(tester, autenticacao, null);
    expect(find.byType(AberturaScreen), findsOneWidget);
    await tocar(tester, 'Criar conta');
    await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.test');
    await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo1');
    await tester.pump();
    await tocar(tester, 'Criar conta');
    expect(autenticacao.pedidosDeCriarConta.single.email, 'ana@exemplo.test');

    // O provedor entra na conta nova; ela ainda não tem perfil: o termo.
    await sessao(tester, autenticacao, ana);
    expect(find.byType(CriarContaScreen), findsNothing);
    expect(find.byType(TermoScreen), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tocar(tester, 'Continuar');

    // O cadastro, com o aceite da versão lida.
    expect(find.byType(FormularioDoPacienteScreen), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima');
    await tester.pump();
    await tocar(tester, 'Concluir cadastro');
    final cadastro = jsonDecode(api.pedidosA('POST', '/pacientes').single.body) as Map<String, Object?>;
    expect(cadastro['consentimento'], {'aceito': true, 'versao': '2026-09-v2'});

    // Sem a permissão de notificações, a explicação do lembrete vem antes.
    expect(find.byType(LembretesScreen), findsOneWidget);
    await tocar(tester, 'Agora não');

    // O aplicativo, sem caminho de volta para o formulário ou o termo.
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(podeVoltar(tester), isFalse);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    expect(find.text('Ana Lima'), findsOneWidget);

    // Sair, com confirmação.
    await tocar(tester, 'Sair da conta');
    expect(find.text('Sair da conta?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Sair da conta'));
    await tester.pumpAndSettle();
    expect(autenticacao.saidas, 1);
    // Saiu por vontade própria: de volta à abertura, sem aviso nenhum.
    expect(find.byType(AberturaScreen), findsOneWidget);
  });

  group('sem sessão', () {
    Future<void> abrir(WidgetTester tester, AutenticacaoFalsa autenticacao) async {
      await montar(tester, autenticacao, ApiFalsa());
      await sessao(tester, autenticacao, null);
    }

    String emailEmEntrar(WidgetTester tester) => tester
        .widget<TextField>(find.descendant(
          of: find.descendant(of: find.byType(EntrarScreen), matching: find.widgetWithText(TextFormField, 'E-mail')),
          matching: find.byType(TextField),
        ))
        .controller!
        .text;

    testWidgets('sem motivo: a abertura, com os dois caminhos, e não a tela de entrar', (tester) async {
      await abrir(tester, AutenticacaoFalsa());

      expect(find.byType(AberturaScreen), findsOneWidget);
      expect(find.byType(EntrarScreen), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Criar conta'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Já tenho conta'), findsOneWidget);
      // Voltar, na abertura, sai do aplicativo: não há para onde voltar.
      expect(podeVoltar(tester), isFalse);
    });

    testWidgets('"Já tenho conta" abre a tela de entrar, e voltar retorna à abertura', (tester) async {
      await abrir(tester, AutenticacaoFalsa());

      await tocar(tester, 'Já tenho conta');
      expect(find.byType(EntrarScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(EntrarScreen), findsNothing);
      expect(find.byType(AberturaScreen), findsOneWidget);
    });

    testWidgets('criar conta e voltar pelo sistema: fica na abertura', (tester) async {
      await abrir(tester, AutenticacaoFalsa());
      await tocar(tester, 'Criar conta');
      expect(find.byType(CriarContaScreen), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.byType(CriarContaScreen), findsNothing);
      expect(find.byType(EntrarScreen), findsNothing);
      expect(find.byType(AberturaScreen), findsOneWidget);
    });

    testWidgets('em criar conta, "Já tenho conta" leva a entrar com o e-mail que estava digitado', (tester) async {
      await abrir(tester, AutenticacaoFalsa());
      await tocar(tester, 'Criar conta');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.test');
      await tester.pump();

      await tocar(tester, 'Já tenho conta');
      // Havia algo digitado: a pergunta de descartar vem antes (checklist 3.6).
      await tester.tap(find.widgetWithText(TextButton, 'Descartar'));
      await tester.pumpAndSettle();

      expect(find.byType(CriarContaScreen), findsNothing);
      expect(find.byType(EntrarScreen), findsOneWidget);
      expect(emailEmEntrar(tester), 'ana@exemplo.test');
    });

    testWidgets('em criar conta, "Entrar com este e-mail" leva a entrar com ele', (tester) async {
      final autenticacao = AutenticacaoFalsa(criarConta: [const ErroDeAutenticacao('email-already-in-use')]);
      await abrir(tester, autenticacao);
      await tocar(tester, 'Criar conta');
      await tester.enterText(find.widgetWithText(TextFormField, 'E-mail'), 'ana@exemplo.test');
      await tester.enterText(find.widgetWithText(TextFormField, 'Senha'), 'segredo1');
      await tester.pump();
      await tocar(tester, 'Criar conta');

      await tocar(tester, 'Entrar com este e-mail');

      expect(find.byType(CriarContaScreen), findsNothing);
      expect(find.byType(EntrarScreen), findsOneWidget);
      expect(emailEmEntrar(tester), 'ana@exemplo.test');
    });
  });

  testWidgets('portão criado com a sessão já assentada: a primeira troca de área também fecha o que está aberto', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final pacientes = RepositorioDoPacienteFalso(meu: [const ErroDaApi.semConexao()]);
    final vm = SessaoViewModel(autenticacao: autenticacao, pacientes: pacientes)..iniciar();
    addTearDown(vm.dispose);
    final lembretes = LembretesViewModel(notificacoes: NotificacoesFalsas(), dispositivos: DispositivosFalso(), sessao: vm)
      ..iniciar();
    addTearDown(lembretes.dispose);
    // A sessão já sabe que não há ninguém antes de o portão existir.
    autenticacao.emitir(null);
    await tester.pump();

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServicoDeAutenticacao>.value(value: autenticacao),
        Provider<RepositorioDoPaciente>.value(value: pacientes),
        ChangeNotifierProvider<SessaoViewModel>.value(value: vm),
        ChangeNotifierProvider<LembretesViewModel>.value(value: lembretes),
      ],
      child: const MaterialApp(home: PortaoDaSessao(lerArquivo: lerDoDisco)),
    ));
    await tocar(tester, 'Criar conta');
    expect(find.byType(CriarContaScreen), findsOneWidget);

    // Entra, e o perfil não carrega: a tela de falha, sem o Criar conta por cima.
    await sessao(tester, autenticacao, ana);

    expect(find.byType(CriarContaScreen, skipOffstage: false), findsNothing);
    expect(find.text(const ErroDaApi.semConexao().mensagem), findsOneWidget);
  });

  testWidgets('quem entra com perfil vai direto ao aplicativo', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);

    await sessao(tester, autenticacao, ana);

    expect(find.byType(ShellScreen), findsOneWidget);
    // A barra, na ordem da checklist (4.4), e a primeira aba é o Início: sem
    // consulta nenhuma, o convite para agendar.
    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barra.selectedIndex, 0);
    expect(
      [for (final destino in barra.destinations) (destino as NavigationDestination).label],
      ['Início', 'Buscar', 'Minhas consultas', 'Perfil'],
    );
    expect(find.byType(InicioScreen), findsOneWidget);
    expect(find.text('Você ainda não tem consultas'), findsOneWidget);
    expect(api.pedidosA('GET', '/consultas'), isNotEmpty);

    // A busca, já com os profissionais da API.
    await abrirAba(tester, 'Buscar');
    expect(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'), findsOneWidget);
  });

  testWidgets('o portão em miniatura da Etapa 13: achar um cardiologista e ver os horários de amanhã', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    final abridor = AbridorDeLinksFalso();
    await montar(tester, autenticacao, api, abridor: abridor);
    await sessao(tester, autenticacao, ana);

    // Buscar: a especialidade, e o cardiologista na lista.
    await abrirAba(tester, 'Buscar');
    expect(find.byType(BuscaScreen), findsOneWidget);
    await tester.tap(find.widgetWithText(ChipDeEscolha, 'Cardiologia'));
    await tester.pumpAndSettle();
    expect(api.pedidos.last.url.queryParameters, {'especialidade': '1', 'pagina': '1'});
    await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();

    // O profissional, com a grade pedida sem o token da conta, e amanhã já escolhido.
    expect(find.byType(ProfissionalScreen), findsOneWidget);
    final hoje = DataCivil.naClinica(DateTime.now());
    final grade = api.pedidosA('GET', '/profissionais/2/horarios').single;
    expect(grade.url.queryParameters, {'ate': hoje.maisDias(14).paraApi()});
    expect(grade.headers.containsKey('Authorization'), isFalse);
    expect(find.text('Amanhã', skipOffstage: false), findsWidgets);

    // O telefone da clínica, pelo aparelho.
    await tester.tap(find.text('Ligar'));
    await tester.pumpAndSettle();
    expect(abridor.ligacoes, ['(88) 3000-0000']);

    // Os horários de amanhã ficam mais abaixo: rolando até eles.
    await tester.scrollUntilVisible(find.text('14:30'), 200, scrollable: find.byType(Scrollable).first);
    for (final hora in ['09:00', '10:30', '14:30']) {
      expect(find.text(hora, skipOffstage: false), findsOneWidget, reason: hora);
    }
    await tester.tap(find.text('14:30'));
    await tester.pumpAndSettle();
    expect(find.textContaining('14:30 · 30\u00a0min'), findsOneWidget);

    // Voltar leva à busca como estava: a especialidade continua escolhida.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(ProfissionalScreen), findsNothing);
    expect(tester.widget<ChipDeEscolha>(find.widgetWithText(ChipDeEscolha, 'Cardiologia')).escolhido, isTrue);
    expect(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'), findsOneWidget);
  });

  testWidgets('o portão em miniatura da Etapa 14: outra pessoa reserva antes, a grade recarrega, e o outro horário fica reservado', (
    tester,
  ) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Buscar');

    // O cardiologista, e as 14:30 de amanhã.
    await tester.tap(find.widgetWithText(ChipDeEscolha, 'Cardiologia'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();
    expect(find.text('Etapa 1 de 3'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('14:30'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('14:30'));
    await tester.pumpAndSettle();

    // Entre a grade e a confirmação, outra pessoa reserva as 14:30: a API
    // recusa pela versão, e a grade nova já vem sem elas.
    api.forcadas['POST /consultas'] = ApiFalsa.json(
      409,
      ApiFalsa.erro(
        'HORARIO_INDISPONIVEL',
        'Este horário acabou de ser reservado por outro paciente.',
        'recarregar_horarios',
      ),
    );
    api.forcadas['GET /profissionais/2/horarios'] = ApiFalsa.json(200, ApiFalsa.grade(tirar: {43}));

    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    expect(find.text('Resumo da consulta'), findsOneWidget);
    expect(find.text('Etapa 2 de 3'), findsOneWidget);
    await tester.tap(find.text('Confirmar e ir para o pagamento'));
    await tester.pumpAndSettle();

    // O pedido levou o horário e a versão da grade, com o token da conta.
    final primeira = api.pedidosA('POST', '/consultas').single;
    expect(jsonDecode(primeira.body), {'horarioId': 43, 'versao': 0});
    expect(primeira.headers['Authorization'], 'Bearer token-de-teste');

    // O fallback do TCC (Seção 3.8.3): a grade recarregada, sem as 14:30, e a
    // explicação com a mensagem da API.
    expect(api.pedidosA('GET', '/profissionais/2/horarios'), hasLength(2));
    expect(find.text('Esse horário não está mais livre'), findsOneWidget);
    expect(
      find.text('Este horário acabou de ser reservado por outro paciente. A lista de horários já foi atualizada.'),
      findsOneWidget,
    );
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text('14:30')), findsNothing);

    // Uma das sugestões, direto para o resumo, e desta vez a reserva sai.
    await tester.tap(find.descendant(of: find.byType(BottomSheet), matching: find.text('10:30')));
    await tester.pumpAndSettle();
    expect(find.text('Resumo da consulta'), findsOneWidget);
    await tester.tap(find.text('Confirmar e ir para o pagamento'));
    await tester.pumpAndSettle();

    expect(jsonDecode(api.pedidosA('POST', '/consultas').last.body), {'horarioId': 42, 'versao': 0});
    expect(find.text('Pagamento'), findsOneWidget);
    expect(find.text('Etapa 3 de 3'), findsOneWidget);
    expect(find.textContaining('Seu horário fica reservado até'), findsOneWidget);
    expect(find.textContaining('(faltam 15\u00a0minutos)'), findsOneWidget);

    // Voltar do pagamento pergunta antes; saindo, leva à busca, e não ao
    // resumo nem à grade.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Sair sem pagar?'), findsOneWidget);
    await tester.tap(find.text('Sair'));
    await tester.pumpAndSettle();
    expect(find.byType(BuscaScreen), findsOneWidget);
    expect(find.byType(ProfissionalScreen), findsNothing);
  });

  testWidgets('o portão em miniatura da Etapa 15: pagar na aba, voltar, e a consulta confirmada pela API', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    final abridor = AbridorDeLinksFalso();
    await montar(tester, autenticacao, api, abridor: abridor);
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Buscar');

    // O cardiologista, as 14:30 de amanhã, o resumo e a reserva.
    await tester.tap(find.widgetWithText(ChipDeEscolha, 'Cardiologia'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('14:30'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('14:30'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continuar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirmar e ir para o pagamento'));
    await tester.pumpAndSettle();
    expect(find.text('Pagamento'), findsOneWidget);
    expect(find.text('Ambiente de teste: nenhum valor real é cobrado.').hitTestable(), findsOneWidget);

    // A página do Mercado Pago, pedida com o token, aberta na aba.
    await tester.tap(find.text('Abrir o pagamento'));
    await tester.pump();
    await tester.pump();
    final pedido = api.pedidosA('POST', '/consultas/90/pagamento').single;
    expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    expect(abridor.pagamentos, [Uri.parse('https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=teste')]);

    // Lá, a pessoa paga; o webhook chega à API, que passa a dizer confirmada.
    api.statusDaConsulta = 'confirmada';
    for (final estado in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(estado);
    }
    await tester.pumpAndSettle();

    // A confirmação vem do detalhe que a API devolveu, com o endereço.
    expect(api.pedidosA('GET', '/consultas/90'), isNotEmpty);
    expect(find.text('Consulta confirmada'), findsOneWidget);
    expect(find.text('Centro, Quixadá - CE'), findsOneWidget);

    // Voltar dali leva ao Início, e não ao pagamento — e o Início, pedido de
    // novo na volta, já mostra a consulta paga.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(InicioScreen), findsOneWidget);
    expect(find.text('Pagamento'), findsNothing);
    expect(find.text('Sua próxima consulta'), findsOneWidget);
  });

  testWidgets('o portão em miniatura da Etapa 16: a reserva no Início, os detalhes, cancelar e agendar de novo', (
    tester,
  ) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    expect(find.text('Você ainda não tem consultas'), findsOneWidget);

    // Reservar e sair sem pagar: na volta, o shell pede as consultas de novo.
    await reservarAs1430(tester);
    expect(find.text('Pagamento'), findsOneWidget);
    await sairDoPagamento(tester);

    // O Início mostra a reserva, e "Pagar agora" reabre o pagamento, sem a etapa.
    await abrirAba(tester, 'Início');
    expect(find.textContaining('Reserva aguardando pagamento. Carlos Eduardo Timbó'), findsOneWidget);
    await tester.tap(find.text('Pagar agora'));
    await tester.pumpAndSettle();
    expect(find.text('Pagamento'), findsOneWidget);
    expect(find.text('Etapa 3 de 3'), findsNothing);
    await sairDoPagamento(tester);

    // Minhas consultas: a reserva nas próximas; os detalhes; cancelar.
    await abrirAba(tester, 'Minhas consultas');
    expect(find.text('Próximas (1)'), findsOneWidget);
    await tester.tap(find.textContaining('·\u00a014:30').first);
    await tester.pumpAndSettle();
    await tester.tap(find.ancestor(of: find.text('Cancelar consulta'), matching: find.byType(OutlinedButton)));
    await tester.pumpAndSettle();
    expect(find.text('Cancelar esta consulta?'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancelar consulta')));
    await tester.pumpAndSettle();
    final cancelamento = api.pedidosA('PATCH', '/consultas/90/cancelamento').single;
    expect(cancelamento.headers['Authorization'], 'Bearer token-de-teste');
    expect(find.text('Consulta cancelada.'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);

    // De volta à lista, pedida de novo: a consulta passou às anteriores.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Próximas (0)'), findsOneWidget);
    expect(find.text('Anteriores (1)'), findsOneWidget);
    await tester.tap(find.text('Anteriores (1)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agendar de novo com Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfissionalScreen), findsOneWidget);
  });

  testWidgets('sair e entrar de novo começa no Início', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Minhas consultas');
    expect(abaEscolhida(tester), 2);

    await sessao(tester, autenticacao, null);
    await sessao(tester, autenticacao, ana);

    expect(abaEscolhida(tester), 0);
    expect(find.byType(InicioScreen), findsOneWidget);
  });

  testWidgets('fechar um diálogo por cima do shell não pede as consultas de novo; fechar uma tela, pede', (
    tester,
  ) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    final antes = api.pedidosA('GET', '/consultas').length;

    await abrirAba(tester, 'Perfil');
    await tocar(tester, 'Sair da conta');
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancelar')));
    await tester.pumpAndSettle();
    expect(api.pedidosA('GET', '/consultas'), hasLength(antes));

    await abrirAba(tester, 'Buscar');
    await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(api.pedidosA('GET', '/consultas'), hasLength(antes + 1));
  });

  testWidgets('a sessão que cai com uma tela por cima do shell não faz pedir as consultas', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Buscar');
    await tester.tap(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'));
    await tester.pumpAndSettle();
    final antes = api.pedidosA('GET', '/consultas').length;

    await sessao(tester, autenticacao, null);

    expect(find.byType(ShellScreen), findsNothing);
    expect(api.pedidosA('GET', '/consultas'), hasLength(antes));
  });

  testWidgets('a especialidade escolhida no Início abre a busca com ela, e com o campo vazio', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Buscar');
    await tester.enterText(find.byType(TextField), 'carlos');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    await abrirAba(tester, 'Início');
    await tester.scrollUntilVisible(
      find.widgetWithText(ListTile, 'Cardiologia'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.widgetWithText(ListTile, 'Cardiologia'));
    await tester.pumpAndSettle();

    expect(abaEscolhida(tester), 1);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(tester.widget<ChipDeEscolha>(find.widgetWithText(ChipDeEscolha, 'Cardiologia')).escolhido, isTrue);
    expect(api.pedidosA('GET', '/profissionais').last.url.queryParameters, {'especialidade': '1', 'pagina': '1'});
  });

  testWidgets('a barra de quatro abas, a 200% num aparelho estreito: nada estoura', (tester) async {
    tester.view.physicalSize = const Size(360, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);

    for (final aba in ['Buscar', 'Minhas consultas', 'Perfil', 'Início']) {
      await abrirAba(tester, aba);
      expect(tester.takeException(), isNull, reason: aba);
    }
  });

  testWidgets('trocar de área fecha as telas abertas por cima', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, null);
    // Duas telas por cima da abertura: entrar, e recuperar a senha.
    await tocar(tester, 'Já tenho conta');
    await tocar(tester, 'Esqueci minha senha');
    expect(find.byType(EsqueciASenhaScreen), findsOneWidget);

    await sessao(tester, autenticacao, ana);

    expect(find.byType(EsqueciASenhaScreen), findsNothing);
    expect(find.byType(EntrarScreen), findsNothing);
    expect(find.byType(ShellScreen), findsOneWidget);
    expect(podeVoltar(tester), isFalse);
  });

  testWidgets('sessão perdida num pedido: volta à entrada, com o motivo, e fecha o que estava aberto', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();
    await tocar(tester, 'Editar dados');
    expect(find.byType(FormularioDoPacienteScreen), findsOneWidget);

    api.forcadas['PATCH /pacientes/me'] =
        ApiFalsa.json(401, ApiFalsa.erro('NAO_AUTENTICADO', 'Faça login para continuar.', 'autenticar'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima Sá');
    await tester.pump();
    await tocar(tester, 'Salvar alterações');

    expect(find.byType(FormularioDoPacienteScreen), findsNothing);
    // Direto na tela de entrar, e não na abertura: a pessoa já estava dentro.
    expect(find.byType(AberturaScreen), findsNothing);
    expect(find.byType(EntrarScreen), findsOneWidget);
    expect(find.text('Sua sessão terminou. Entre de novo para continuar.'), findsOneWidget);
    expect(autenticacao.saidas, 1);
  });

  testWidgets('editar os dados: salva, volta ao perfil atualizado e confirma', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    await tocar(tester, 'Editar dados');
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima Sá');
    await tester.pump();
    await tocar(tester, 'Salvar alterações');

    expect(find.byType(PerfilScreen), findsOneWidget);
    expect(find.text('Dados salvos.'), findsOneWidget);
    // O perfil rolou até o botão de editar; o nome está no topo.
    await tester.scrollUntilVisible(find.text('Ana Lima Sá'), -300, scrollable: find.byType(Scrollable).first);
    expect(find.text('Ana Lima Sá'), findsOneWidget);
  });

  testWidgets('o perfil mostra os dados e o termo aceito, que se pode reler', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    // No cabeçalho: as iniciais, o nome e o e-mail.
    expect(find.text('AL'), findsOneWidget);
    expect(find.text('Ana Lima'), findsOneWidget);
    expect(find.text('ana@exemplo.test'), findsOneWidget);
    expect(find.text('(88) 99999-0000'), findsOneWidget);
    expect(find.text('15/03/1990'), findsOneWidget);
    expect(find.textContaining('Versão 2026-09-v2, aceita em 06/10/2026'), findsOneWidget);

    await tocar(tester, 'Ler o termo');
    expect(find.text('Termo de consentimento para tratamento de dados'), findsOneWidget);
  });

  testWidgets('termo trocado durante o cadastro: o formulário fecha e o termo novo é lido', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa();
    await montar(tester, autenticacao, api);
    await sessao(tester, autenticacao, ana);
    await tester.scrollUntilVisible(find.byType(CheckboxListTile), 300, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tocar(tester, 'Continuar');

    api.forcadas['POST /pacientes'] = ApiFalsa.json(
      422,
      ApiFalsa.erro('CONSENTIMENTO_OBRIGATORIO', 'O termo de consentimento foi atualizado.', 'exibir_termo'),
    );
    api.versaoDoTermo = '2027-01-v3';
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima');
    await tester.pump();
    await tocar(tester, 'Concluir cadastro');

    expect(find.byType(FormularioDoPacienteScreen), findsNothing);
    expect(api.pedidosA('GET', '/consentimento/termo-vigente'), hasLength(2));
    // A versão nova não está neste aplicativo: nada de aceitar um texto que
    // não foi mostrado.
    expect(find.text('Atualize o aplicativo'), findsOneWidget);
  });

  testWidgets('barra de status do Android: ícones claros sobre o fundo escuro, e escuros de volta nas telas claras',
      (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    api.forcadas['GET /pacientes/me'] = ApiFalsa.json(500, ApiFalsa.erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.'));
    await montar(tester, autenticacao, api);
    // A espera inicial tem o fundo na cor principal.
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.light);

    // A falha ao carregar o perfil não tem barra superior, e o fundo é claro.
    await sessao(tester, autenticacao, ana);
    expect(find.text('Algo deu errado do nosso lado.'), findsOneWidget);
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.dark);

    // A abertura volta ao fundo escuro.
    await tocar(tester, 'Sair da conta');
    expect(find.byType(AberturaScreen), findsOneWidget);
    expect(SystemChrome.latestStyle!.statusBarIconBrightness, Brightness.light);
  });

  testWidgets('falha ao carregar o perfil: tentar de novo, ou sair', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    api.forcadas['GET /pacientes/me'] = ApiFalsa.json(500, ApiFalsa.erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.'));
    await montar(tester, autenticacao, api);

    await sessao(tester, autenticacao, ana);
    expect(find.text('Algo deu errado do nosso lado.'), findsOneWidget);
    expect(find.text('Sair da conta'), findsOneWidget);

    await tocar(tester, 'Tentar de novo');
    expect(find.byType(ShellScreen), findsOneWidget);
  });

  testWidgets('desistir na confirmação não sai da conta', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    await tocar(tester, 'Sair da conta');
    await tester.tap(find.widgetWithText(TextButton, 'Cancelar'));
    await tester.pumpAndSettle();

    expect(autenticacao.saidas, 0);
    expect(find.byType(PerfilScreen), findsOneWidget);
  });

  testWidgets('voltar do Android, fora da primeira aba, volta para ela', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await abrirAba(tester, 'Perfil');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    final barra = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(barra.selectedIndex, 0);
  });

  testWidgets('perfil com o aparelho deitado: nada estoura, e rolando se chega a sair da conta', (tester) async {
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tocar(tester, 'Sair da conta');
    expect(find.text('Sair da conta?'), findsOneWidget);
  });

  testWidgets('perfil: acessibilidade e texto ampliado', (tester) async {
    final semantica = tester.ensureSemantics();
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final autenticacao = AutenticacaoFalsa();
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
    await sessao(tester, autenticacao, ana);
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantica.dispose();
  });

  group('lembretes', () {
    /// Do termo ao fim do cadastro, numa conta nova.
    Future<void> cadastrar(WidgetTester tester, AutenticacaoFalsa autenticacao) async {
      await sessao(tester, autenticacao, ana);
      await tester.scrollUntilVisible(find.byType(CheckboxListTile), 300, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tocar(tester, 'Continuar');
      await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima');
      await tester.pump();
      await tocar(tester, 'Concluir cadastro');
    }

    /// O grupo dos lembretes fica mais abaixo no Perfil, e a lista só constrói
    /// o que está perto da tela: rola até o texto antes de conferir.
    Future<void> rolarAte(WidgetTester tester, String texto) =>
        tester.scrollUntilVisible(find.text(texto), 200, scrollable: find.byType(Scrollable).first);

    /// A consulta 90, confirmada, para amanhã às 14:30.
    ApiFalsa comConsultaConfirmada() => ApiFalsa(temPerfil: true)
      ..horarioReservado = 43
      ..statusDaConsulta = 'confirmada';

    group('a explicação, depois do cadastro', () {
      testWidgets('"Ativar lembretes" e "Permitir": o aparelho registrado, e o aplicativo', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa();
        final notificacoes = NotificacoesFalsas(concede: true);
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await cadastrar(tester, autenticacao);

        expect(find.text('Quer receber um lembrete?'), findsOneWidget);
        expect(find.textContaining('não mostra o profissional nem a especialidade'), findsOneWidget);
        // Antes da pergunta do sistema, nada: a explicação vem primeiro.
        expect(notificacoes.perguntas, 0);
        expect(api.pedidosA('POST', '/dispositivos'), isEmpty);
        await tocar(tester, 'Ativar lembretes');

        expect(notificacoes.perguntas, 1);
        final registro = api.pedidosA('POST', '/dispositivos').single;
        expect(jsonDecode(registro.body), {'token': 'token-fcm-de-teste', 'plataforma': 'android'});
        expect(registro.headers['Authorization'], 'Bearer token-de-teste');
        expect(find.byType(ShellScreen), findsOneWidget);
        expect(find.text('Lembretes ativados.'), findsOneWidget);
        await abrirAba(tester, 'Perfil');
        await rolarAte(tester, 'Ativados: um aviso um dia antes da consulta');
      });

      testWidgets('"Não permitir": onde ativar depois, e nada vai para a API', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa();
        await montar(tester, autenticacao, api);
        await cadastrar(tester, autenticacao);

        await tocar(tester, 'Ativar lembretes');

        expect(find.byType(ShellScreen), findsOneWidget);
        expect(find.text('Os lembretes ficaram desativados. Você pode ativar em Perfil.'), findsOneWidget);
        expect(api.pedidosA('POST', '/dispositivos'), isEmpty);
        await abrirAba(tester, 'Perfil');
        await rolarAte(tester, 'Desativados');
        expect(find.text('Ativar lembretes'), findsOneWidget);
      });

      testWidgets('permitido, mas o registro falha: o aviso diz que o aplicativo tenta de novo', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa();
        api.forcadas['POST /dispositivos'] = ApiFalsa.json(500, ApiFalsa.erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.'));
        await montar(tester, autenticacao, api, notificacoes: NotificacoesFalsas(concede: true));
        await cadastrar(tester, autenticacao);

        await tocar(tester, 'Ativar lembretes');

        expect(find.byType(ShellScreen), findsOneWidget);
        expect(
          find.text('Não foi possível ativar os lembretes agora. O aplicativo tenta de novo quando você voltar.'),
          findsOneWidget,
        );
      });

      testWidgets('a permissão ainda não lida quando o cadastro acaba: a espera, sem o aplicativo piscar antes', (
        tester,
      ) async {
        final autenticacao = AutenticacaoFalsa();
        final leitura = Completer<bool>();
        await montar(tester, autenticacao, ApiFalsa(), notificacoes: NotificacoesFalsas()..leituraNoAr = leitura);
        await sessao(tester, autenticacao, ana);
        await tester.scrollUntilVisible(find.byType(CheckboxListTile), 300, scrollable: find.byType(Scrollable).first);
        await tester.tap(find.byType(CheckboxListTile));
        await tester.pump();
        await tocar(tester, 'Continuar');
        await tester.enterText(find.widgetWithText(TextFormField, 'Nome completo'), 'Ana Lima');
        await tester.pump();
        // Sem esperar assentar: o indicador de carga gira até a leitura chegar.
        await tester.tap(find.widgetWithText(FilledButton, 'Concluir cadastro'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(FormularioDoPacienteScreen), findsNothing);
        expect(find.byType(ShellScreen), findsNothing);
        expect(find.byType(LembretesScreen), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        leitura.complete(false);
        await tester.pumpAndSettle();
        expect(find.byType(LembretesScreen), findsOneWidget);
      });

      testWidgets('voltar do Android vale "Agora não", e não fecha o aplicativo', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, ApiFalsa(), notificacoes: notificacoes);
        await cadastrar(tester, autenticacao);
        expect(find.byType(LembretesScreen), findsOneWidget);

        final fechou = await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        expect(fechou, isTrue);
        expect(find.byType(ShellScreen), findsOneWidget);
        expect(notificacoes.perguntas, 0);
      });

      testWidgets('a explicação a 200%: nada estoura, e os botões têm nome e tamanho de toque', (tester) async {
        final semantica = tester.ensureSemantics();
        final autenticacao = AutenticacaoFalsa();
        await montar(tester, autenticacao, ApiFalsa());
        await cadastrar(tester, autenticacao);

        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        tester.view.physicalSize = const Size(360, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpAndSettle();
        expect(find.byType(LembretesScreen), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(find.text('Agora não'), 300, scrollable: find.byType(Scrollable).first);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        semantica.dispose();
      });
    });

    group('o toque no lembrete', () {
      testWidgets('com uma tela aberta por cima: ela fecha, os detalhes abrem, e voltar leva ao Início', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = comConsultaConfirmada();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');
        await tocar(tester, 'Ler o termo');
        expect(find.text('Termo de consentimento para tratamento de dados'), findsOneWidget);

        notificacoes.tocar(lembreteDaConsulta(90));
        await tester.pumpAndSettle();

        // O status de agora, lido da API, e não o do envio.
        expect(api.pedidosA('GET', '/consultas/90'), hasLength(1));
        expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
        expect(find.text('Termo de consentimento para tratamento de dados'), findsNothing);

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(find.byType(DetalhesDaConsultaScreen), findsNothing);
        expect(abaEscolhida(tester), 0);
        expect(podeVoltar(tester), isFalse);
      });

      testWidgets('o toque que abriu o aplicativo fechado: a consulta abre assim que a conta abre', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas(toqueInicial: lembreteDaConsulta(90));
        await montar(tester, autenticacao, comConsultaConfirmada(), notificacoes: notificacoes);

        await sessao(tester, autenticacao, ana);

        expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
        expect(notificacoes.leiturasDoToqueInicial, 1);
      });

      testWidgets('um toque sem a conta aberta espera a pessoa entrar', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, comConsultaConfirmada(), notificacoes: notificacoes);
        await sessao(tester, autenticacao, null);

        notificacoes.tocar(lembreteDaConsulta(90));
        await tester.pumpAndSettle();
        expect(find.byType(AberturaScreen), findsOneWidget);

        await sessao(tester, autenticacao, ana);
        expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
      });

      testWidgets('a mesma mensagem entregue de novo não abre a consulta outra vez', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = comConsultaConfirmada();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);
        notificacoes.tocar(lembreteDaConsulta(90));
        await tester.pumpAndSettle();
        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();

        notificacoes.tocar(lembreteDaConsulta(90));
        await tester.pumpAndSettle();

        expect(find.byType(DetalhesDaConsultaScreen), findsNothing);
        expect(api.pedidosA('GET', '/consultas/90'), hasLength(1));
      });

      testWidgets('a consulta de outra conta: não encontrada, sem nada dela, e "Ver minhas consultas"', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, ApiFalsa(temPerfil: true), notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);

        notificacoes.tocar(lembreteDaConsulta(77));
        await tester.pumpAndSettle();
        expect(find.text('Não encontramos esta consulta nesta conta.'), findsOneWidget);

        await tocar(tester, 'Ver minhas consultas');
        expect(abaEscolhida(tester), 2);
        expect(podeVoltar(tester), isFalse);
      });

      testWidgets('a consulta que não carrega: a mensagem da API e "Tentar de novo"', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = comConsultaConfirmada();
        final notificacoes = NotificacoesFalsas();
        api.forcadas['GET /consultas/90'] = ApiFalsa.json(500, ApiFalsa.erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.'));
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);

        notificacoes.tocar(lembreteDaConsulta(90));
        await tester.pumpAndSettle();
        expect(find.text('Algo deu errado do nosso lado.'), findsOneWidget);

        await tocar(tester, 'Tentar de novo');
        expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
      });
    });

    group('com o aplicativo aberto', () {
      testWidgets('o aviso com o texto da API, e "Ver" abre a consulta', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, comConsultaConfirmada(), notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);

        notificacoes.chegarComOAppAberto(lembreteDaConsulta(90));
        await tester.pumpAndSettle();
        expect(find.text('Você tem uma consulta amanhã às 14:30.'), findsOneWidget);

        await tester.tap(find.text('Ver'));
        await tester.pumpAndSettle();
        expect(find.byType(DetalhesDaConsultaScreen), findsOneWidget);
      });

      testWidgets('o aviso some sozinho', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final notificacoes = NotificacoesFalsas();
        await montar(tester, autenticacao, comConsultaConfirmada(), notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);

        notificacoes.chegarComOAppAberto(lembreteDaConsulta(90));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 11));
        await tester.pumpAndSettle();

        expect(find.text('Você tem uma consulta amanhã às 14:30.'), findsNothing);
      });
    });

    group('no Perfil', () {
      testWidgets('"Ativar lembretes" com "Permitir": o aparelho registrado, e ativados', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa(temPerfil: true);
        await montar(tester, autenticacao, api, notificacoes: NotificacoesFalsas(concede: true));
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');
        await rolarAte(tester, 'Desativados');

        await tocar(tester, 'Ativar lembretes');

        expect(api.pedidosA('POST', '/dispositivos'), hasLength(1));
        await rolarAte(tester, 'Ativados: um aviso um dia antes da consulta');
        expect(find.text('Lembretes ativados.'), findsOneWidget);
        expect(find.text('Ativar lembretes'), findsNothing);
      });

      testWidgets('com a pergunta recusada: o diálogo diz onde ativar nas configurações', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        await montar(tester, autenticacao, ApiFalsa(temPerfil: true));
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');

        await tocar(tester, 'Ativar lembretes');

        expect(find.text('Os lembretes continuam desativados'), findsOneWidget);
        expect(find.textContaining('Configurações › Apps › Marcaí › Notificações'), findsOneWidget);
        await tester.tap(find.text('Entendi'));
        await tester.pumpAndSettle();
        expect(find.text('Os lembretes continuam desativados'), findsNothing);
        await rolarAte(tester, 'Desativados');
      });

      testWidgets('o registro que falha: "Tentar de novo" registra', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa(temPerfil: true);
        api.forcadas['POST /dispositivos'] = ApiFalsa.json(500, ApiFalsa.erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.'));
        await montar(tester, autenticacao, api, notificacoes: NotificacoesFalsas(permitido: true));
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');
        await rolarAte(tester, 'Não foi possível confirmar os lembretes agora');

        await tocar(tester, 'Tentar de novo');

        expect(api.pedidosA('POST', '/dispositivos'), hasLength(2));
        await rolarAte(tester, 'Ativados: um aviso um dia antes da consulta');
      });

      testWidgets('sair: "Saindo…" enquanto o aparelho sai da API, e só depois a saída do provedor', (tester) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa(temPerfil: true);
        final notificacoes = NotificacoesFalsas(permitido: true);
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');
        final revogacao = api.esperas['DELETE /dispositivos/12'] = Completer<void>();

        await tocar(tester, 'Sair da conta');
        await tester.tap(find.widgetWithText(TextButton, 'Sair da conta'));
        await tester.pump();
        await tester.pump();

        expect(find.text('Saindo…'), findsOneWidget);
        expect(api.pedidosA('DELETE', '/dispositivos/12'), hasLength(1));
        expect(autenticacao.saidas, 0);

        revogacao.complete();
        await tester.pumpAndSettle();
        expect(autenticacao.saidas, 1);
        expect(notificacoes.tokensApagados, greaterThanOrEqualTo(1));
        expect(find.byType(AberturaScreen), findsOneWidget);
      });

      testWidgets('de volta ao aplicativo, com a permissão revogada nas configurações: o aparelho sai da API', (
        tester,
      ) async {
        final autenticacao = AutenticacaoFalsa();
        final api = ApiFalsa(temPerfil: true);
        final notificacoes = NotificacoesFalsas(permitido: true);
        await montar(tester, autenticacao, api, notificacoes: notificacoes);
        await sessao(tester, autenticacao, ana);
        await abrirAba(tester, 'Perfil');
        await rolarAte(tester, 'Ativados: um aviso um dia antes da consulta');

        notificacoes.permitido = false;
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await tester.pumpAndSettle();

        expect(api.pedidosA('DELETE', '/dispositivos/12'), hasLength(1));
        await rolarAte(tester, 'Desativados');
      });
    });
  });
}
