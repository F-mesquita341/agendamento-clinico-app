/// Textos que aparecem em mais de uma tela.
///
/// O glossário da interface (checklist, item 2.2) vale para todo texto do
/// aplicativo, esteja aqui ou na própria tela:
///
/// - consulta — nunca "atendimento" ou "agendamento" para a mesma coisa;
/// - horário — nunca "slot" ou "vaga";
/// - especialidade, profissional;
/// - reserva — o horário guardado enquanto o pagamento não se confirma;
/// - pagamento antecipado — nunca "caução" nem "sinal".
abstract final class Textos {
  static const carregando = 'Carregando…';

  /// Não afirma a causa: com o servidor fora do ar, a conexão também fica
  /// pendurada, e "acordando" seria mentira.
  static const servidorDemorando =
      'O servidor está demorando para responder. Se ele estava parado, o primeiro acesso pode levar até um minuto.';

  static const tentarDeNovo = 'Tentar de novo';
}
