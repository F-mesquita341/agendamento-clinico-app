import 'horario.dart';
import 'instante.dart';

/// Em que pé a consulta está, como a API diz — o aplicativo lê o status, nunca
/// o deduz (checklist, item 1.5).
enum StatusDaConsulta {
  pendentePagamento,
  confirmada,
  cancelada,
  realizada,
  naoCompareceu,

  /// Um status que esta versão do aplicativo não conhece. A API pode ganhar um
  /// status novo, e isso não pode derrubar a leitura das consultas.
  desconhecido;

  static StatusDaConsulta daApi(String valor) => switch (valor) {
        'pendente_pagamento' => pendentePagamento,
        'confirmada' => confirmada,
        'cancelada' => cancelada,
        'realizada' => realizada,
        'nao_compareceu' => naoCompareceu,
        _ => desconhecido,
      };

  /// A consulta ainda segura o horário: espera o pagamento, ou já foi paga.
  bool get seguraOHorario => this == pendentePagamento || this == confirmada;
}

/// Uma consulta do paciente — termo da linguagem ubíqua. Nasce quando o
/// horário é reservado, aguardando o pagamento antecipado.
class Consulta {
  const Consulta({
    required this.id,
    required this.status,
    required this.horarioId,
    required this.valorFormatado,
    this.reservaExpiraEm,
    this.horario,
  });

  factory Consulta.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final status = json['status'];
    final horarioId = json['horarioId'];
    final valor = json['valorFormatado'];
    final expira = json['reservaExpiraEm'];
    final horario = json['horario'];
    if (id is! int ||
        status is! String ||
        horarioId is! int ||
        valor is! String ||
        horario is! Map<String, Object?>?) {
      throw const FormatException('Consulta fora do formato esperado.');
    }
    return Consulta(
      id: id,
      status: StatusDaConsulta.daApi(status),
      horarioId: horarioId,
      valorFormatado: valor,
      reservaExpiraEm: expira == null ? null : instanteDaApi(expira),
      horario: horario == null ? null : Horario.fromJson(horario),
    );
  }

  final int id;
  final StatusDaConsulta status;
  final int horarioId;

  /// "R$ 250,00" — o valor congelado quando o horário foi reservado. Um
  /// reajuste do profissional depois disso não o muda.
  final String valorFormatado;

  /// Até quando a reserva espera o pagamento; depois disso a API recusa pagar,
  /// e o horário volta à grade. Só na consulta que ainda espera pagamento.
  final DateTime? reservaExpiraEm;

  /// O horário da consulta. Vem nas listagens; a resposta do agendamento não o
  /// traz, porque quem agendou já o tem.
  final Horario? horario;
}
