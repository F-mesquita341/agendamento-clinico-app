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
  /// O nome do aplicativo, como o Android o mostra (android:label, no
  /// AndroidManifest.xml, tem de dizer o mesmo).
  static const nomeDoApp = 'Marcaí';

  static const carregando = 'Carregando…';

  /// Não afirma a causa: com o servidor fora do ar, a conexão também fica
  /// pendurada, e "acordando" seria mentira.
  static const servidorDemorando =
      'O servidor está demorando para responder. Se ele estava parado, o primeiro acesso pode levar até um minuto.';

  static const tentarDeNovo = 'Tentar de novo';
}

/// O mesmo texto, sem poder quebrar de linha nos espaços. Para o que se lê
/// inteiro ou não se lê: um valor não fica com o "R$" numa linha e os números
/// na outra.
String semQuebra(String texto) => texto.replaceAll(' ', '\u00a0');

/// O mesmo texto, com a primeira letra mai\u00fascula: as datas s\u00e3o escritas para
/// o meio de uma frase ("qui, 15/10"), e \u00e0s vezes come\u00e7am uma.
String comInicialMaiuscula(String texto) => texto.isEmpty ? texto : texto[0].toUpperCase() + texto.substring(1);
