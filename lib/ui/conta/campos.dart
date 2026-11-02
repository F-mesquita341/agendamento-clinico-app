import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de e-mail: rótulo que não some ao digitar (checklist, item 6.8),
/// teclado de e-mail e preenchimento automático (item 5.5).
///
/// O erro espera a pessoa sair do campo: enquanto ela digita pela primeira
/// vez, "ana@" é o começo de um endereço, e não um erro — no portão da Etapa
/// 18, o vermelho aparecia na primeira letra. Depois que ela sai, o campo
/// confere a cada tecla, e o erro some assim que o endereço fica certo. O
/// botão de enviar confere tudo, como antes.
class CampoDeEmail extends StatefulWidget {
  const CampoDeEmail({
    super.key,
    required this.controlador,
    required this.validar,
    this.erro,
    this.aoMudar,
    this.acaoDoTeclado = TextInputAction.next,
    this.aoConcluir,
  });

  final TextEditingController controlador;
  final FormFieldValidator<String> validar;

  /// Erro vindo do provedor de identidade: aparece no lugar do da validação.
  final String? erro;
  final ValueChanged<String>? aoMudar;
  final TextInputAction acaoDoTeclado;
  final ValueChanged<String>? aoConcluir;

  @override
  State<CampoDeEmail> createState() => _CampoDeEmailState();
}

class _CampoDeEmailState extends State<CampoDeEmail> {
  /// Se a pessoa já saiu do campo com algo escrito. Sair dele vazio não é
  /// erro ainda: "Informe o e-mail" fica para o botão de enviar.
  bool _saiu = false;

  void _aoMudarOFoco(bool focado) {
    if (!focado && !_saiu && widget.controlador.text.isNotEmpty) setState(() => _saiu = true);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: _aoMudarOFoco,
      child: TextFormField(
        controller: widget.controlador,
        decoration: const InputDecoration(labelText: 'E-mail'),
        keyboardType: TextInputType.emailAddress,
        autofillHints: const [AutofillHints.email],
        autocorrect: false,
        textInputAction: widget.acaoDoTeclado,
        autovalidateMode: _saiu ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
        validator: widget.validar,
        forceErrorText: widget.erro,
        onChanged: widget.aoMudar,
        onFieldSubmitted: widget.aoConcluir,
        // Espaço digitado sem querer no fim não pode virar "e-mail inválido".
        inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
      ),
    );
  }
}

/// Campo de senha, com o botão de mostrar e ocultar (checklist, item 5.6) e,
/// para quem cria a senha, a regra visível antes de qualquer erro.
class CampoDeSenha extends StatefulWidget {
  const CampoDeSenha({
    super.key,
    required this.controlador,
    required this.validar,
    required this.nova,
    this.regra,
    this.erro,
    this.aoMudar,
    this.aoConcluir,
  });

  final TextEditingController controlador;
  final FormFieldValidator<String> validar;

  /// Senha que está sendo criada: o preenchimento automático sugere uma nova.
  final bool nova;

  /// A regra da senha, mostrada embaixo do campo antes de qualquer erro.
  final String? regra;
  final String? erro;
  final ValueChanged<String>? aoMudar;
  final ValueChanged<String>? aoConcluir;

  @override
  State<CampoDeSenha> createState() => _CampoDeSenhaState();
}

class _CampoDeSenhaState extends State<CampoDeSenha> {
  bool _visivel = false;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controlador,
      decoration: InputDecoration(
        labelText: 'Senha',
        helperText: widget.regra,
        helperMaxLines: 2,
        suffixIcon: IconButton(
          tooltip: _visivel ? 'Ocultar senha' : 'Mostrar senha',
          icon: Icon(_visivel ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visivel = !_visivel),
        ),
      ),
      // Sem keyboardType: com obscureText, o teclado recebe a variação de
      // senha. Um visiblePassword aqui se sobreporia a ela, e o teclado
      // trataria a senha oculta como texto visível.
      obscureText: !_visivel,
      autocorrect: false,
      enableSuggestions: false,
      autofillHints: [widget.nova ? AutofillHints.newPassword : AutofillHints.password],
      textInputAction: TextInputAction.done,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: widget.validar,
      forceErrorText: widget.erro,
      onChanged: widget.aoMudar,
      onFieldSubmitted: widget.aoConcluir,
    );
  }
}
