import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/leitura_json.dart';
import 'package:agendamento_clinico/data/repositories/repositorio_de_dispositivos.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Os aparelhos do paciente contra respostas iguais às da API real
/// (`src/interfaces/http/rotas/dispositivos.js`).
void main() {
  late List<http.Request> pedidos;

  RepositorioDeDispositivosRemoto dispositivos(int status, [Object? corpo]) {
    pedidos = [];
    return RepositorioDeDispositivosRemoto(ApiClient(
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return http.Response.bytes(corpo == null ? const [] : utf8.encode(jsonEncode(corpo)), status);
      }),
      base: Uri.parse('https://api.exemplo.test'),
      token: ({bool renovar = false}) async => 'token-de-teste',
    ));
  }

  Map<String, Object?> erro(String codigo, String mensagem, [String? acao]) => {
        'erro': {'codigo': codigo, 'mensagem': mensagem, 'acao': acao},
      };

  group('registrar', () {
    test('manda só o token e a plataforma, com o token da conta, e devolve o id', () async {
      final id = await dispositivos(201, {
        'dispositivo': {'id': 12},
      }).registrar('token-fcm');

      expect(id, 12);
      final pedido = pedidos.single;
      expect(pedido.method, 'POST');
      expect(pedido.url.path, '/dispositivos');
      // O corpo é estrito na API: um campo a mais seria recusado.
      expect(jsonDecode(pedido.body), {'token': 'token-fcm', 'plataforma': 'android'});
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('resposta sem o id vira RESPOSTA_INESPERADA', () async {
      final registro = <String>[];
      final original = registrarRespostaForaDoFormato;
      registrarRespostaForaDoFormato = registro.add;
      addTearDown(() => registrarRespostaForaDoFormato = original);

      await expectLater(
        dispositivos(201, {'dispositivo': <String, Object?>{}}).registrar('token-fcm'),
        throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')),
      );
      expect(registro.single, contains('"dispositivo"'));
      // O token é dado pessoal: não vai para o log.
      expect(registro.single, isNot(contains('token-fcm')));
    });

    test('a recusa da API sobe como erro, com a ação', () async {
      await expectLater(
        dispositivos(429, erro('MUITAS_REQUISICOES', 'Muitas tentativas.', 'tentar_novamente')).registrar('t'),
        throwsA(isA<ErroDaApi>().having((e) => e.acao, 'acao', AcaoSugerida.tentarNovamente)),
      );
    });
  });

  group('revogar', () {
    test('DELETE pelo id, com o token da conta, sem corpo', () async {
      await dispositivos(204).revogar(12);

      final pedido = pedidos.single;
      expect(pedido.method, 'DELETE');
      expect(pedido.url.path, '/dispositivos/12');
      expect(pedido.body, isEmpty);
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('404 sem ação conta como feito: o aparelho já não é desta conta', () async {
      await dispositivos(404, erro('NAO_ENCONTRADO', 'Aparelho não encontrado.')).revogar(12);
    });

    test('o 404 do cadastro que falta vem com ação, e sobe', () async {
      await expectLater(
        dispositivos(404, erro('PERFIL_NAO_CADASTRADO', 'Complete seu cadastro.', 'completar_cadastro')).revogar(12),
        throwsA(isA<ErroDaApi>().having((e) => e.acao, 'acao', AcaoSugerida.completarCadastro)),
      );
    });

    test('outra recusa sobe', () async {
      await expectLater(
        dispositivos(500, erro('ERRO_INTERNO', 'Algo deu errado do nosso lado.')).revogar(12),
        throwsA(isA<ErroDaApi>().having((e) => e.status, 'status', 500)),
      );
    });
  });
}
