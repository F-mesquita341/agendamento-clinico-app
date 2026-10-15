import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lê o formato da API e devolve os mesmos números, sem fuso no meio', () {
    final data = DataCivil.daApi('1990-03-15')!;

    expect((data.ano, data.mes, data.dia), (1990, 3, 15));
    expect(data.paraApi(), '1990-03-15');
  });

  test('ausente é null', () {
    expect(DataCivil.daApi(null), isNull);
  });

  test('data que não existe no calendário é recusada, em vez de normalizada', () {
    // DateTime aceitaria 30/02 e devolveria 02/03 — a pessoa veria outra data.
    expect(DataCivil.tentar(2026, 2, 30), isNull);
    expect(DataCivil.tentar(2026, 13, 1), isNull);
    expect(DataCivil.tentar(2026, 4, 31), isNull);
    expect(() => DataCivil.daApi('2026-02-30'), throwsFormatException);
  });

  test('29 de fevereiro existe só em ano bissexto', () {
    expect(DataCivil.tentar(2024, 2, 29), isNotNull);
    expect(DataCivil.tentar(2026, 2, 29), isNull);
  });

  test('texto fora do formato é recusado', () {
    expect(() => DataCivil.daApi('15/03/1990'), throwsFormatException);
    expect(() => DataCivil.daApi('1990-3-15'), throwsFormatException);
    expect(() => DataCivil.daApi(19900315), throwsFormatException);
  });

  test('na tela, dd/mm/aaaa com zeros à esquerda', () {
    expect(DataCivil.tentar(2001, 2, 3)!.paraTela(), '03/02/2001');
    expect(DataCivil.tentar(2001, 2, 3)!.paraApi(), '2001-02-03');
  });

  test('o dia de um instante é o do calendário da clínica', () {
    // 22:30 do dia 14 em Quixadá: em UTC, já é dia 15.
    expect(DataCivil.naClinica(DateTime.utc(2026, 10, 15, 1, 30)), DataCivil.tentar(2026, 10, 14));
    // Meia-noite em Quixadá: o dia vira.
    expect(DataCivil.naClinica(DateTime.utc(2026, 10, 15, 3)), DataCivil.tentar(2026, 10, 15));
  });

  test('somar dias atravessa o mês e o ano', () {
    expect(DataCivil.tentar(2026, 10, 30)!.maisDias(3), DataCivil.tentar(2026, 11, 2));
    expect(DataCivil.tentar(2026, 12, 31)!.maisDias(1), DataCivil.tentar(2027, 1, 1));
    expect(DataCivil.tentar(2026, 3, 1)!.maisDias(-1), DataCivil.tentar(2026, 2, 28));
  });

  test('dia da semana, de 1 (segunda-feira) a 7 (domingo)', () {
    expect(DataCivil.tentar(2026, 10, 15)!.diaDaSemana, 4);
    expect(DataCivil.tentar(2026, 10, 18)!.diaDaSemana, 7);
    expect(DataCivil.tentar(2026, 10, 19)!.diaDaSemana, 1);
  });

  test('compara pela ordem do calendário', () {
    final antes = DataCivil.tentar(1999, 12, 31)!;
    final depois = DataCivil.tentar(2000, 1, 1)!;

    expect(antes.compareTo(depois), lessThan(0));
    expect(depois.compareTo(antes), greaterThan(0));
    expect(antes.compareTo(DataCivil.tentar(1999, 12, 31)!), 0);
  });
}
