import 'package:flutter/material.dart';

/// Pede confirmação antes de uma ação séria (checklist, item 5.7). O botão
/// de confirmar diz a ação — "Sair da conta", "Descartar" —, nunca só "OK", e
/// fica à direita, como manda a convenção do Android (item 4.7).
///
/// Devolve true só se a pessoa confirmou; fechar o diálogo é desistir.
Future<bool> confirmar(
  BuildContext context, {
  required String titulo,
  required String texto,
  required String acao,
  String desistir = 'Cancelar',
  bool destrutiva = false,
}) async {
  final confirmou = await showDialog<bool>(
    context: context,
    builder: (contexto) {
      final cores = Theme.of(contexto).colorScheme;
      return AlertDialog(
        title: Text(titulo),
        content: Text(texto),
        actions: [
          TextButton(onPressed: () => Navigator.of(contexto).pop(false), child: Text(desistir)),
          TextButton(
            style: destrutiva ? TextButton.styleFrom(foregroundColor: cores.error) : null,
            onPressed: () => Navigator.of(contexto).pop(true),
            child: Text(acao),
          ),
        ],
      );
    },
  );
  return confirmou ?? false;
}

/// Protege um formulário preenchido: voltar — pelo botão da barra ou pelo
/// gesto do Android — pergunta antes de descartar o que a pessoa digitou
/// (checklist, item 3.6). Formulário vazio volta direto.
class ProtecaoDeAlteracoes extends StatelessWidget {
  const ProtecaoDeAlteracoes({super.key, required this.haAlteracoes, required this.child});

  final bool haAlteracoes;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: !haAlteracoes,
      onPopInvokedWithResult: (saiu, resultado) async {
        if (saiu) return;
        final descartar = await confirmar(
          context,
          titulo: 'Descartar alterações?',
          texto: 'O que você preencheu nesta tela será perdido.',
          acao: 'Descartar',
          desistir: 'Continuar editando',
        );
        if (descartar && context.mounted) Navigator.of(context).pop(resultado);
      },
      child: child,
    );
  }
}
