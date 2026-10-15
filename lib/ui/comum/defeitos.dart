import 'dart:async';

import 'package:flutter/foundation.dart';

/// Rede de segurança: um erro que não veio da API é defeito do aplicativo.
/// Ele é relatado — nos testes, isso faz o teste cair — e quem chamou mostra
/// uma mensagem, em vez de deixar a tela girando para sempre.
void relatarDefeito(Object erro, StackTrace pilha, String quando) {
  FlutterError.reportError(FlutterErrorDetails(
    exception: erro,
    stack: pilha,
    library: 'agendamento_clinico',
    context: ErrorDescription(quando),
  ));
}

/// Avisa quando uma espera passa do razoável — o servidor gratuito hiberna, e
/// o primeiro pedido depois disso leva perto de um minuto (heurística 1 de
/// Nielsen: sem o aviso, a espera parece travamento). Não afirma a causa.
class AvisoDeDemora {
  AvisoDeDemora({required this.espera, required this.aoMudar});

  /// Quanto esperar antes de avisar.
  final Duration espera;

  /// Chamado quando o aviso passa a valer, para quem o mostra se atualizar.
  final VoidCallback aoMudar;

  Timer? _relogio;
  bool _demorando = false;

  bool get demorando => _demorando;

  /// Começa a contar de novo, descartando a contagem anterior.
  void iniciar() {
    parar();
    _relogio = Timer(espera, () {
      _demorando = true;
      aoMudar();
    });
  }

  /// A espera acabou: o aviso some. Não avisa quem mostra — quem para é quem
  /// sabe o que mudou, e avisa junto.
  void parar() {
    _relogio?.cancel();
    _relogio = null;
    _demorando = false;
  }

  int _noAr = 0;
  int _rodada = 0;

  /// Acompanha um pedido que pode estar no ar junto com outros — atualizar a
  /// lista enquanto a página seguinte carrega, por exemplo. A contagem começa
  /// no primeiro, e o aviso só some quando o último termina: um pedido rápido
  /// não apaga o aviso de outro que ainda espera. Quem chamou avisa a tela
  /// depois, como com [parar].
  Future<T> acompanhar<T>(Future<T> Function() pedido) async {
    final rodada = _rodada;
    if (_noAr++ == 0) iniciar();
    try {
      return await pedido();
    } finally {
      if (rodada == _rodada && --_noAr == 0) parar();
    }
  }

  /// Os pedidos acompanhados até aqui deixam de contar: as respostas deles vão
  /// ser descartadas, e o aviso não fica à vista por causa delas.
  void esquecerPedidos() {
    _rodada++;
    _noAr = 0;
    parar();
  }
}
