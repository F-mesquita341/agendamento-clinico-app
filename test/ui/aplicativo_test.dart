import 'dart:convert';

import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/main.dart';
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
  final pedidos = <http.Request>[];

  /// Respostas forçadas, por "MÉTODO /caminho", consumidas uma vez.
  final forcadas = <String, http.Response>{};

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

  static http.Response json(int status, Object corpo) =>
      http.Response.bytes(utf8.encode(jsonEncode(corpo)), status, headers: {'content-type': 'application/json'});

  static Map<String, Object?> erro(String codigo, String mensagem, [String? acao]) => {
        'erro': {'codigo': codigo, 'mensagem': mensagem, 'acao': acao},
      };

  late final cliente = MockClient((pedido) async {
    pedidos.add(pedido);
    final rota = '${pedido.method} ${pedido.url.path}';
    if (forcadas.remove(rota) case final resposta?) return resposta;
    return switch (rota) {
      'GET /especialidades' => json(200, {
          'especialidades': [
            {'id': 1, 'nome': 'Cardiologia'},
          ],
        }),
      'GET /profissionais' => json(200, {
          'profissionais': [
            {
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
            },
          ],
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
      _ => json(404, erro('ROTA_NAO_ENCONTRADA', 'Não existe $rota nesta API.')),
    };
  });

  /// A grade do cardiologista: três horários livres amanhã, no calendário da
  /// clínica — amanhã de verdade, pelo relógio de quem roda o teste, como o
  /// aplicativo o lê.
  static Map<String, Object?> grade() {
    final amanha = DataCivil.naClinica(DateTime.now()).maisDias(1);
    // Hora da clínica mais três: UTC.
    String instante(int hora, int minuto) =>
        DateTime.utc(amanha.ano, amanha.mes, amanha.dia, hora + 3, minuto).toIso8601String();
    return {
      'periodo': {'de': DateTime.now().toUtc().toIso8601String(), 'ate': instante(21, 0)},
      'horarios': [
        for (final (id, hora, minuto) in [(41, 9, 0), (42, 10, 30), (43, 14, 30)])
          {
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
}) async {
  await tester.pumpWidget(AplicativoDoPaciente(
    autenticacao: autenticacao,
    cliente: api.cliente,
    base: Uri.parse('https://api.exemplo.test'),
    abridor: abridor ?? AbridorDeLinksFalso(),
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
    // A sessão já sabe que não há ninguém antes de o portão existir.
    autenticacao.emitir(null);
    await tester.pump();

    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<ServicoDeAutenticacao>.value(value: autenticacao),
        Provider<RepositorioDoPaciente>.value(value: pacientes),
        ChangeNotifierProvider<SessaoViewModel>.value(value: vm),
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
    await montar(tester, autenticacao, ApiFalsa(temPerfil: true));

    await sessao(tester, autenticacao, ana);

    expect(find.byType(ShellScreen), findsOneWidget);
    // A primeira aba é a busca, já com os profissionais da API.
    expect(find.widgetWithText(CardDoProfissional, 'Carlos Eduardo Timbó'), findsOneWidget);
  });

  testWidgets('o portão em miniatura da Etapa 13: achar um cardiologista e ver os horários de amanhã', (tester) async {
    final autenticacao = AutenticacaoFalsa();
    final api = ApiFalsa(temPerfil: true);
    final abridor = AbridorDeLinksFalso();
    await montar(tester, autenticacao, api, abridor: abridor);
    await sessao(tester, autenticacao, ana);

    // Buscar: a especialidade, e o cardiologista na lista.
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
    await tester.tap(find.text('Perfil'));
    await tester.pumpAndSettle();

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
}
