import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/ui/consultas/situacao_da_consulta.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/agenda.dart';

void main() {
  // Meio-dia de quarta, 14/10, na clínica; a consulta é às 14:00 do mesmo dia.
  final agora = meioDiaDeQuarta;
  final dasDuas = horario(1, 14, 14);
  final prazo = agora.add(const Duration(minutes: 15));

  ConsultaNaLista item(StatusDaConsulta status, {DateTime? expiraEm, MotivoDoCancelamento? motivo}) =>
      itemDe(consultaNa(dasDuas, status: status, expiraEm: expiraEm, motivo: motivo));

  group('reserva aguardando pagamento', () {
    test('com o prazo valendo: aguarda, é próxima, pode pagar e cancelar', () {
      final reserva = item(StatusDaConsulta.pendentePagamento, expiraEm: prazo);

      expect(reserva.reservaVencida(agora), isFalse);
      expect(reserva.aguardandoPagamento(agora), isTrue);
      expect(reserva.ehProxima(agora), isTrue);
      expect(reserva.podePagar(agora), isTrue);
      expect(reserva.podeCancelar(agora), isTrue);
    });

    test('no instante do prazo, a reserva venceu: nem pagar, nem cancelar', () {
      final reserva = item(StatusDaConsulta.pendentePagamento, expiraEm: prazo);

      expect(reserva.reservaVencida(prazo), isTrue);
      expect(reserva.aguardandoPagamento(prazo), isFalse);
      expect(reserva.ehProxima(prazo), isFalse);
      expect(reserva.podePagar(prazo), isFalse);
      expect(reserva.podeCancelar(prazo), isFalse);
      // Um instante antes, ainda valia.
      final antes = prazo.subtract(const Duration(milliseconds: 1));
      expect(reserva.aguardandoPagamento(antes), isTrue);
    });

    test('sem prazo, a reserva não é dada como vencida', () {
      final reserva = item(StatusDaConsulta.pendentePagamento);

      expect(reserva.reservaVencida(agora), isFalse);
      expect(reserva.aguardandoPagamento(agora), isTrue);
    });

    test('com o horário já começado, não é mais próxima, nem se paga', () {
      final inicio = dasDuas.inicio;
      final reserva = item(StatusDaConsulta.pendentePagamento, expiraEm: inicio.add(const Duration(minutes: 5)));

      expect(reserva.aguardandoPagamento(inicio), isTrue);
      expect(reserva.comecou(inicio), isTrue);
      expect(reserva.ehProxima(inicio), isFalse);
      expect(reserva.podePagar(inicio), isFalse);
      expect(reserva.podeCancelar(inicio), isFalse);
    });
  });

  group('consulta confirmada', () {
    test('antes do horário: próxima, e pode cancelar, mas não pagar', () {
      final consulta = item(StatusDaConsulta.confirmada);

      expect(consulta.ehProxima(agora), isTrue);
      expect(consulta.podeCancelar(agora), isTrue);
      expect(consulta.podePagar(agora), isFalse);
    });

    test('no instante do começo, não se cancela mais (decisão de 20/10)', () {
      final consulta = item(StatusDaConsulta.confirmada);
      final inicio = dasDuas.inicio;

      expect(consulta.comecou(inicio), isTrue);
      expect(consulta.ehProxima(inicio), isFalse);
      expect(consulta.podeCancelar(inicio), isFalse);
      final antes = inicio.subtract(const Duration(milliseconds: 1));
      expect(consulta.comecou(antes), isFalse);
      expect(consulta.podeCancelar(antes), isTrue);
    });
  });

  test('cancelada, mesmo com o horário adiante, não é próxima nem se cancela', () {
    for (final motivo in [MotivoDoCancelamento.paciente, MotivoDoCancelamento.reservaExpirada]) {
      final cancelada = item(StatusDaConsulta.cancelada, motivo: motivo);

      expect(cancelada.ehProxima(agora), isFalse, reason: '$motivo');
      expect(cancelada.podeCancelar(agora), isFalse, reason: '$motivo');
      expect(cancelada.podePagar(agora), isFalse, reason: '$motivo');
    }
  });

  group('a próxima mudança', () {
    test('a reserva muda primeiro no prazo; depois, no começo do horário', () {
      final reserva = item(StatusDaConsulta.pendentePagamento, expiraEm: prazo);

      expect(reserva.proximaMudanca(agora), prazo);
      expect(reserva.proximaMudanca(prazo), dasDuas.inicio);
    });

    test('a confirmada muda no começo do horário, e depois mais nada', () {
      final consulta = item(StatusDaConsulta.confirmada);

      expect(consulta.proximaMudanca(agora), dasDuas.inicio);
      expect(consulta.proximaMudanca(dasDuas.inicio), isNull);
    });

    test('a cancelada não muda mais', () {
      expect(item(StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.paciente).proximaMudanca(agora), isNull);
    });
  });
}
