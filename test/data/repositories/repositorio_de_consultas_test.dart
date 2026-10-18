import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/repositorio_de_consultas.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// As consultas contra respostas iguais às da API real.
void main() {
  late List<http.Request> pedidos;

  RepositorioDeConsultasRemoto consultas(Object corpo, {int status = 200}) {
    pedidos = [];
    return RepositorioDeConsultasRemoto(ApiClient(
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return http.Response.bytes(utf8.encode(jsonEncode(corpo)), status);
      }),
      base: Uri.parse('https://api.exemplo.test'),
      token: ({bool renovar = false}) async => 'token-de-teste',
    ));
  }

  final respostaInesperada =
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA'));

  // A resposta do agendamento, como a API a escreve: sem o horário dentro.
  const reservada = {
    'id': 31,
    'status': 'pendente_pagamento',
    'motivoCancelamento': null,
    'horarioId': 7,
    'valorCentavos': 25000,
    'valorFormatado': 'R\$ 250,00',
    'reservaExpiraEm': '2026-10-19T12:15:00.000Z',
    'criadoEm': '2026-10-19T12:00:00.000Z',
  };

  group('agendar', () {
    test('manda o horário e a versão da grade, com o token da conta', () async {
      await consultas({'consulta': reservada}, status: 201).agendar(horarioId: 7, versao: 3);

      final pedido = pedidos.single;
      expect(pedido.method, 'POST');
      expect(pedido.url.path, '/consultas');
      expect(pedido.url.query, isEmpty);
      expect(jsonDecode(pedido.body), {'horarioId': 7, 'versao': 3});
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('lê a consulta reservada, com o prazo da reserva em UTC', () async {
      final consulta = await consultas({'consulta': reservada}, status: 201).agendar(horarioId: 7, versao: 3);

      expect(consulta.id, 31);
      expect(consulta.status, StatusDaConsulta.pendentePagamento);
      expect(consulta.horarioId, 7);
      expect(consulta.valorFormatado, 'R\$ 250,00');
      expect(consulta.reservaExpiraEm, DateTime.utc(2026, 10, 19, 12, 15));
      expect(consulta.horario, isNull);
    });

    test('a colisão do lock otimista chega como erro com a ação de recarregar', () async {
      final repositorio = consultas({
        'erro': {
          'codigo': 'HORARIO_INDISPONIVEL',
          'mensagem': 'Este horário acabou de ser reservado por outro paciente.',
          'acao': 'recarregar_horarios',
        },
      }, status: 409);

      await expectLater(
        repositorio.agendar(horarioId: 7, versao: 3),
        throwsA(isA<ErroDaApi>()
            .having((e) => e.acao, 'acao', AcaoSugerida.recarregarHorarios)
            .having((e) => e.mensagem, 'mensagem', 'Este horário acabou de ser reservado por outro paciente.')),
      );
    });

    test('consulta fora do formato vira RESPOSTA_INESPERADA, e não erro de tipo', () async {
      await expectLater(
        consultas({
          'consulta': {...reservada, 'horarioId': '7'},
        }, status: 201)
            .agendar(horarioId: 7, versao: 3),
        respostaInesperada,
      );
      await expectLater(consultas({'consulta': 'reservada'}, status: 201).agendar(horarioId: 7, versao: 3),
          respostaInesperada);
    });
  });

  group('minhas', () {
    const horario = {
      'id': 7,
      'inicio': '2026-10-19T12:00:00.000Z',
      'fim': '2026-10-19T12:30:00.000Z',
      'duracaoMinutos': 30,
      'versao': 4,
    };

    test('pede a página com o limite dito por extenso, e com o token da conta', () async {
      await consultas({
        'consultas': <Object>[],
        'paginacao': {'pagina': 2, 'limite': 20, 'paginas': 2, 'total': 21},
      }).minhas(pagina: 2);

      final pedido = pedidos.single;
      expect(pedido.method, 'GET');
      expect(pedido.url.path, '/consultas');
      expect(pedido.url.queryParameters, {'pagina': '2', 'limite': '20'});
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('lê cada consulta com o horário, e a paginação', () async {
      final pagina = await consultas({
        'consultas': [
          {...reservada, 'horario': horario},
          {...reservada, 'id': 30, 'status': 'cancelada', 'reservaExpiraEm': null, 'horario': horario},
        ],
        'paginacao': {'pagina': 1, 'limite': 20, 'paginas': 1, 'total': 2},
      }).minhas();

      expect(pagina.itens.map((c) => (c.id, c.status)), [
        (31, StatusDaConsulta.pendentePagamento),
        (30, StatusDaConsulta.cancelada),
      ]);
      expect(pagina.itens.first.horario?.inicio, DateTime.utc(2026, 10, 19, 12));
      expect(pagina.itens.last.reservaExpiraEm, isNull);
      expect(pagina.temMais, isFalse);
    });

    test('lista sem a paginação vira RESPOSTA_INESPERADA', () async {
      await expectLater(consultas({'consultas': <Object>[]}).minhas(), respostaInesperada);
    });
  });
}
