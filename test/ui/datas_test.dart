import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/ui/comum/datas.dart';
import 'package:flutter_test/flutter_test.dart';

/// As datas como o paciente as lê (checklist, item 2.4).
void main() {
  group('mês do ano', () {
    final hoje = DataCivil.tentar(2026, 10, 15)!;

    test('o nome do mês, sem o ano quando é o corrente', () {
      expect(mesDoAno(DataCivil.tentar(2026, 10, 1)!, hoje: hoje), 'outubro');
      expect(mesDoAno(DataCivil.tentar(2026, 3, 9)!, hoje: hoje), 'março');
      expect(mesDoAno(DataCivil.tentar(2026, 12, 31)!, hoje: hoje), 'dezembro');
    });

    test('com o ano quando não é o corrente', () {
      expect(mesDoAno(DataCivil.tentar(2027, 1, 4)!, hoje: hoje), 'janeiro de 2027');
    });
  });

  final hoje = DataCivil.tentar(2026, 10, 13)!;
  final quinta = DataCivil.tentar(2026, 10, 15)!;

  test('dia da semana por extenso, dia e mês', () {
    expect(diaPorExtenso(quinta, hoje: hoje), 'quinta-feira, 15/10');
    expect(diaPorExtenso(DataCivil.tentar(2026, 10, 18)!, hoje: hoje), 'domingo, 18/10');
    expect(diaPorExtenso(DataCivil.tentar(2026, 11, 2)!, hoje: hoje), 'segunda-feira, 02/11');
  });

  test('o ano aparece só quando não é o corrente', () {
    expect(diaEMes(quinta, hoje: hoje), '15/10');
    expect(diaEMes(DataCivil.tentar(2027, 1, 2)!, hoje: hoje), '02/01/2027');
    expect(diaPorExtenso(DataCivil.tentar(2027, 1, 2)!, hoje: hoje), 'sábado, 02/01/2027');
  });

  test('forma curta, para onde o espaço é pouco', () {
    expect(diaCurto(quinta, hoje: hoje), 'qui, 15/10');
    expect(diaAbreviado(quinta), 'qui');
    expect(diaAbreviado(DataCivil.tentar(2026, 10, 17)!), 'sáb');
  });

  test('"Hoje" e "Amanhã", e nada para os outros dias', () {
    expect(diaRelativo(hoje, hoje: hoje), 'Hoje');
    expect(diaRelativo(DataCivil.tentar(2026, 10, 14)!, hoje: hoje), 'Amanhã');
    expect(diaRelativo(quinta, hoje: hoje), isNull);
    // Ontem não é "Hoje" nem "Amanhã".
    expect(diaRelativo(DataCivil.tentar(2026, 10, 12)!, hoje: hoje), isNull);
  });

  test('amanhã atravessa o mês', () {
    final ultimo = DataCivil.tentar(2026, 10, 31)!;
    expect(diaRelativo(DataCivil.tentar(2026, 11, 1)!, hoje: ultimo), 'Amanhã');
  });
}
