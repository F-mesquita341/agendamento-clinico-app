import 'package:flutter/material.dart';

import '../../config/tema.dart';
import 'espaco.dart';

/// Os três tipos de retorno ao paciente. Cada um tem sempre a mesma cor, o
/// mesmo ícone e o mesmo componente, em qualquer tela (checklist, item 4.6),
/// e nunca depende só da cor: o ícone e o texto vão junto (item 8.7).
enum TipoDeRetorno { sucesso, aviso, erro }

/// Retorno passageiro, embaixo da tela: "Dados salvos", "Enviamos o e-mail".
///
/// Com [acao] — o "Ver" do lembrete que chega com o aplicativo aberto —, fica
/// até a pessoa tocar na ação ou no X: o que pede uma ação não tem prazo para
/// sumir (WCAG 2.2.1). No portão da Etapa 17, em 10 s ele sumiu antes do toque.
/// Os retornos sem ação somem sozinhos, em 4 s.
void mostrarRetorno(
  BuildContext context,
  TipoDeRetorno tipo,
  String texto, {
  ({String rotulo, VoidCallback aoTocar})? acao,
}) {
  final estilo = _EstiloDoRetorno.de(context, tipo);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: estilo.fundo,
      // A ação e o X vão no conteúdo, e não nos campos do SnackBar: ali eles
      // ficam sempre ao lado do texto (ver _LinhaComAcao).
      padding: acao == null ? null : const EdgeInsetsDirectional.only(start: Espaco.medio),
      content: acao == null
          ? _Linha(estilo: estilo, texto: texto)
          : _LinhaComAcao(estilo: estilo, texto: texto, acao: acao),
      persist: acao != null,
    ));
}

/// Retorno que fica na tela enquanto vale — "Não foi possível atualizar", o
/// aviso de sessão encerrada na tela de entrar.
class Aviso extends StatelessWidget {
  const Aviso({super.key, required this.tipo, required this.texto});

  final TipoDeRetorno tipo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    final estilo = _EstiloDoRetorno.de(context, tipo);
    return Container(
      decoration: BoxDecoration(color: estilo.fundo, borderRadius: BorderRadius.circular(16)),
      padding: const EdgeInsets.all(Espaco.medio),
      // liveRegion: o leitor de tela anuncia o aviso quando ele aparece.
      child: Semantics(liveRegion: true, child: _Linha(estilo: estilo, texto: texto)),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.estilo, required this.texto});

  final _EstiloDoRetorno estilo;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // O texto já diz tudo; o ícone é reforço visual e não é lido duas vezes.
        ExcludeSemantics(child: Icon(estilo.icone, color: estilo.frente)),
        const SizedBox(width: Espaco.pequeno),
        Expanded(child: Text(texto, style: TextStyle(color: estilo.frente))),
      ],
    );
  }
}

/// O texto, a ação e o X. Com a fonte grande, a ação e o X descem para baixo
/// do texto: lado a lado, a 200% num celular de 360 dp, o texto ficava numa
/// coluna de 130 dp, uma palavra por linha.
class _LinhaComAcao extends StatelessWidget {
  const _LinhaComAcao({required this.estilo, required this.texto, required this.acao});

  final _EstiloDoRetorno estilo;
  final String texto;
  final ({String rotulo, VoidCallback aoTocar}) acao;

  @override
  Widget build(BuildContext context) {
    final linha = Padding(
      padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
      child: _Linha(estilo: estilo, texto: texto),
    );
    final botoes = [
      SnackBarAction(label: acao.rotulo, textColor: estilo.frente, onPressed: acao.aoTocar),
      // O X padrão do SnackBar é claro, feito para a barra escura do Material:
      // sobre o fundo claro do aviso, sumiria. Este leva a cor do texto.
      IconButton(
        icon: const Icon(Icons.close),
        color: estilo.frente,
        tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(reason: SnackBarClosedReason.dismiss),
      ),
    ];
    if (MediaQuery.textScalerOf(context).scale(1) > 1.3) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsetsDirectional.only(end: Espaco.medio), child: linha),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: botoes),
        ],
      );
    }
    return Row(children: [Expanded(child: linha), ...botoes]);
  }
}

class _EstiloDoRetorno {
  const _EstiloDoRetorno(this.icone, this.fundo, this.frente);

  /// Pares de fundo e texto que o teste do tema confere a 4,5:1.
  factory _EstiloDoRetorno.de(BuildContext context, TipoDeRetorno tipo) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final retorno = tema.extension<CoresDeRetorno>()!;
    return switch (tipo) {
      TipoDeRetorno.sucesso =>
        _EstiloDoRetorno(Icons.check_circle_outline, retorno.sucesso.fundo, retorno.sucesso.texto),
      TipoDeRetorno.aviso => _EstiloDoRetorno(Icons.info_outline, retorno.aviso.fundo, retorno.aviso.texto),
      TipoDeRetorno.erro => _EstiloDoRetorno(Icons.error_outline, cores.errorContainer, cores.onErrorContainer),
    };
  }

  final IconData icone;
  final Color fundo;
  final Color frente;
}
