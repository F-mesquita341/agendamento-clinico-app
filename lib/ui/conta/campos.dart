import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Campo de e-mail: rótulo que não some ao digitar (checklist, item 6.8),
/// teclado de e-mail e preenchimento automático (item 5.5).
class CampoDeEmail extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      decoration: const InputDecoration(labelText: 'E-mail'),
      keyboardType: TextInputType.emailAddress,
      autofillHints: const [AutofillHints.email],
      autocorrect: false,
      textInputAction: acaoDoTeclado,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validar,
      forceErrorText: erro,
      onChanged: aoMudar,
      onFieldSubmitted: aoConcluir,
      // Espaço digitado sem querer no fim não pode virar "e-mail inválido".
      inputFormatters: [FilteringTextInputFormatter.deny(RegExp(r'\s'))],
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
