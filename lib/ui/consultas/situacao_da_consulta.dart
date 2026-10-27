import '../../domain/models/consulta.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';

/// Uma consulta como as telas a mostram: com o horário e o profissional, que a
/// lista e o detalhe da API sempre trazem.
typedef ConsultaNaLista = ({Consulta consulta, Horario horario, Profissional profissional});

/// O que a tela pode dizer e oferecer sobre uma consulta.
///
/// O status é sempre o que a API deu: nada aqui deduz pagamento (checklist,
/// item 1.5). O relógio só decide o que já passou — o prazo da reserva e o
/// começo do horário —, para a tela não oferecer o que não vale mais.
extension SituacaoDaConsulta on ConsultaNaLista {
  /// Aguardando pagamento, com o prazo da reserva já vencido. A API ainda não
  /// a expirou — a rotina dela roda a cada minuto —, e um pagamento feito no
  /// último minuto ainda pode confirmá-la.
  bool reservaVencida(DateTime agora) =>
      consulta.status == StatusDaConsulta.pendentePagamento &&
      switch (consulta.reservaExpiraEm) {
        final prazo? => !prazo.isAfter(agora),
        null => false,
      };

  /// Aguardando pagamento, com a reserva valendo.
  bool aguardandoPagamento(DateTime agora) =>
      consulta.status == StatusDaConsulta.pendentePagamento && !reservaVencida(agora);

  /// O horário da consulta já começou.
  bool comecou(DateTime agora) => !horario.inicio.isAfter(agora);

  /// Uma consulta que ainda vai acontecer: aguardando pagamento ou confirmada,
  /// antes do horário. É a lista "Próximas", e são as que se podem cancelar.
  bool ehProxima(DateTime agora) =>
      (aguardandoPagamento(agora) || consulta.status == StatusDaConsulta.confirmada) && !comecou(agora);

  /// Cancelar, com a devolução integral, vale só até o horário da consulta
  /// (decisão de 20/10/2026).
  bool podeCancelar(DateTime agora) => ehProxima(agora);

  /// A página de pagamento ainda pode ser aberta.
  bool podePagar(DateTime agora) => aguardandoPagamento(agora) && !comecou(agora);

  /// O próximo instante em que alguma das regras acima muda — o prazo da
  /// reserva ou o começo do horário —, para a tela se refazer nessa hora sem
  /// pedir nada à API. Null se nada mais muda.
  DateTime? proximaMudanca(DateTime agora) {
    final instantes = [
      if (consulta.status == StatusDaConsulta.pendentePagamento) ?consulta.reservaExpiraEm,
      if (consulta.status case StatusDaConsulta.pendentePagamento || StatusDaConsulta.confirmada) horario.inicio,
    ].where((instante) => instante.isAfter(agora));
    return instantes.isEmpty ? null : instantes.reduce((a, b) => a.isBefore(b) ? a : b);
  }
}
