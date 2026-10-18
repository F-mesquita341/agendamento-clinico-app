import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/instante.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('instante da API', () {
    test('o instante fica em UTC, como a API mandou, sem passar pelo fuso do aparelho', () {
      final lido = instanteDaApi('2026-10-06T11:30:00.000Z');

      expect(lido.isUtc, isTrue);
      expect(lido, DateTime.utc(2026, 10, 6, 11, 30));
    });

    test('a hora que se mostra é a da clínica, três horas atrás do UTC', () {
      expect(horaNaClinica(DateTime.utc(2026, 10, 15, 17, 30)), '14:30');
      expect(horaNaClinica(DateTime.utc(2026, 10, 15, 11, 5)), '08:05');
      // Perto da meia-noite, a hora volta para o dia anterior.
      expect(horaNaClinica(DateTime.utc(2026, 10, 15, 2, 5)), '23:05');
    });

    test('o relógio da clínica não depende do fuso do aparelho', () {
      final instante = DateTime.utc(2026, 10, 15, 17, 30);

      // O mesmo instante, escrito no fuso do aparelho, dá o mesmo relógio.
      expect(relogioDaClinica(instante.toLocal()), relogioDaClinica(instante));
      expect(relogioDaClinica(instante).isUtc, isTrue);
    });

    test('texto sem o Z do UTC é recusado, em vez de lido como hora local', () {
      expect(() => instanteDaApi('2026-10-06T11:30:00'), throwsFormatException);
    });

    test('valor que não é texto é recusado', () {
      expect(() => instanteDaApi(null), throwsFormatException);
    });
  });

  group('ação sugerida', () {
    test('os seis valores da API, e ausência vira nenhuma', () {
      expect(
        ['autenticar', 'renovar_token', 'completar_cadastro', 'recarregar_horarios', 'exibir_termo', 'tentar_novamente', null]
            .map(AcaoSugerida.daApi),
        [
          AcaoSugerida.autenticar,
          AcaoSugerida.renovarToken,
          AcaoSugerida.completarCadastro,
          AcaoSugerida.recarregarHorarios,
          AcaoSugerida.exibirTermo,
          AcaoSugerida.tentarNovamente,
          AcaoSugerida.nenhuma,
        ],
      );
    });

    test('valor desconhecido não quebra o aplicativo: vira nenhuma', () {
      expect(AcaoSugerida.daApi('acao_que_ainda_nao_existe'), AcaoSugerida.nenhuma);
    });
  });

  group('especialidade', () {
    test('lida do JSON da API', () {
      final e = Especialidade.fromJson({'id': 3, 'nome': 'Cardiologia'});

      expect((e.id, e.nome), (3, 'Cardiologia'));
    });

    test('fora do formato é recusada', () {
      expect(() => Especialidade.fromJson({'id': '3', 'nome': 'Cardiologia'}), throwsFormatException);
    });
  });

  group('consulta', () {
    const json = {
      'id': 31,
      'status': 'pendente_pagamento',
      'horarioId': 7,
      'valorFormatado': 'R\$ 250,00',
      'reservaExpiraEm': '2026-10-19T12:15:00.000Z',
    };

    test('os cinco status da API', () {
      StatusDaConsulta lido(String status) => Consulta.fromJson({...json, 'status': status}).status;

      expect(lido('pendente_pagamento'), StatusDaConsulta.pendentePagamento);
      expect(lido('confirmada'), StatusDaConsulta.confirmada);
      expect(lido('cancelada'), StatusDaConsulta.cancelada);
      expect(lido('realizada'), StatusDaConsulta.realizada);
      expect(lido('nao_compareceu'), StatusDaConsulta.naoCompareceu);
    });

    test('status que esta versão não conhece não quebra a leitura: vira desconhecido', () {
      expect(Consulta.fromJson({...json, 'status': 'remarcada'}).status, StatusDaConsulta.desconhecido);
    });

    test('só aguardando pagamento e confirmada seguram o horário', () {
      expect(
        [for (final status in StatusDaConsulta.values) if (status.seguraOHorario) status],
        [StatusDaConsulta.pendentePagamento, StatusDaConsulta.confirmada],
      );
    });

    test('prazo e horário podem não vir', () {
      final consulta = Consulta.fromJson({...json, 'reservaExpiraEm': null});

      expect(consulta.reservaExpiraEm, isNull);
      expect(consulta.horario, isNull);
    });

    test('fora do formato é recusada', () {
      expect(() => Consulta.fromJson({...json, 'id': '31'}), throwsFormatException);
      expect(() => Consulta.fromJson({...json, 'status': null}), throwsFormatException);
      expect(() => Consulta.fromJson({...json, 'horario': 7}), throwsFormatException);
      expect(() => Consulta.fromJson({...json, 'reservaExpiraEm': '2026-10-19T12:15:00'}), throwsFormatException);
    });
  });
}
