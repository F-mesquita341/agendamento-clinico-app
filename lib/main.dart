import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'config/ambiente.dart';
import 'config/tema.dart';
import 'data/repositories/repositorio_do_catalogo.dart';
import 'data/services/api_client.dart';
import 'ui/especialidades/especialidades_screen.dart';
import 'ui/especialidades/especialidades_view_model.dart';

void main() {
  runApp(const AplicativoDoPaciente());
}

class AplicativoDoPaciente extends StatelessWidget {
  const AplicativoDoPaciente({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>(
          create: (_) => ApiClient(cliente: http.Client(), base: Uri.parse(urlDaApi)),
        ),
        Provider<RepositorioDoCatalogo>(
          create: (contexto) => RepositorioDoCatalogoRemoto(contexto.read<ApiClient>()),
        ),
      ],
      child: MaterialApp(
        title: 'Agendamento Clínico',
        theme: temaDoApp(),
        locale: const Locale('pt', 'BR'),
        supportedLocales: const [Locale('pt', 'BR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: ChangeNotifierProvider(
          create: (contexto) => EspecialidadesViewModel(contexto.read<RepositorioDoCatalogo>())..carregar(),
          child: const EspecialidadesScreen(),
        ),
      ),
    );
  }
}
