import 'package:flutter/material.dart';

import 'espaco.dart';

/// Os botões do aplicativo, um para cada papel (checklist, item 4.2). A ação
/// principal de uma tela é sempre um [BotaoPrincipal], em largura total, e só
/// existe uma por tela (item 8.1).
class BotaoPrincipal extends StatelessWidget {
  const BotaoPrincipal({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.enviando = false,
    this.rotuloEnviando,
  });

  final String rotulo;
  final VoidCallback? aoTocar;

  /// Enquanto envia, o botão fica desabilitado e mostra um indicador no lugar
  /// do texto (checklist, item 1.2): o segundo toque não dispara um segundo
  /// pedido, e a pessoa vê que o primeiro foi recebido.
  final bool enviando;

  /// O que o botão diz enquanto envia, ao lado do indicador — "Reservando o
  /// horário…" —, quando a espera merece ser dita. Sem ele, só o indicador.
  final String? rotuloEnviando;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: enviando ? null : aoTocar,
        child: _Conteudo(rotulo: rotulo, enviando: enviando, rotuloEnviando: rotuloEnviando),
      ),
    );
  }
}

/// Alternativa à ação principal, logo abaixo dela.
class BotaoSecundario extends StatelessWidget {
  const BotaoSecundario({super.key, required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(onPressed: aoTocar, child: Text(rotulo, textAlign: TextAlign.center)),
    );
  }
}

/// Ação que encerra ou desfaz algo — sair da conta, cancelar a consulta. Tem a
/// cor de erro, e leva o nome da ação (checklist, item 5.7). Pede confirmação
/// antes: quem chama é que abre o diálogo.
class BotaoDestrutivo extends StatelessWidget {
  const BotaoDestrutivo({
    super.key,
    required this.rotulo,
    required this.aoTocar,
    this.enviando = false,
    this.rotuloEnviando,
  });

  final String rotulo;
  final VoidCallback? aoTocar;

  /// Como no [BotaoPrincipal]: enquanto envia, o botão fica desabilitado e
  /// mostra o indicador — "Cancelando…" —, e o segundo toque não faz pedido.
  final bool enviando;
  final String? rotuloEnviando;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: cores.error,
          side: BorderSide(color: cores.error, width: 1.5),
        ),
        onPressed: enviando ? null : aoTocar,
        child: _Conteudo(rotulo: rotulo, enviando: enviando, rotuloEnviando: rotuloEnviando),
      ),
    );
  }
}

/// Ação leve: um link para outra tela ("Esqueci minha senha", "Criar conta").
class BotaoDeTexto extends StatelessWidget {
  const BotaoDeTexto({super.key, required this.rotulo, required this.aoTocar});

  final String rotulo;
  final VoidCallback? aoTocar;

  @override
  Widget build(BuildContext context) {
    return TextButton(onPressed: aoTocar, child: Text(rotulo, textAlign: TextAlign.center));
  }
}

class _Conteudo extends StatelessWidget {
  const _Conteudo({required this.rotulo, required this.enviando, this.rotuloEnviando});

  final String rotulo;
  final bool enviando;
  final String? rotuloEnviando;

  static const _indicador = SizedBox.square(
    dimension: 20,
    child: CircularProgressIndicator(strokeWidth: 2.5),
  );

  @override
  Widget build(BuildContext context) {
    if (!enviando) return Text(rotulo, textAlign: TextAlign.center);
    final dizendo = rotuloEnviando;
    if (dizendo != null) {
      // O texto já diz que o botão está ocupado, e é ele que o leitor de tela lê.
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Espaco.pequeno + 4,
        children: [
          const ExcludeSemantics(child: _indicador),
          Flexible(child: Text(dizendo, textAlign: TextAlign.center)),
        ],
      );
    }
    // O leitor de tela continua sabendo que botão é, e que está ocupado.
    return Semantics(label: '$rotulo, enviando', child: _indicador);
  }
}
