import 'forma_de_pagamento.dart';
import 'horario.dart';
import 'instante.dart';
import 'plano.dart';
import 'profissional.dart';

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

/// Por que a consulta foi cancelada, como a API diz: a pessoa cancelou, ou o
/// prazo para pagar a reserva terminou — "você cancelou" não é "o prazo
/// acabou" (checklist, item 1.7).
enum MotivoDoCancelamento {
  paciente,
  reservaExpirada,

  /// Um motivo que esta versão do aplicativo não conhece.
  outro;

  static MotivoDoCancelamento? daApi(Object? valor) => switch (valor) {
        null => null,
        'paciente' => paciente,
        'reserva_expirada' => reservaExpirada,
        _ => outro,
      };
}

/// Uma consulta do paciente — termo da linguagem ubíqua. Nasce quando o
/// horário é reservado: aguardando o pagamento antecipado, se ele é pelo
/// aplicativo, ou já confirmada, com o plano de saúde ou na clínica (versão 2).
class Consulta {
  const Consulta({
    required this.id,
    required this.status,
    required this.horarioId,
    required this.valorFormatado,
    this.motivoDoCancelamento,
    this.reservaExpiraEm,
    this.horario,
    this.profissional,
    this.formaDePagamento = FormaDePagamento.app,
    this.plano,
  });

  factory Consulta.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final status = json['status'];
    final motivo = json['motivoCancelamento'];
    final horarioId = json['horarioId'];
    final valor = json['valorFormatado'];
    final expira = json['reservaExpiraEm'];
    final horario = json['horario'];
    final profissional = json['profissional'];
    final forma = json['formaDePagamento'];
    final plano = json['plano'];
    if (id is! int ||
        status is! String ||
        motivo is! String? ||
        horarioId is! int ||
        valor is! String ||
        horario is! Map<String, Object?>? ||
        profissional is! Map<String, Object?>? ||
        forma is! String? ||
        plano is! Map<String, Object?>?) {
      throw const FormatException('Consulta fora do formato esperado.');
    }
    return Consulta(
      id: id,
      status: StatusDaConsulta.daApi(status),
      motivoDoCancelamento: MotivoDoCancelamento.daApi(motivo),
      horarioId: horarioId,
      valorFormatado: valor,
      reservaExpiraEm: expira == null ? null : instanteDaApi(expira),
      horario: horario == null ? null : Horario.fromJson(horario),
      profissional: profissional == null ? null : Profissional.fromJson(profissional),
      // Ausente — a API de produção, a v1 — ou desconhecida: o aplicativo.
      formaDePagamento: (forma == null ? null : FormaDePagamento.daApi(forma)) ?? FormaDePagamento.app,
      plano: plano == null ? null : Plano.fromJson(plano),
    );
  }

  final int id;
  final StatusDaConsulta status;

  /// Só em consulta cancelada.
  final MotivoDoCancelamento? motivoDoCancelamento;
  final int horarioId;

  /// "R$ 250,00" — o valor congelado quando o horário foi reservado. Um
  /// reajuste do profissional depois disso não o muda.
  final String valorFormatado;

  /// Até quando a reserva espera o pagamento; depois disso a API recusa pagar,
  /// e o horário volta à grade. Só na consulta que ainda espera pagamento.
  final DateTime? reservaExpiraEm;

  /// O horário da consulta. Vem no detalhe e nas listagens; a resposta do
  /// agendamento não o traz, porque quem agendou já o tem.
  final Horario? horario;

  /// Quem atende, com a especialidade e a clínica. Vem no detalhe e nas
  /// listagens, e é de lá que sai a tela da consulta confirmada (checklist,
  /// item 1.4).
  final Profissional? profissional;

  /// Como a consulta é paga. Só o aplicativo tem pagamento antecipado — e,
  /// por isso, valor a devolver num cancelamento.
  final FormaDePagamento formaDePagamento;

  /// O plano de saúde, quando a forma é o plano.
  final Plano? plano;
}
