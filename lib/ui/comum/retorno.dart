import 'package:flutter/material.dart';

import 'espaco.dart';

/// Os três tipos de retorno ao paciente. Cada um tem sempre a mesma cor, o
/// mesmo ícone e o mesmo componente, em qualquer tela (checklist, item 4.6),
/// e nunca depende só da cor: o ícone e o texto vão junto (item 8.7).
enum TipoDeRetorno { sucesso, aviso, erro }

/// Retorno passageiro, embaixo da tela: "Dados salvos", "Enviamos o e-mail".
void mostrarRetorno(BuildContext context, TipoDeRetorno tipo, String texto) {
  final estilo = _EstiloDoRetorno.de(context, tipo);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: estilo.fundo,
      content: _Linha(estilo: estilo, texto: texto),
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
      color: estilo.fundo,
      padding: const EdgeInsets.symmetric(horizontal: Espaco.margem, vertical: Espaco.medio),
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

class _EstiloDoRetorno {
  const _EstiloDoRetorno(this.icone, this.fundo, this.frente);

  /// Pares de fundo e texto que o teste do tema confere a 4,5:1.
  factory _EstiloDoRetorno.de(BuildContext context, TipoDeRetorno tipo) {
    final cores = Theme.of(context).colorScheme;
    return switch (tipo) {
      TipoDeRetorno.sucesso =>
        _EstiloDoRetorno(Icons.check_circle_outline, cores.secondaryContainer, cores.onSecondaryContainer),
      TipoDeRetorno.aviso => _EstiloDoRetorno(Icons.info_outline, cores.primaryContainer, cores.onPrimaryContainer),
      TipoDeRetorno.erro => _EstiloDoRetorno(Icons.error_outline, cores.errorContainer, cores.onErrorContainer),
    };
  }

  final IconData icone;
  final Color fundo;
  final Color frente;
}
