import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../domain/models/profissional.dart';
import '../busca/busca_screen.dart';
import '../busca/busca_view_model.dart';
import '../perfil/perfil_screen.dart';
import '../profissional/horarios_view_model.dart';
import '../profissional/profissional_screen.dart';

/// O aplicativo de quem tem conta e cadastro: a barra de navegação de baixo,
/// sempre com os mesmos itens, na mesma ordem (checklist, item 4.4). Início e
/// Minhas consultas entram na Etapa 16, sem mudar a ordem dos que já existem.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.lerArquivo});

  final Future<String> Function(String caminho) lerArquivo;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> {
  int _aba = 0;

  /// Abre o profissional por cima da barra de baixo. O view model da tela
  /// nasce aqui, com quem a abre: na Etapa 14, o resumo da consulta volta para
  /// ela com o dia e o horário ainda escolhidos (checklist, item 3.1).
  void _abrir(BuildContext context, Profissional profissional) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => ChangeNotifierProvider(
        create: (contexto) => HorariosViewModel(contexto.read<RepositorioDoCatalogo>(), profissional)..carregar(),
        child: const ProfissionalScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Voltar, fora da primeira aba, volta para ela; na primeira, sai do
      // aplicativo — como o paciente espera no Android (checklist, item 3.8).
      canPop: _aba == 0,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) setState(() => _aba = 0);
      },
      child: Scaffold(
        // IndexedStack: cada aba guarda o próprio estado — a lista rolada, o
        // que estava carregado — ao trocar de aba.
        body: IndexedStack(
          index: _aba,
          children: [
            ChangeNotifierProvider(
              create: (contexto) => BuscaViewModel(contexto.read<RepositorioDoCatalogo>())..carregar(),
              child: BuscaScreen(aoAbrir: (profissional) => _abrir(context, profissional)),
            ),
            PerfilScreen(lerArquivo: widget.lerArquivo),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _aba,
          onDestinationSelected: (aba) => setState(() => _aba = aba),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
            NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}
