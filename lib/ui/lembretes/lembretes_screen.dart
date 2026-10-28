import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import 'lembretes_view_model.dart';

/// "Quer receber um lembrete?": logo depois do cadastro, explica o lembrete
/// antes da pergunta do sistema (checklist, item 10.5) — sem conta, não há
/// aparelho para registrar, e por isso não antes. Só aparece se a permissão
/// ainda não foi dada.
///
/// É a raiz do aplicativo enquanto aparece: voltar do Android vale como
/// "Agora não", e não fecha o aplicativo.
class LembretesScreen extends StatefulWidget {
  const LembretesScreen({super.key});

  @override
  State<LembretesScreen> createState() => _LembretesScreenState();
}

class _LembretesScreenState extends State<LembretesScreen> {
  bool _ativando = false;

  Future<void> _ativar() async {
    if (_ativando) return;
    setState(() => _ativando = true);
    final lembretes = context.read<LembretesViewModel>();
    final resultado = await lembretes.ativar();
    if (!mounted) return;
    final (tipo, texto) = switch (resultado) {
      ResultadoDaAtivacao.ativados => (TipoDeRetorno.sucesso, 'Lembretes ativados.'),
      ResultadoDaAtivacao.falhou => (
          TipoDeRetorno.aviso,
          'Não foi possível ativar os lembretes agora. O aplicativo tenta de novo quando você voltar.',
        ),
      ResultadoDaAtivacao.negada => (
          TipoDeRetorno.aviso,
          'Os lembretes ficaram desativados. Você pode ativar em Perfil.',
        ),
    };
    // Antes de a tela sair: o retorno fica com o mensageiro da raiz, e aparece
    // por cima do aplicativo.
    mostrarRetorno(context, tipo, texto);
    lembretes.explicacaoConcluida();
  }

  void _agoraNao() {
    if (_ativando) return;
    context.read<LembretesViewModel>().explicacaoConcluida();
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final fonteGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    final conteudo = [
      Center(
        child: Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(color: cores.primaryContainer, shape: BoxShape.circle),
          child: ExcludeSemantics(child: Icon(Icons.notifications_active_outlined, size: 32, color: cores.primary)),
        ),
      ),
      const SizedBox(height: Espaco.medio),
      Semantics(
        header: true,
        child: Text(
          'Quer receber um lembrete?',
          textAlign: TextAlign.center,
          style: tema.textTheme.headlineMedium!.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      const SizedBox(height: Espaco.medio),
      Text(
        'Um dia antes da consulta, o aplicativo avisa você. O lembrete diz só quando é a consulta: '
        'não mostra o profissional nem a especialidade.',
        textAlign: TextAlign.center,
        style: tema.textTheme.bodyLarge,
      ),
    ];
    final botoes = Column(
      spacing: Espaco.pequeno,
      children: [
        BotaoPrincipal(
          rotulo: 'Ativar lembretes',
          aoTocar: _ativar,
          enviando: _ativando,
          rotuloEnviando: 'Ativando…',
        ),
        BotaoDeTexto(rotulo: 'Agora não', aoTocar: _ativando ? null : _agoraNao),
      ],
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (saiu, _) {
        if (!saiu) _agoraNao();
      },
      // Sem barra superior, sobre o fundo claro: ícones escuros na barra de
      // status do Android.
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          body: SafeArea(
            child: fonteGrande
                ? ListView(
                    padding: const EdgeInsets.all(Espaco.margem),
                    children: [...conteudo, const SizedBox(height: Espaco.grande), botoes],
                  )
                : Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(Espaco.margem),
                            child: Column(children: conteudo),
                          ),
                        ),
                      ),
                      Padding(padding: const EdgeInsets.all(Espaco.medio), child: botoes),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
