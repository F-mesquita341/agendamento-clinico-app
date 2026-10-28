import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../data/services/servico_de_notificacoes.dart';
import '../../domain/models/profissional.dart';
import '../busca/busca_screen.dart';
import '../busca/busca_view_model.dart';
import '../comum/retorno.dart';
import '../consultas/consultas_view_model.dart';
import '../consultas/minhas_consultas_screen.dart';
import '../inicio/inicio_screen.dart';
import '../lembretes/consulta_do_lembrete_screen.dart';
import '../lembretes/lembretes_view_model.dart';
import '../perfil/perfil_screen.dart';
import '../profissional/profissional_screen.dart';
import 'abas_do_shell.dart';

/// O aplicativo de quem tem conta e cadastro: a barra de navegação de baixo,
/// sempre com os mesmos itens, na mesma ordem — Início, Buscar, Minhas
/// consultas, Perfil (checklist, item 4.4).
///
/// As listas da busca e das consultas nascem aqui, com a sessão, e servem às
/// abas: o Início mostra as consultas e as especialidades da busca.
class ShellScreen extends StatefulWidget {
  const ShellScreen({super.key, required this.lerArquivo});

  final Future<String> Function(String caminho) lerArquivo;

  @override
  State<ShellScreen> createState() => _ShellScreenState();
}

class _ShellScreenState extends State<ShellScreen> with RouteAware {
  late final BuscaViewModel _busca;
  late final ConsultasViewModel _consultas;
  late final LembretesViewModel _lembretes;
  late final StreamSubscription<LembreteRecebido> _comOAppAberto;
  RouteObserver<PageRoute<dynamic>>? _rotas;

  @override
  void initState() {
    super.initState();
    context.read<AbasDoShell>().recomecar();
    _busca = BuscaViewModel(context.read<RepositorioDoCatalogo>())..carregar();
    _consultas = ConsultasViewModel(context.read<RepositorioDeConsultas>())..carregar();
    _lembretes = context.read<LembretesViewModel>()..addListener(_aoMudarLembretes);
    _comOAppAberto = _lembretes.recebidosComOAppAberto.listen(_mostrarLembrete);
    // O toque que abriu o aplicativo — ou que chegou antes de a conta abrir —
    // espera o shell: é ele que sabe abrir a consulta.
    _atenderToqueDepoisDoQuadro();
  }

  void _aoMudarLembretes() {
    if (_lembretes.toquePendente != null) _atenderToqueDepoisDoQuadro();
  }

  void _atenderToqueDepoisDoQuadro() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_lembretes.consumirToque() case final lembrete?) _abrirLembrete(lembrete.consultaId);
    });
  }

  /// O toque no lembrete abre a consulta (checklist, item 7.2) a partir do
  /// Início: o que estava aberto fecha, e voltar dos detalhes leva ao Início,
  /// como no modelo. Uma reserva deixada no pagamento continua lá, com "Pagar
  /// agora".
  void _abrirLembrete(int consultaId) {
    context.read<AbasDoShell>().mostrar(AbaDoShell.inicio);
    final navegador = Navigator.of(context)..popUntil((rota) => rota.isFirst);
    unawaited(navegador.push(rotaDoLembrete(consultaId)));
  }

  /// Com o aplicativo aberto, o Android não mostra o lembrete na bandeja: ele
  /// aparece aqui, com o texto da API, e "Ver" abre a consulta.
  void _mostrarLembrete(LembreteRecebido lembrete) {
    if (!mounted) return;
    mostrarRetorno(
      context,
      TipoDeRetorno.aviso,
      lembrete.texto ?? 'Você tem uma consulta chegando.',
      acao: (rotulo: 'Ver', aoTocar: () => _abrirLembrete(lembrete.consultaId)),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final rota = ModalRoute.of(context);
    if (_rotas == null && rota is PageRoute<dynamic>) {
      _rotas = context.read<RouteObserver<PageRoute<dynamic>>>()..subscribe(this, rota);
    }
  }

  /// Uma tela por cima do shell fechou — o agendamento, o pagamento, os
  /// detalhes —: as consultas podem ter mudado, e a lista é pedida de novo.
  /// Depois do quadro, e só com o shell ainda de pé: quando a sessão cai, o
  /// portão fecha as telas por cima — e é aí que este aviso chega — e, no
  /// quadro seguinte, troca o shell pela entrada. Um pedido sem sessão daria
  /// outro "sessão perdida".
  @override
  void didPopNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _consultas.atualizar();
    });
  }

  @override
  void dispose() {
    _lembretes.removeListener(_aoMudarLembretes);
    unawaited(_comOAppAberto.cancel());
    _rotas?.unsubscribe(this);
    _busca.dispose();
    _consultas.dispose();
    super.dispose();
  }

  /// Abre o profissional por cima da barra de baixo.
  void _abrir(BuildContext context, Profissional profissional) {
    Navigator.of(context).push(rotaDoProfissional(profissional));
  }

  @override
  Widget build(BuildContext context) {
    final abas = context.watch<AbasDoShell>();
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<BuscaViewModel>.value(value: _busca),
        ChangeNotifierProvider<ConsultasViewModel>.value(value: _consultas),
      ],
      child: PopScope(
        // Voltar, fora do Início, volta para ele; no Início, sai do aplicativo
        // — como o paciente espera no Android (checklist, item 3.8).
        canPop: abas.aba == AbaDoShell.inicio,
        onPopInvokedWithResult: (saiu, _) {
          if (!saiu) abas.mostrar(AbaDoShell.inicio);
        },
        child: Scaffold(
          // IndexedStack: cada aba guarda o próprio estado — a lista rolada, o
          // que estava carregado — ao trocar de aba.
          body: IndexedStack(
            index: abas.aba.index,
            children: [
              const InicioScreen(),
              BuscaScreen(aoAbrir: (profissional) => _abrir(context, profissional)),
              const MinhasConsultasScreen(),
              PerfilScreen(lerArquivo: widget.lerArquivo),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: abas.aba.index,
            onDestinationSelected: (indice) => abas.mostrar(AbaDoShell.values[indice]),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Início'),
              NavigationDestination(icon: Icon(Icons.search), label: 'Buscar'),
              NavigationDestination(
                icon: Icon(Icons.event_note_outlined),
                selectedIcon: Icon(Icons.event_note),
                label: 'Minhas consultas',
              ),
              NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }
}
