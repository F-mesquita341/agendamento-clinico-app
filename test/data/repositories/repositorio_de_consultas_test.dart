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

  group('consulta', () {
    // O detalhe, como a API o escreve: com o horário e o profissional inteiro.
    final detalhe = <String, Object?>{
      ...reservada,
      'status': 'confirmada',
      'reservaExpiraEm': null,
      'horario': {
        'id': 7,
        'inicio': '2026-10-19T12:00:00.000Z',
        'fim': '2026-10-19T12:30:00.000Z',
        'duracaoMinutos': 30,
        'versao': 1,
      },
      'profissional': {
        'id': 2,
        'nome': 'Carlos Eduardo Timbó',
        'registroConselho': 'CRM-CE 12345',
        'especialidade': {'id': 2, 'nome': 'Cardiologia'},
        'valorCentavos': 25000,
        'valorFormatado': 'R\$ 250,00',
        'clinica': {
          'id': 1,
          'nome': 'Clínica Exemplo Quixadá',
          'telefone': '(88) 3000-0000',
          'endereco': 'Centro, Quixadá - CE',
        },
      },
    };

    test('pede a consulta pelo id, com o token da conta', () async {
      await consultas({'consulta': detalhe}).consulta(31);

      final pedido = pedidos.single;
      expect(pedido.method, 'GET');
      expect(pedido.url.path, '/consultas/31');
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('lê o status, o horário e o profissional com a clínica', () async {
      final consulta = await consultas({'consulta': detalhe}).consulta(31);

      expect(consulta.status, StatusDaConsulta.confirmada);
      expect(consulta.horario?.inicio, DateTime.utc(2026, 10, 19, 12));
      expect(consulta.profissional?.nome, 'Carlos Eduardo Timbó');
      expect(consulta.profissional?.clinica?.endereco, 'Centro, Quixadá - CE');
    });

    test('lê o motivo do cancelamento', () async {
      final consulta = await consultas({
        'consulta': {...detalhe, 'status': 'cancelada', 'motivoCancelamento': 'reserva_expirada'},
      }).consulta(31);

      expect(consulta.status, StatusDaConsulta.cancelada);
      expect(consulta.motivoDoCancelamento, MotivoDoCancelamento.reservaExpirada);
    });
  });

  group('pagar', () {
    const pagamento = {
      'status': 'aberto',
      'checkoutUrl': 'https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123',
      'expiraEm': '2026-10-19T12:15:00.000Z',
      'valorCentavos': 25000,
      'valorFormatado': 'R\$ 250,00',
    };

    test('pede o pagamento da consulta, sem corpo, com o token da conta', () async {
      await consultas({'pagamento': pagamento}, status: 201).pagar(31);

      final pedido = pedidos.single;
      expect(pedido.method, 'POST');
      expect(pedido.url.path, '/consultas/31/pagamento');
      expect(pedido.body, isEmpty);
      expect(pedido.headers['Authorization'], 'Bearer token-de-teste');
    });

    test('lê o endereço da página, o valor e o prazo — 201 e 200 dão o mesmo', () async {
      for (final status in [201, 200]) {
        final checkout = await consultas({'pagamento': pagamento}, status: status).pagar(31);

        expect(checkout.endereco, Uri.parse('https://www.mercadopago.com.br/checkout/v1/redirect?pref_id=123'));
        expect(checkout.valorFormatado, 'R\$ 250,00');
        expect(checkout.expiraEm, DateTime.utc(2026, 10, 19, 12, 15));
      }
    });

    test('endereço que não é uma página https é recusado: é nela que se digita o cartão', () async {
      for (final url in ['http://www.mercadopago.com.br/checkout', 'javascript:alert(1)', 'https://', 'qualquer coisa']) {
        await expectLater(
          consultas({
            'pagamento': {...pagamento, 'checkoutUrl': url},
          }, status: 201)
              .pagar(31),
          respostaInesperada,
          reason: url,
        );
      }
    });

    test('a recusa da API chega com a mensagem dela', () async {
      final repositorio = consultas({
        'erro': {
          'codigo': 'RESERVA_EXPIRADA',
          'mensagem': 'O prazo para pagar esta reserva terminou. Escolha o horário de novo.',
        },
      }, status: 422);

      await expectLater(
        repositorio.pagar(31),
        throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESERVA_EXPIRADA')),
      );
    });
  });
}
