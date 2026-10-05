import 'dart:convert';

import 'package:agendamento_clinico/data/repositories/repositorio_do_catalogo.dart';
import 'package:agendamento_clinico/data/services/api_client.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  RepositorioDoCatalogoRemoto catalogo(Object corpo) => RepositorioDoCatalogoRemoto(
        ApiClient(
          cliente: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(corpo)), 200)),
          base: Uri.parse('https://api.exemplo.test'),
        ),
      );

  test('lê as especialidades embrulhadas no nome do recurso', () async {
    final itens = await catalogo({
      'especialidades': [
        {'id': 1, 'nome': 'Cardiologia'},
        {'id': 2, 'nome': 'Pediatria'},
      ],
    }).especialidades();

    expect(itens.map((e) => e.nome), ['Cardiologia', 'Pediatria']);
  });

  test('resposta fora do formato vira RESPOSTA_INESPERADA, e não erro de tipo', () async {
    await expectLater(
      catalogo({'especialidades': 'não é lista'}).especialidades(),
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')),
    );
  });

  test('um item fora do formato também', () async {
    await expectLater(
      catalogo({
        'especialidades': [
          {'id': 1},
        ],
      }).especialidades(),
      throwsA(isA<ErroDaApi>().having((e) => e.codigo, 'codigo', 'RESPOSTA_INESPERADA')),
    );
  });
}
