import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_consentimento.dart';
import '../../data/repositories/repositorio_do_paciente.dart';
import '../cadastro/formulario_do_paciente_screen.dart';
import '../cadastro/formulario_do_paciente_view_model.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/marca.dart';
import '../conta/abertura_screen.dart';
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
///   sem sessão ............ a abertura (e dali, criar conta ou entrar); ou
///                           entrar direto, quando a sessão se perdeu
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
      EstadoDaSessao.iniciando => const _Iniciando(),
      EstadoDaSessao.carregandoPerfil => _Transicao(child: IndicadorDeCarga(demorando: sessao.demorando)),
      EstadoDaSessao.falhou => _Transicao(
          child: FalhaDeCarga(
            mensagem: sessao.erro!.mensagem,
            tentarDeNovo: sessao.carregarPerfil,
            outraSaida: (rotulo: 'Sair da conta', aoTocar: sessao.sair),
          ),
        ),
      EstadoDaSessao.semSessao => switch (sessao.motivoDaSaida) {
          // Quem estava dentro e perdeu a sessão vai direto a entrar, com o
          // motivo. A chave recria a tela quando o motivo muda, sem guardar o
          // que estava digitado de uma sessão para outra.
          final motivo? => EntrarScreen(key: ValueKey(motivo), aviso: motivo),
          // Primeiro uso, ou saiu por vontade própria.
          null => const AberturaScreen(),
        },
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

/// Carregando o perfil, ou a falha ao carregar: telas sem barra superior, sobre
/// o fundo claro.
///
/// Pede ícones escuros na barra de status do Android. A espera inicial e a
/// abertura, de fundo escuro, pedem ícones claros; uma tela sem barra superior
/// que não pedisse nada herdaria os claros, e o relógio sumiria no fundo.
class _Transicao extends StatelessWidget {
  const _Transicao({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(body: SafeArea(child: child)),
    );
  }
}

/// Enquanto o provedor não diz se há sessão: a marca, e que algo está vindo.
class _Iniciando extends StatelessWidget {
  const _Iniciando();

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    // Fundo escuro: os ícones da barra de status do Android ficam claros.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: cores.primary,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(Espaco.grande),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Marca(tamanho: 56),
                const SizedBox(height: Espaco.maior),
                CircularProgressIndicator(color: cores.onPrimary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
