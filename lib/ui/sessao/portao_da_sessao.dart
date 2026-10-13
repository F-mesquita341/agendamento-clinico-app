import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_consentimento.dart';
import '../../data/repositories/repositorio_do_paciente.dart';
import '../cadastro/formulario_do_paciente_screen.dart';
import '../cadastro/formulario_do_paciente_view_model.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../conta/entrar_screen.dart';
import '../shell/shell_screen.dart';
import '../termo/termo_screen.dart';
import '../termo/termo_view_model.dart';
import 'sessao_view_model.dart';

/// As três áreas do aplicativo. Trocar de área recomeça a navegação.
enum _Area { transicao, entrada, cadastro, aplicativo }

/// A raiz do aplicativo: a guarda de rota da Etapa 12. Decide a tela pelo
/// estado da sessão, sem roteador:
///
///   sem sessão ............ entrar (e dali, criar conta, recuperar a senha)
///   com sessão, sem perfil  termo, e então completar o cadastro
///   com sessão e perfil ... o aplicativo
///
/// Quando a área muda, as telas abertas por cima são fechadas: depois de
/// cadastrar, voltar não leva ao formulário; depois de sair, não leva ao
/// perfil (checklist, itens 3.3 e 3.8).
class PortaoDaSessao extends StatefulWidget {
  const PortaoDaSessao({super.key, required this.lerArquivo});

  /// Os arquivos do termo, por caminho — o pacote do aplicativo, ou o disco
  /// nos testes.
  final Future<String> Function(String caminho) lerArquivo;

  @override
  State<PortaoDaSessao> createState() => _PortaoDaSessaoState();
}

class _PortaoDaSessaoState extends State<PortaoDaSessao> {
  late final SessaoViewModel _sessao;
  late _Area _area;

  static _Area _areaDe(EstadoDaSessao estado) => switch (estado) {
        EstadoDaSessao.semSessao => _Area.entrada,
        EstadoDaSessao.semPerfil => _Area.cadastro,
        EstadoDaSessao.comPerfil => _Area.aplicativo,
        EstadoDaSessao.iniciando || EstadoDaSessao.carregandoPerfil || EstadoDaSessao.falhou => _Area.transicao,
      };

  @override
  void initState() {
    super.initState();
    _sessao = context.read<SessaoViewModel>();
    // A área de partida é lida agora, na criação. Lida só na primeira mudança,
    // ela já seria a área nova, e essa primeira troca não fecharia nada.
    _area = _areaDe(_sessao.estado);
    _sessao.addListener(_aoMudarSessao);
  }

  @override
  void dispose() {
    _sessao.removeListener(_aoMudarSessao);
    super.dispose();
  }

  void _aoMudarSessao() {
    final area = _areaDe(_sessao.estado);
    if (area == _area) return;
    _area = area;
    // Fecha tudo o que foi aberto por cima da raiz na área anterior.
    Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  void _continuarCadastro(BuildContext contexto, TermoViewModel termo, String versao) {
    final pacientes = contexto.read<RepositorioDoPaciente>();
    Navigator.of(contexto).push<void>(MaterialPageRoute(
      builder: (rota) => FormularioDoPacienteScreen(
        criarVm: () => FormularioDoPacienteViewModel.cadastro(pacientes, versaoDoTermo: versao),
        email: _sessao.usuario?.email ?? '',
        // A sessão passa a ter perfil, a área muda, e o portão leva ao
        // aplicativo fechando o formulário e o termo.
        aoConcluir: _sessao.perfilCadastrado,
        aoTermoMudar: () {
          Navigator.of(rota).pop();
          termo.carregar();
        },
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<SessaoViewModel>();
    return switch (sessao.estado) {
      EstadoDaSessao.iniciando => const _Abertura(),
      EstadoDaSessao.carregandoPerfil => Scaffold(body: SafeArea(child: IndicadorDeCarga(demorando: sessao.demorando))),
      EstadoDaSessao.falhou => Scaffold(
          body: SafeArea(
            child: FalhaDeCarga(
              mensagem: sessao.erro!.mensagem,
              tentarDeNovo: sessao.carregarPerfil,
              outraSaida: (rotulo: 'Sair da conta', aoTocar: sessao.sair),
            ),
          ),
        ),
      // A chave pelo motivo recria a tela quando ele muda, sem guardar o que
      // estava digitado de uma sessão para outra.
      EstadoDaSessao.semSessao => EntrarScreen(key: ValueKey(sessao.motivoDaSaida), aviso: sessao.motivoDaSaida),
      EstadoDaSessao.semPerfil => ChangeNotifierProvider(
          create: (contexto) => TermoViewModel(
            contexto.read<RepositorioDoConsentimento>(),
            lerArquivo: widget.lerArquivo,
          )..carregar(),
          child: Builder(
            builder: (contexto) => TermoScreen(
              aoContinuar: (versao) => _continuarCadastro(contexto, contexto.read<TermoViewModel>(), versao),
              aoSair: sessao.sair,
            ),
          ),
        ),
      EstadoDaSessao.comPerfil => ShellScreen(lerArquivo: widget.lerArquivo),
    };
  }
}

class _Abertura extends StatelessWidget {
  const _Abertura();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(Espaco.grande),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.event_available_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: Espaco.medio),
              Text('Agendamento Clínico', style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: Espaco.grande),
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
