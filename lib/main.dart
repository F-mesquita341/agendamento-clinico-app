import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/ambiente.dart';
import 'config/tema.dart';
import 'data/repositories/repositorio_de_consultas.dart';
import 'data/repositories/repositorio_de_dispositivos.dart';
import 'data/repositories/repositorio_do_catalogo.dart';
import 'data/repositories/repositorio_do_consentimento.dart';
import 'data/repositories/repositorio_do_paciente.dart';
import 'data/services/abridor_de_links.dart';
import 'data/services/abridor_de_links_do_aparelho.dart';
import 'data/services/api_client.dart';
import 'data/services/autenticacao_firebase.dart';
import 'data/services/notificacoes_firebase.dart';
import 'data/services/servico_de_autenticacao.dart';
import 'data/services/servico_de_notificacoes.dart';
import 'ui/comum/textos.dart';
import 'ui/lembretes/lembretes_view_model.dart';
import 'ui/sessao/portao_da_sessao.dart';
import 'ui/sessao/sessao_view_model.dart';
import 'ui/shell/abas_do_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem opções: no Android, a configuração vem de android/app/google-services.json,
  // lido pelo plugin com.google.gms.google-services do Gradle.
  await Firebase.initializeApp();
  runApp(AplicativoDoPaciente(
    autenticacao: AutenticacaoFirebase(),
    cliente: http.Client(),
    base: Uri.parse(urlDaApi),
    abridor: AbridorDeLinksDoAparelho(),
    notificacoes: NotificacoesFirebase(),
  ));
}

/// O aplicativo montado: aqui as peças se ligam umas às outras, e só aqui.
/// Os testes montam o mesmo aplicativo com um provedor de identidade e uma
/// API em memória.
class AplicativoDoPaciente extends StatefulWidget {
  const AplicativoDoPaciente({
    super.key,
    required this.autenticacao,
    required this.cliente,
    required this.base,
    required this.abridor,
    required this.notificacoes,
    this.lerArquivo,
  });

  final ServicoDeAutenticacao autenticacao;
  final http.Client cliente;
  final Uri base;

  /// O discador e o mapa, fora do aplicativo.
  final AbridorDeLinks abridor;

  /// A permissão de notificações, o endereço do aparelho e os lembretes.
  final ServicoDeNotificacoes notificacoes;

  /// Os arquivos do pacote do aplicativo — o texto do termo.
  final Future<String> Function(String caminho)? lerArquivo;

  @override
  State<AplicativoDoPaciente> createState() => _AplicativoDoPacienteState();
}

class _AplicativoDoPacienteState extends State<AplicativoDoPaciente> {
  late final SessaoViewModel _sessao;
  late final LembretesViewModel _lembretes;
  late final AppLifecycleListener _ciclo;
  late final ApiClient _api;
  final _abas = AbasDoShell();

  /// Avisa o shell quando uma tela por cima dele fecha, para ele pedir as
  /// consultas de novo. Só telas inteiras: fechar um diálogo não conta.
  final _rotas = RouteObserver<PageRoute<dynamic>>();

  @override
  void initState() {
    super.initState();
    _api = ApiClient(
      cliente: widget.cliente,
      base: widget.base,
      token: widget.autenticacao.token,
      // Qualquer pedido que descubra a sessão perdida leva de volta à tela de
      // entrar, sem cada tela precisar lembrar disso.
      aoPerderSessao: () => _sessao.sessaoPerdida(),
    );
    _sessao = SessaoViewModel(
      autenticacao: widget.autenticacao,
      pacientes: RepositorioDoPacienteRemoto(_api),
      // O aparelho sai dos lembretes enquanto o token da conta ainda vale.
      antesDeSair: () => _lembretes.antesDeSair(),
    )..iniciar();
    _lembretes = LembretesViewModel(
      notificacoes: widget.notificacoes,
      dispositivos: RepositorioDeDispositivosRemoto(_api),
      sessao: _sessao,
    )..iniciar();
    // De volta ao aplicativo, a permissão é conferida de novo: a pessoa pode
    // tê-la mudado nas configurações, ou acabado de responder à pergunta.
    _ciclo = AppLifecycleListener(onResume: _lembretes.aoVoltarAoAplicativo);
  }

  @override
  void dispose() {
    _ciclo.dispose();
    _lembretes.dispose();
    _sessao.dispose();
    _abas.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ServicoDeAutenticacao>.value(value: widget.autenticacao),
        Provider<AbridorDeLinks>.value(value: widget.abridor),
        Provider<RepositorioDoCatalogo>(create: (_) => RepositorioDoCatalogoRemoto(_api)),
        Provider<RepositorioDeConsultas>(create: (_) => RepositorioDeConsultasRemoto(_api)),
        Provider<RepositorioDoPaciente>(create: (_) => RepositorioDoPacienteRemoto(_api)),
        Provider<RepositorioDoConsentimento>(create: (_) => RepositorioDoConsentimentoRemoto(_api)),
        ChangeNotifierProvider<SessaoViewModel>.value(value: _sessao),
        ChangeNotifierProvider<LembretesViewModel>.value(value: _lembretes),
        ChangeNotifierProvider<AbasDoShell>.value(value: _abas),
        Provider<RouteObserver<PageRoute<dynamic>>>.value(value: _rotas),
      ],
      child: MaterialApp(
        title: Textos.nomeDoApp,
        theme: temaDoApp(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        navigatorObservers: [_rotas],
        home: PortaoDaSessao(lerArquivo: widget.lerArquivo ?? rootBundle.loadString),
      ),
    );
  }
}
