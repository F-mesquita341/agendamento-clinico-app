import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/ambiente.dart';
import 'config/tema.dart';
import 'data/repositories/repositorio_do_catalogo.dart';
import 'data/repositories/repositorio_do_consentimento.dart';
import 'data/repositories/repositorio_do_paciente.dart';
import 'data/services/abridor_de_links.dart';
import 'data/services/abridor_de_links_do_aparelho.dart';
import 'data/services/api_client.dart';
import 'data/services/autenticacao_firebase.dart';
import 'data/services/servico_de_autenticacao.dart';
import 'ui/comum/textos.dart';
import 'ui/sessao/portao_da_sessao.dart';
import 'ui/sessao/sessao_view_model.dart';

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
    this.lerArquivo,
  });

  final ServicoDeAutenticacao autenticacao;
  final http.Client cliente;
  final Uri base;

  /// O discador e o mapa, fora do aplicativo.
  final AbridorDeLinks abridor;

  /// Os arquivos do pacote do aplicativo — o texto do termo.
  final Future<String> Function(String caminho)? lerArquivo;

  @override
  State<AplicativoDoPaciente> createState() => _AplicativoDoPacienteState();
}

class _AplicativoDoPacienteState extends State<AplicativoDoPaciente> {
  late final SessaoViewModel _sessao;
  late final ApiClient _api;

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
    _sessao = SessaoViewModel(autenticacao: widget.autenticacao, pacientes: RepositorioDoPacienteRemoto(_api))
      ..iniciar();
  }

  @override
  void dispose() {
    _sessao.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ServicoDeAutenticacao>.value(value: widget.autenticacao),
        Provider<AbridorDeLinks>.value(value: widget.abridor),
        Provider<RepositorioDoCatalogo>(create: (_) => RepositorioDoCatalogoRemoto(_api)),
        Provider<RepositorioDoPaciente>(create: (_) => RepositorioDoPacienteRemoto(_api)),
        Provider<RepositorioDoConsentimento>(create: (_) => RepositorioDoConsentimentoRemoto(_api)),
        ChangeNotifierProvider<SessaoViewModel>.value(value: _sessao),
      ],
      child: MaterialApp(
        title: Textos.nomeDoApp,
        theme: temaDoApp(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: PortaoDaSessao(lerArquivo: widget.lerArquivo ?? rootBundle.loadString),
      ),
    );
  }
}
