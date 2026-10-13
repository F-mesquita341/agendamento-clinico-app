import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/servico_de_autenticacao.dart';
import '../../data/services/traducoes_da_autenticacao.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import 'campos.dart';
import 'criar_conta_screen.dart';
import 'envio_de_conta.dart';
import 'esqueci_a_senha_screen.dart';
import 'validacoes.dart';

/// Entrar na conta. É a raiz de quem está sem sessão: daqui se cria a conta e
/// se recupera a senha. Quando a entrada dá certo, a sessão muda e a raiz do
/// aplicativo troca a tela — esta tela não navega para lugar nenhum.
class EntrarScreen extends StatefulWidget {
  const EntrarScreen({super.key, this.aviso, this.emailInicial = ''});

  /// Por que a pessoa está aqui sem ter pedido — a sessão terminou.
  final String? aviso;

  /// O e-mail de quem chegou aqui vindo de criar a conta.
  final String emailInicial;

  @override
  State<EntrarScreen> createState() => _EntrarScreenState();
}

class _EntrarScreenState extends State<EntrarScreen> {
  final _formulario = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInicial);
  final _senha = TextEditingController();
  final _envio = EnvioDeConta();

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _envio.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    final autenticacao = context.read<ServicoDeAutenticacao>();
    await _envio.enviar(() => autenticacao.entrar(email: _email.text.trim(), senha: _senha.text));
  }

  Future<void> _criarConta() async {
    // Quem, ao criar a conta, descobre que o e-mail já tem cadastro — ou
    // lembra que já tem conta — volta para cá com ele preenchido. Voltar sem
    // e-mail nenhum não apaga o que já estava digitado aqui.
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => CriarContaScreen(emailInicial: _email.text.trim())),
    );
    if (email != null && email.isNotEmpty && mounted) _email.text = email;
  }

  void _esqueciASenha() {
    Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => EsqueciASenhaScreen(emailInicial: _email.text.trim())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _envio,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Entrar')),
        body: SafeArea(
          child: AutofillGroup(
            child: Form(
              key: _formulario,
              child: ListView(
                padding: const EdgeInsets.all(Espaco.margem),
                children: [
                  if (widget.aviso case final aviso?) ...[
                    Aviso(tipo: TipoDeRetorno.aviso, texto: aviso),
                    const SizedBox(height: Espaco.grande),
                  ],
                  Text(
                    'Entre para agendar e acompanhar suas consultas.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: Espaco.grande),
                  CampoDeEmail(
                    controlador: _email,
                    validar: validarEmail,
                    erro: _envio.erroDoEmail,
                    aoMudar: (_) => _envio.campoMudou(CampoDoErro.email),
                  ),
                  const SizedBox(height: Espaco.medio),
                  CampoDeSenha(
                    controlador: _senha,
                    validar: validarSenha,
                    nova: false,
                    erro: _envio.erroDaSenha,
                    aoMudar: (_) => _envio.campoMudou(CampoDoErro.senha),
                    aoConcluir: (_) => _entrar(),
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: BotaoDeTexto(rotulo: 'Esqueci minha senha', aoTocar: _esqueciASenha),
                  ),
                  const SizedBox(height: Espaco.pequeno),
                  if (_envio.erroGeral case final erro?) ...[
                    Aviso(tipo: TipoDeRetorno.erro, texto: erro),
                    const SizedBox(height: Espaco.medio),
                  ],
                  BotaoPrincipal(rotulo: 'Entrar', aoTocar: _entrar, enviando: _envio.enviando),
                  const SizedBox(height: Espaco.grande),
                  // Lado a lado quando cabe; um embaixo do outro com o texto ampliado.
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Ainda não tem conta?'),
                      BotaoDeTexto(rotulo: 'Criar conta', aoTocar: _criarConta),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
