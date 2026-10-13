import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/servico_de_autenticacao.dart';
import '../../data/services/traducoes_da_autenticacao.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import 'campos.dart';
import 'envio_de_conta.dart';
import 'validacoes.dart';

/// Pedir um link para criar uma senha nova (checklist, item 3.10).
///
/// A confirmação é a mesma exista ou não a conta: dizer "esse e-mail não tem
/// cadastro" revelaria quem tem.
class EsqueciASenhaScreen extends StatefulWidget {
  const EsqueciASenhaScreen({super.key, this.emailInicial = ''});

  final String emailInicial;

  @override
  State<EsqueciASenhaScreen> createState() => _EsqueciASenhaScreenState();
}

class _EsqueciASenhaScreenState extends State<EsqueciASenhaScreen> {
  final _formulario = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.emailInicial);
  final _envio = EnvioDeConta();
  String? _enviadoPara;

  @override
  void dispose() {
    _email.dispose();
    _envio.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) return;
    final autenticacao = context.read<ServicoDeAutenticacao>();
    final email = _email.text.trim();
    if (await _envio.enviar(() => autenticacao.enviarRedefinicaoDeSenha(email)) && mounted) {
      setState(() => _enviadoPara = email);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _envio,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('Recuperar a senha')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(Espaco.margem),
            children: [
              if (_enviadoPara case final email?) ...[
                Aviso(
                  tipo: TipoDeRetorno.sucesso,
                  texto: 'Se houver uma conta com $email, você vai receber um link para criar uma senha nova. '
                      'Confira a caixa de entrada e também a de spam.',
                ),
                const SizedBox(height: Espaco.grande),
                BotaoPrincipal(rotulo: 'Voltar para entrar', aoTocar: () => Navigator.of(context).pop()),
              ] else
                Form(
                  key: _formulario,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Informe o e-mail da sua conta. Enviaremos um link para você criar uma senha nova.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: Espaco.grande),
                      CampoDeEmail(
                        controlador: _email,
                        validar: validarEmail,
                        erro: _envio.erroDoEmail,
                        aoMudar: (_) => _envio.campoMudou(CampoDoErro.email),
                        acaoDoTeclado: TextInputAction.done,
                        aoConcluir: (_) => _enviar(),
                      ),
                      const SizedBox(height: Espaco.grande),
                      if (_envio.erroGeral case final erro?) ...[
                        Aviso(tipo: TipoDeRetorno.erro, texto: erro),
                        const SizedBox(height: Espaco.medio),
                      ],
                      BotaoPrincipal(rotulo: 'Enviar link', aoTocar: _enviar, enviando: _envio.enviando),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
