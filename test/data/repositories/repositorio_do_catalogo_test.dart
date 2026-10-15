import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// O catálogo contra respostas iguais às da API real.
void main() {
  late List<http.Request> pedidos;

  // A fonte de token existe de propósito: é ela que faz o teste "sem o token
  // da conta" cair se o catálogo passar a ser pedido como rota autenticada.
  RepositorioDoCatalogoRemoto catalogo(Object corpo) {
    pedidos = [];
    return RepositorioDoCatalogoRemoto(ApiClient(
      cliente: MockClient((pedido) async {
        pedidos.add(pedido);
        return http.Response.bytes(utf8.encode(jsonEncode(corpo)), 200);
      }),
      base: Uri.parse('https://api.exemplo.test'),
      token: ({bool renovar = false}) async => 'token-de-teste',
    ));
  }

  final respostaInesperada =
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA'));

  group('especialidades', () {
    test('lê as especialidades embrulhadas no nome do recurso', () async {
      final itens = await catalogo({
        'especialidades': [
          {'id': 1, 'nome': 'Cardiologia'},
          {'id': 2, 'nome': 'Pediatria'},
        ],
      }).especialidades();

      expect(itens.map((e) => e.nome), ['Cardiologia', 'Pediatria']);
      expect(pedidos.single.url.path, '/especialidades');
    });

    test('sem o token da conta: o catálogo é público', () async {
      await catalogo({'especialidades': <Object>[]}).especialidades();

      expect(pedidos.single.headers.containsKey('Authorization'), isFalse);
    });

    test('resposta fora do formato vira RESPOSTA_INESPERADA, e não erro de tipo', () async {
      await expectLater(catalogo({'especialidades': 'não é lista'}).especialidades(), respostaInesperada);
    });

    test('um item fora do formato também', () async {
      await expectLater(
        catalogo({
          'especialidades': [
            {'id': 1},
          ],
        }).especialidades(),
        respostaInesperada,
      );
    });
  });

  group('profissionais', () {
    const timbo = {
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
    };

    Map<String, Object?> pagina(List<Object?> itens, {int pagina = 1, int paginas = 1, int? total}) => {
          'profissionais': itens,
          'paginacao': {'pagina': pagina, 'limite': 20, 'total': total ?? itens.length, 'paginas': paginas},
        };

    test('lê o profissional com a especialidade, o valor e a clínica', () async {
      final resultado = await catalogo(pagina([timbo])).profissionais();

      final profissional = resultado.itens.single;
      expect(profissional.id, 2);
      expect(profissional.nome, 'Carlos Eduardo Timbó');
      expect(profissional.registroConselho, 'CRM-CE 12345');
      expect(profissional.especialidade?.id, 2);
      expect(profissional.especialidade?.nome, 'Cardiologia');
      expect(profissional.valorFormatado, 'R\$ 250,00');
      expect(profissional.clinica?.nome, 'Clínica Exemplo Quixadá');
      expect(profissional.clinica?.telefone, '(88) 3000-0000');
      expect(profissional.clinica?.endereco, 'Centro, Quixadá - CE');
    });

    test('sem filtro, pede a primeira página de /profissionais, e mais nada', () async {
      await catalogo(pagina([])).profissionais();

      expect(pedidos.single.url.path, '/profissionais');
      expect(pedidos.single.url.queryParameters, {'pagina': '1'});
    });

    test('especialidade, texto e página vão com os nomes que a API espera', () async {
      await catalogo(pagina([])).profissionais(especialidadeId: 2, termo: 'ana', pagina: 3);

      expect(pedidos.single.url.queryParameters, {'especialidade': '2', 'q': 'ana', 'pagina': '3'});
    });

    test('só a especialidade: nada de texto na consulta', () async {
      await catalogo(pagina([])).profissionais(especialidadeId: 5);

      expect(pedidos.single.url.queryParameters, {'especialidade': '5', 'pagina': '1'});
    });

    test('sem o token da conta: o que a pessoa busca não vai junto de quem ela é', () async {
      await catalogo(pagina([])).profissionais(termo: 'ana');

      expect(pedidos.single.headers.containsKey('Authorization'), isFalse);
    });

    test('especialidade e clínica podem vir nulas', () async {
      final resultado = await catalogo(pagina([
        {...timbo, 'especialidade': null, 'clinica': null},
      ])).profissionais();

      expect(resultado.itens.single.especialidade, isNull);
      expect(resultado.itens.single.clinica, isNull);
    });

    test('telefone e endereço da clínica podem vir nulos', () async {
      final resultado = await catalogo(pagina([
        {
          ...timbo,
          'clinica': {'id': 1, 'nome': 'Clínica Exemplo Quixadá', 'telefone': null, 'endereco': null},
        },
      ])).profissionais();

      final clinica = resultado.itens.single.clinica!;
      expect(clinica.nome, 'Clínica Exemplo Quixadá');
      expect(clinica.telefone, isNull);
      expect(clinica.endereco, isNull);
    });

    test('a paginação diz em que página se está e se há mais', () async {
      final meio = await catalogo(pagina([timbo], pagina: 2, paginas: 3, total: 45)).profissionais(pagina: 2);
      expect(meio.pagina, 2);
      expect(meio.paginas, 3);
      expect(meio.total, 45);
      expect(meio.temMais, isTrue);

      final ultima = await catalogo(pagina([timbo], pagina: 3, paginas: 3, total: 45)).profissionais(pagina: 3);
      expect(ultima.temMais, isFalse);
    });

    test('busca sem resultado: lista vazia, zero páginas, nada mais a mostrar', () async {
      final resultado = await catalogo(pagina([], paginas: 0)).profissionais(termo: 'zz');

      expect(resultado.itens, isEmpty);
      expect(resultado.total, 0);
      expect(resultado.temMais, isFalse);
    });

    test('profissional fora do formato vira RESPOSTA_INESPERADA', () async {
      await expectLater(
        catalogo(pagina([
          {...timbo, 'valorFormatado': 25000},
        ])).profissionais(),
        respostaInesperada,
      );
    });

    test('especialidade ou clínica fora do formato também', () async {
      await expectLater(
        catalogo(pagina([
          {...timbo, 'especialidade': 'Cardiologia'},
        ])).profissionais(),
        respostaInesperada,
      );
      await expectLater(
        catalogo(pagina([
          {
            ...timbo,
            'clinica': {'id': 1, 'telefone': '(88) 3000-0000'},
          },
        ])).profissionais(),
        respostaInesperada,
      );
    });

    test('lista sem a paginação, ou com ela fora do formato, também', () async {
      await expectLater(catalogo({'profissionais': [timbo]}).profissionais(), respostaInesperada);
      await expectLater(
        catalogo({
          'profissionais': [timbo],
          'paginacao': {'pagina': '1', 'limite': 20, 'total': 1, 'paginas': 1},
        }).profissionais(),
        respostaInesperada,
      );
    });

    test('corpo que nem objeto é também', () async {
      await expectLater(catalogo(<Object>[]).profissionais(), respostaInesperada);
    });
  });

  group('resposta fora do formato, no log do aparelho', () {
    late List<String> registro;
    setUp(() {
      registro = [];
      final original = debugPrint;
      debugPrint = (mensagem, {wrapWidth}) => registro.add(mensagem ?? '');
      addTearDown(() => debugPrint = original);
    });

    test('diz o recurso e o motivo — o do modelo, quando é um item que não serve', () async {
      await expectLater(
        catalogo({
          'profissionais': [
            {'id': 2},
          ],
          'paginacao': {'pagina': 1, 'limite': 20, 'total': 1, 'paginas': 1},
        }).profissionais(),
        respostaInesperada,
      );

      expect(registro, ['Resposta fora do formato em "profissionais": Profissional fora do formato esperado.']);
    });

    test('lista que não é lista, e paginação que não veio', () async {
      await expectLater(catalogo({'especialidades': 'nenhuma'}).especialidades(), respostaInesperada);
      await expectLater(catalogo({'profissionais': <Object>[]}).profissionais(), respostaInesperada);

      expect(registro, [
        'Resposta fora do formato em "especialidades": não veio uma lista.',
        'Resposta fora do formato em "profissionais": a paginação não veio, ou veio fora do formato.',
      ]);
    });

    test('horário com o instante sem fuso', () async {
      await expectLater(
        catalogo({
          'horarios': [
            {'id': 1, 'inicio': '2026-10-15T14:30:00.000', 'duracaoMinutos': 30, 'versao': 0},
          ],
        }).horarios(2, ate: DataCivil.tentar(2026, 10, 28)!),
        respostaInesperada,
      );

      expect(registro, ['Resposta fora do formato em "horarios": Instante sem fuso: a API sempre manda UTC.']);
    });

    test('resposta no formato não deixa nada no log', () async {
      await catalogo({'especialidades': <Object>[]}).especialidades();

      expect(registro, isEmpty);
    });
  });

  group('horários', () {
    Map<String, Object?> grade(List<Object?> horarios) => {
          'periodo': {'de': '2026-10-13T15:00:00.000Z', 'ate': '2026-10-27T03:00:00.000Z'},
          'horarios': horarios,
        };

    Map<String, Object?> horario(int id, String inicio, {int versao = 0}) => {
          'id': id,
          'inicio': inicio,
          'fim': '2026-10-15T18:00:00.000Z',
          'duracaoMinutos': 30,
          'versao': versao,
        };

    final ate = DataCivil.tentar(2026, 10, 27)!;

    test('pede a grade do profissional até o dia dado, como data sem hora', () async {
      await catalogo(grade([])).horarios(2, ate: ate);

      expect(pedidos.single.url.path, '/profissionais/2/horarios');
      expect(pedidos.single.url.queryParameters, {'ate': '2026-10-27'});
    });

    test('sem o token da conta', () async {
      await catalogo(grade([])).horarios(2, ate: ate);

      expect(pedidos.single.headers.containsKey('Authorization'), isFalse);
    });

    test('lê o horário com o instante em UTC e a versão que a API mandou', () async {
      final horarios = await catalogo(grade([
        horario(41, '2026-10-15T17:30:00.000Z', versao: 3),
      ])).horarios(2, ate: ate);

      final lido = horarios.single;
      expect(lido.id, 41);
      expect(lido.inicio, DateTime.utc(2026, 10, 15, 17, 30));
      expect(lido.inicio.isUtc, isTrue);
      expect(lido.duracaoMinutos, 30);
      // É a versão que volta no pedido de agendamento (lock otimista).
      expect(lido.versao, 3);
    });

    test('o dia e a hora do horário são os da clínica', () async {
      final horarios = await catalogo(grade([
        horario(1, '2026-10-15T17:30:00.000Z'),
        // 22:30 em Fortaleza: em UTC já é o dia 16.
        horario(2, '2026-10-16T01:30:00.000Z'),
      ])).horarios(2, ate: ate);

      expect(horarios[0].dia, DataCivil.tentar(2026, 10, 15));
      expect(horarios[0].hora, '14:30');
      expect(horarios[1].dia, DataCivil.tentar(2026, 10, 15));
      expect(horarios[1].hora, '22:30');
    });

    test('manhã é antes do meio-dia na clínica', () async {
      final horarios = await catalogo(grade([
        // 08:00, 11:30 e 12:00 em Fortaleza.
        horario(1, '2026-10-15T11:00:00.000Z'),
        horario(2, '2026-10-15T14:30:00.000Z'),
        horario(3, '2026-10-15T15:00:00.000Z'),
      ])).horarios(2, ate: ate);

      expect(horarios.map((h) => h.deManha), [true, true, false]);
    });

    test('mantém a ordem em que a API mandou', () async {
      final horarios = await catalogo(grade([
        horario(7, '2026-10-15T11:00:00.000Z'),
        horario(3, '2026-10-15T11:30:00.000Z'),
        horario(9, '2026-10-16T11:00:00.000Z'),
      ])).horarios(2, ate: ate);

      expect(horarios.map((h) => h.id), [7, 3, 9]);
    });

    test('horário sem a duração vira RESPOSTA_INESPERADA', () async {
      await expectLater(
        catalogo(grade([
          {'id': 41, 'inicio': '2026-10-15T17:30:00.000Z', 'fim': '2026-10-15T18:00:00.000Z', 'versao': 0},
        ])).horarios(2, ate: ate),
        respostaInesperada,
      );
    });

    test('horário sem a versão vira RESPOSTA_INESPERADA', () async {
      await expectLater(
        catalogo(grade([
          {'id': 41, 'inicio': '2026-10-15T17:30:00.000Z', 'fim': '2026-10-15T18:00:00.000Z', 'duracaoMinutos': 30},
        ])).horarios(2, ate: ate),
        respostaInesperada,
      );
    });

    test('instante sem fuso, ou que nem data é, também', () async {
      await expectLater(
        catalogo(grade([horario(41, '2026-10-15T14:30:00.000')])).horarios(2, ate: ate),
        respostaInesperada,
      );
      await expectLater(
        catalogo(grade([horario(41, 'quinta à tarde')])).horarios(2, ate: ate),
        respostaInesperada,
      );
    });

    test('grade fora do formato também', () async {
      await expectLater(catalogo({'horarios': 'nenhum'}).horarios(2, ate: ate), respostaInesperada);
    });
  });
}
