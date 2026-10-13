import 'dart:async';
import 'dart:convert';
import 'dart:io' show HandshakeException;

import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// O cliente HTTP contra uma API simulada: cada resposta é a que a API real dá
/// no caso descrito — o envelope de erro, a sessão expirada, o 429.
void main() {
  final base = Uri.parse('https://api.exemplo.test');

  http.Response json(int status, Object corpo, {Map<String, String> cabecalhos = const {}}) =>
      http.Response.bytes(utf8.encode(jsonEncode(corpo)), status,
          headers: {'content-type': 'application/json; charset=utf-8', ...cabecalhos});

  Map<String, Object?> envelope(String codigo, String mensagem, {String? acao, List<Object>? problemas}) => {
        'erro': {
          'codigo': codigo,
          'mensagem': mensagem,
          'acao': acao,
          'problemas': ?problemas,
        },
      };

  /// Fonte de token que registra cada pedido, e dá um token novo quando pedem
  /// renovação.
  ({FonteDeToken fonte, List<bool> pedidos}) tokens() {
    final pedidos = <bool>[];
    Future<String?> fonte({bool renovar = false}) async {
      pedidos.add(renovar);
      return renovar ? 'token-novo' : 'token-velho';
    }

    return (fonte: fonte, pedidos: pedidos);
  }

  test('resposta de sucesso devolve o JSON decodificado, em UTF-8', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => json(200, {'nome': 'Clínica Geral'})),
      base: base,
    );

    expect(await api.get('/especialidades', autenticado: false), {'nome': 'Clínica Geral'});
  });

  test('o envelope de erro vira ErroDaApi, com código, mensagem, ação e problemas', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => json(
            422,
            envelope('DADOS_INVALIDOS', 'Alguns campos não foram preenchidos corretamente.',
                problemas: [
                  {'campo': 'nome', 'mensagem': 'Informe o nome.'},
                ]),
          )),
      base: base,
    );

    await expectLater(
      api.post('/pacientes', corpo: {}),
      throwsA(isA<ErroDaApi>()
          .having((e) => e.status, 'status', 422)
          .having((e) => e.codigo, 'codigo', 'DADOS_INVALIDOS')
          .having((e) => e.mensagem, 'mensagem', 'Alguns campos não foram preenchidos corretamente.')
          .having((e) => e.problemas.single.campo, 'campo', 'nome')),
    );
  });

  test('a ação vem da API e decide o que fazer — nunca o texto da mensagem', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => json(
            409,
            envelope('HORARIO_INDISPONIVEL', 'Este horário acabou de ser reservado por outro paciente.',
                acao: 'recarregar_horarios'),
          )),
      base: base,
    );

    await expectLater(
      api.post('/consultas', corpo: {'horarioId': 1, 'versao': 0}),
      throwsA(isA<ErroDaApi>().having((e) => e.acao, 'acao', AcaoSugerida.recarregarHorarios)),
    );
  });

  test('pedido autenticado leva o token no cabeçalho', () async {
    String? recebido;
    final t = tokens();
    final api = ApiClient(
      cliente: MockClient((pedido) async {
        recebido = pedido.headers['Authorization'];
        return json(200, {});
      }),
      base: base,
      token: t.fonte,
    );

    await api.get('/pacientes/me');

    expect(recebido, 'Bearer token-velho');
  });

  test('rota pública não leva token, mesmo havendo sessão', () async {
    String? recebido = 'não chamado';
    final api = ApiClient(
      cliente: MockClient((pedido) async {
        recebido = pedido.headers['Authorization'];
        return json(200, {'especialidades': <Object>[]});
      }),
      base: base,
      token: tokens().fonte,
    );

    await api.get('/especialidades', autenticado: false);

    expect(recebido, isNull);
  });

  test('sessão expirada: renova o token e repete o pedido uma vez', () async {
    final t = tokens();
    final cabecalhos = <String?>[];
    final api = ApiClient(
      cliente: MockClient((pedido) async {
        cabecalhos.add(pedido.headers['Authorization']);
        return cabecalhos.length == 1
            ? json(401, envelope('SESSAO_EXPIRADA', 'Sua sessão expirou.', acao: 'renovar_token'))
            : json(200, {'ok': true});
      }),
      base: base,
      token: t.fonte,
    );

    expect(await api.get('/pacientes/me'), {'ok': true});
    expect(t.pedidos, [false, true]);
    expect(cabecalhos, ['Bearer token-velho', 'Bearer token-novo']);
  });

  test('sessão expirada de novo depois de renovar: desiste, sem repetir para sempre', () async {
    var chamadas = 0;
    final api = ApiClient(
      cliente: MockClient((_) async {
        chamadas++;
        return json(401, envelope('SESSAO_EXPIRADA', 'Sua sessão expirou.', acao: 'renovar_token'));
      }),
      base: base,
      token: tokens().fonte,
    );

    await expectLater(
      api.get('/pacientes/me'),
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'SESSAO_EXPIRADA')),
    );
    expect(chamadas, 2);
  });

  test('sem autenticação (acao autenticar) não renova: é caso de entrar de novo', () async {
    var chamadas = 0;
    final api = ApiClient(
      cliente: MockClient((_) async {
        chamadas++;
        return json(401, envelope('NAO_AUTENTICADO', 'Faça login para continuar.', acao: 'autenticar'));
      }),
      base: base,
      token: tokens().fonte,
    );

    await expectLater(
      api.get('/pacientes/me'),
      throwsA(isA<ErroDaApi>().having((e) => e.acao, 'acao', AcaoSugerida.autenticar)),
    );
    expect(chamadas, 1);
  });

  group('sessão perdida', () {
    test('autenticar num pedido autenticado avisa uma vez, e o erro continua subindo', () async {
      var avisos = 0;
      final api = ApiClient(
        cliente: MockClient((_) async => json(401, envelope('NAO_AUTENTICADO', 'Faça login.', acao: 'autenticar'))),
        base: base,
        token: tokens().fonte,
        aoPerderSessao: () => avisos++,
      );

      await expectLater(api.get('/pacientes/me'), throwsA(isA<ErroDaApi>()));
      expect(avisos, 1);
    });

    test('a fonte de token também pode dizer que a sessão acabou', () async {
      var avisos = 0;
      var pedidos = 0;
      Future<String?> fonteSemSessao({bool renovar = false}) async => throw const ErroDaApi(
            status: 401,
            codigo: 'SESSAO_ENCERRADA',
            mensagem: 'Sua sessão terminou.',
            acao: AcaoSugerida.autenticar,
          );
      final api = ApiClient(
        cliente: MockClient((_) async {
          pedidos++;
          return json(200, {});
        }),
        base: base,
        token: fonteSemSessao,
        aoPerderSessao: () => avisos++,
      );

      await expectLater(api.get('/pacientes/me'), throwsA(isA<ErroDaApi>()));
      expect(avisos, 1);
      // Sem token, o pedido nem sai.
      expect(pedidos, 0);
    });

    test('sessão expirada que se renova não é sessão perdida', () async {
      var avisos = 0;
      var chamadas = 0;
      final api = ApiClient(
        cliente: MockClient((_) async => chamadas++ == 0
            ? json(401, envelope('SESSAO_EXPIRADA', 'Sua sessão expirou.', acao: 'renovar_token'))
            : json(200, {'ok': true})),
        base: base,
        token: tokens().fonte,
        aoPerderSessao: () => avisos++,
      );

      await api.get('/pacientes/me');
      expect(avisos, 0);
    });

    test('outros erros não avisam', () async {
      var avisos = 0;
      final api = ApiClient(
        cliente: MockClient((_) async => json(404, envelope('PERFIL_NAO_CADASTRADO', 'Complete seu cadastro.',
            acao: 'completar_cadastro'))),
        base: base,
        token: tokens().fonte,
        aoPerderSessao: () => avisos++,
      );

      await expectLater(api.get('/pacientes/me'), throwsA(isA<ErroDaApi>()));
      expect(avisos, 0);
    });
  });

  test('429 traz quanto esperar, lido do Retry-After', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => json(
            429,
            envelope('MUITAS_REQUISICOES', 'Muitas operações em pouco tempo.', acao: 'tentar_novamente'),
            cabecalhos: {'retry-after': '37'},
          )),
      base: base,
    );

    await expectLater(
      api.post('/consultas', corpo: {}),
      throwsA(isA<ErroDaApi>()
          .having((e) => e.tenteDeNovoEm, 'tenteDeNovoEm', const Duration(seconds: 37))
          .having((e) => e.acao, 'acao', AcaoSugerida.tentarNovamente)),
    );
  });

  test('sem rede vira SEM_CONEXAO, com mensagem para a pessoa', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => throw http.ClientException('sem rede')),
      base: base,
    );

    await expectLater(
      api.get('/especialidades', autenticado: false),
      throwsA(isA<ErroDaApi>()
          .having((e) => e.codigo, 'codigo', 'SEM_CONEXAO')
          .having((e) => e.acao, 'acao', AcaoSugerida.tentarNovamente)),
    );
  });

  test('falha de TLS, que o pacote http não converte, também vira SEM_CONEXAO', () async {
    // Relógio errado no aparelho, ou rede que intercepta o certificado.
    final api = ApiClient(
      cliente: MockClient((_) async => throw const HandshakeException('certificado recusado')),
      base: base,
    );

    await expectLater(
      api.get('/especialidades', autenticado: false),
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'SEM_CONEXAO')),
    );
  });

  test('o prazo vale para o pedido inteiro: cabeçalhos tardios e corpo parado não dobram a espera', () {
    fakeAsync((tempo) {
      // Os cabeçalhos chegam aos 80 s; o corpo nunca termina. Com um prazo
      // para cada parte, o erro só sairia aos 170 s.
      final corpoQueNaoTermina = StreamController<List<int>>();
      final api = ApiClient(
        cliente: MockClient.streaming((_, _) async {
          await Future<void>.delayed(const Duration(seconds: 80));
          return http.StreamedResponse(corpoQueNaoTermina.stream, 200);
        }),
        base: base,
        prazo: const Duration(seconds: 90),
      );

      Object? erro;
      api.get('/especialidades', autenticado: false).then((_) {}, onError: (Object e) {
        erro = e;
      });

      tempo.elapse(const Duration(seconds: 91));

      expect(erro, isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'SEM_CONEXAO'));
      corpoQueNaoTermina.close();
    });
  });

  test('prazo esgotado também vira SEM_CONEXAO', () async {
    final api = ApiClient(
      cliente: MockClient((_) => Completer<http.Response>().future),
      base: base,
      prazo: const Duration(milliseconds: 20),
    );

    await expectLater(
      api.get('/especialidades', autenticado: false),
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'SEM_CONEXAO')),
    );
  });

  test('resposta fora do envelope — uma página de erro do provedor — vira RESPOSTA_INESPERADA', () async {
    final api = ApiClient(
      cliente: MockClient((_) async => http.Response('<html>Bad Gateway</html>', 502)),
      base: base,
    );

    await expectLater(
      api.get('/especialidades', autenticado: false),
      throwsA(isA<ErroDaApi>()
          .having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')
          .having((e) => e.status, 'status', 502)),
    );
  });

  test('parâmetros de consulta vão codificados na URL', () async {
    Uri? recebido;
    final api = ApiClient(
      cliente: MockClient((pedido) async {
        recebido = pedido.url;
        return json(200, {});
      }),
      base: base,
    );

    await api.get('/profissionais', consulta: {'q': 'José Antônio', 'pagina': '2'}, autenticado: false);

    expect(recebido!.path, '/profissionais');
    expect(recebido!.queryParameters, {'q': 'José Antônio', 'pagina': '2'});
  });

  test('o corpo vai em JSON, com o tipo declarado', () async {
    late http.Request recebido;
    final api = ApiClient(
      cliente: MockClient((pedido) async {
        recebido = pedido;
        return json(201, {});
      }),
      base: base,
    );

    await api.post('/consultas', corpo: {'horarioId': 7, 'versao': 0}, autenticado: false);

    expect(recebido.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(recebido.body), {'horarioId': 7, 'versao': 0});
  });
}
