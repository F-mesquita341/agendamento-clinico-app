import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/servico_de_autenticacao.dart';
import '../../data/services/traducoes_da_autenticacao.dart';
import '../comum/botoes.dart';
import '../comum/confirmacao.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import 'campos.dart';
import 'envio_de_conta.dart';
import 'esqueci_a_senha_screen.dart';
import 'validacoes.dart';

/// Criar a conta, com e-mail e senha. Criada, o provedor já entra nela, e a
/// raiz do aplicativo leva ao termo e ao cadastro.
///
/// Sem campo de "confirmar senha": o botão de mostrar a senha cumpre o papel
/// com menos atrito (decisão da Etapa 12).
class CriarContaScreen extends StatefulWidget {
  const CriarContaScreen({super.key, this.emailInicial = ''});

  final String emailInicial;

  @override
  State<CriarContaScreen> createState() => _CriarContaScreenState();
}

class _CriarContaScreenState extends State<CriarContaScreen> {
  final _formulario = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInicial);
  final _senha = TextEditingController();
  final _envio = EnvioDeConta();
  late final _mudancas = Listenable.merge([_envio, _email, _senha]);

  @override
  void dispose() {
    _email.dispose();
    _senha.dispose();
    _envio.dispose();
    super.dispose();
  }

  Future<void> _criar() async {
    if (!_formulario.currentState!.validate()) return;
    final autenticacao = context.read<ServicoDeAutenticacao>();
    await _envio.enviar(() => autenticacao.criarConta(email: _email.text.trim(), senha: _senha.text));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mudancas,
      builder: (context, _) {
        final emailJaCadastrado = _envio.codigoDoErro == 'email-already-in-use';
        return ProtecaoDeAlteracoes(
          // O e-mail que veio da tela de entrar não conta como alteração.
          haAlteracoes: _email.text.trim() != widget.emailInicial || _senha.text.isNotEmpty,
          child: Scaffold(
            appBar: AppBar(title: const Text('Criar conta')),
            body: SafeArea(
              child: AutofillGroup(
                child: Form(
                  key: _formulario,
                  child: ListView(
                    padding: const EdgeInsets.all(Espaco.margem),
                    children: [
                      Text(
                        'Crie sua conta com e-mail e senha. Em seguida, você lê o termo de consentimento e completa o cadastro.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: Espaco.grande),
                      CampoDeEmail(
                        controlador: _email,
                        validar: validarEmail,
                        erro: _envio.erroDoEmail,
                        aoMudar: (_) => _envio.campoMudou(CampoDoErro.email),
                      ),
                      if (emailJaCadastrado)
                        Wrap(
                          spacing: Espaco.pequeno,
                          children: [
                            BotaoDeTexto(
                              rotulo: 'Entrar com este e-mail',
                              aoTocar: () => Navigator.of(context).pop(_email.text.trim()),
                            ),
                            BotaoDeTexto(
                              rotulo: 'Recuperar a senha',
                              aoTocar: () => Navigator.of(context).push<void>(MaterialPageRoute(
                                builder: (_) => EsqueciASenhaScreen(emailInicial: _email.text.trim()),
                              )),
                            ),
                          ],
                        ),
                      const SizedBox(height: Espaco.medio),
                      CampoDeSenha(
                        controlador: _senha,
                        validar: validarSenhaNova,
                        nova: true,
                        regra: 'Mínimo de $tamanhoMinimoDaSenha caracteres.',
                        erro: _envio.erroDaSenha,
                        aoMudar: (_) => _envio.campoMudou(CampoDoErro.senha),
                        aoConcluir: (_) => _criar(),
                      ),
                      const SizedBox(height: Espaco.grande),
                      if (_envio.erroGeral case final erro?) ...[
                        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
                        const SizedBox(height: Espaco.medio),
                      ],
                      BotaoPrincipal(rotulo: 'Criar conta', aoTocar: _criar, enviando: _envio.enviando),
                      const SizedBox(height: Espaco.pequeno),
                      // Devolve o e-mail a quem abriu esta tela, que leva a entrar
                      // com ele. Por maybePop: com o formulário preenchido, a
                      // pergunta de descartar vem antes.
                      BotaoDeTexto(
                        rotulo: 'Já tenho conta',
                        aoTocar: () => Navigator.of(context).maybePop(_email.text.trim()),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
