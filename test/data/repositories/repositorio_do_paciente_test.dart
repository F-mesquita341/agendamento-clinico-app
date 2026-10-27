import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/leitura_json.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_do_paciente.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// O perfil do paciente contra respostas iguais às da API real.
void main() {
  late List<http.Request> pedidos;

  RepositorioDoPacienteRemoto repositorio(int status, Object corpo) {
    pedidos = [];
    return RepositorioDoPacienteRemoto(ApiClient(
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return http.Response.bytes(utf8.encode(jsonEncode(corpo)), status);
      }),
      base: Uri.parse('https://api.exemplo.test'),
      token: ({bool renovar = false}) async => 'token-de-teste',
    ));
  }

  Map<String, Object?> erro(String codigo, String? acao) => {
        'erro': {'codigo': codigo, 'mensagem': 'mensagem da API', 'acao': acao},
      };

  const perfil = {
    'paciente': {
      'id': 7,
      'nome': 'Ana Lima',
      'email': 'ana@exemplo.test',
      'telefone': '88999990000',
      'dataNascimento': '1990-03-15',
      'consentimento': {'versao': '2026-09-v2', 'aceitoEm': '2026-10-06T12:30:00.000Z'},
    },
  };

  group('meu perfil', () {
    test('lê o perfil da conta, pedindo /pacientes/me com o token', () async {
      final paciente = (await repositorio(200, perfil).meu())!;

      expect(pedidos.single.url.path, '/pacientes/me');
      expect(pedidos.single.headers['Authorization'], 'Bearer token-de-teste');
      expect(paciente.nome, 'Ana Lima');
      expect(paciente.telefone, '88999990000');
      // Data civil: o mesmo dia, sem passar por fuso.
      expect(paciente.dataNascimento, DataCivil.tentar(1990, 3, 15));
      expect(paciente.versaoDoTermo, '2026-09-v2');
      expect(paciente.termoAceitoEm?.toUtc(), DateTime.utc(2026, 10, 6, 12, 30));
    });

    test('telefone e data de nascimento são opcionais', () async {
      final paciente = (await repositorio(200, {
        'paciente': {
          ...perfil['paciente']!,
          'telefone': null,
          'dataNascimento': null,
        },
      }).meu())!;

      expect(paciente.telefone, isNull);
      expect(paciente.dataNascimento, isNull);
    });

    test('conta sem cadastro (completar_cadastro) é null, e não erro', () async {
      expect(await repositorio(404, erro('PERFIL_NAO_CADASTRADO', 'completar_cadastro')).meu(), isNull);
    });

    test('outro 404 continua sendo erro: decide a ação, não o código HTTP', () async {
      await expectLater(
        repositorio(404, erro('ROTA_NAO_ENCONTRADA', null)).meu(),
        throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'ROTA_NAO_ENCONTRADA')),
      );
    });

    test('perfil fora do formato vira RESPOSTA_INESPERADA, e deixa no log o recurso e o motivo', () async {
      final registro = <String>[];
      final original = registrarRespostaForaDoFormato;
      registrarRespostaForaDoFormato = registro.add;
      addTearDown(() => registrarRespostaForaDoFormato = original);

      await expectLater(
        repositorio(200, {
          'paciente': {...perfil['paciente']!, 'dataNascimento': '15/03/1990'},
        }).meu(),
        throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')),
      );
      expect(registro, ['Resposta fora do formato em "paciente": Data fora do formato AAAA-MM-DD.']);
    });
  });
}
