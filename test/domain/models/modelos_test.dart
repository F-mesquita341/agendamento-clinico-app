import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/instante.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('instante da API', () {
    test('o mesmo instante, convertido para o horário do aparelho', () {
      final lido = instanteDaApi('2026-10-06T11:30:00.000Z');

      expect(lido.isUtc, isFalse);
      expect(lido.toUtc(), DateTime.utc(2026, 10, 6, 11, 30));
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
}
