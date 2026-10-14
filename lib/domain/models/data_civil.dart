import 'instante.dart';

/// Data de calendário, sem hora e sem fuso: a data de nascimento, um dia da
/// grade de horários.
///
/// A data de nascimento não passa por `instanteDaApi`. Um dia não é um
/// instante: convertido para um, em UTC, o 15 de março viraria 14 de março às
/// 21h no Brasil, e a tela mostraria o dia errado. Já o dia de um instante —
/// o de uma consulta — é sempre o da clínica: [DataCivil.naClinica].
class DataCivil implements Comparable<DataCivil> {
  const DataCivil._(this.ano, this.mes, this.dia);

  /// A data, se ela existe no calendário; null para 30/02, mês 13 e afins.
  static DataCivil? tentar(int ano, int mes, int dia) {
    if (mes < 1 || mes > 12 || dia < 1) return null;
    // DateTime.utc "normaliza" o que não existe — 30/02 vira 02/03. Se os
    // números mudaram, a data não existia.
    final normalizada = DateTime.utc(ano, mes, dia);
    if (normalizada.year != ano || normalizada.month != mes || normalizada.day != dia) return null;
    return DataCivil._(ano, mes, dia);
  }

  /// Lê o formato da API, `AAAA-MM-DD`. Ausente vira null; qualquer outra
  /// coisa fora do formato é recusada.
  static DataCivil? daApi(Object? valor) {
    if (valor == null) return null;
    final partes = valor is String ? RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(valor) : null;
    final data = partes == null
        ? null
        : tentar(int.parse(partes[1]!), int.parse(partes[2]!), int.parse(partes[3]!));
    if (data == null) throw const FormatException('Data fora do formato AAAA-MM-DD.');
    return data;
  }

  /// O dia do calendário da clínica em que cai um [instante]. Às 22:30 de
  /// Quixadá já é o dia seguinte em UTC: o dia que vale é o de lá.
  factory DataCivil.naClinica(DateTime instante) {
    final relogio = relogioDaClinica(instante);
    return DataCivil._(relogio.year, relogio.month, relogio.day);
  }

  /// Esta data mais [dias] dias — ou menos, com número negativo.
  DataCivil maisDias(int dias) {
    // DateTime.utc normaliza: dia 33 de outubro vira 2 de novembro.
    final soma = DateTime.utc(ano, mes, dia + dias);
    return DataCivil._(soma.year, soma.month, soma.day);
  }

  /// De 1, segunda-feira, a 7, domingo.
  int get diaDaSemana => DateTime.utc(ano, mes, dia).weekday;

  final int ano;
  final int mes;
  final int dia;

  /// O formato que a API espera: `AAAA-MM-DD`.
  String paraApi() => '${_digitos(ano, 4)}-${_digitos(mes, 2)}-${_digitos(dia, 2)}';

  /// O formato que o paciente lê: `dd/mm/aaaa` (checklist, item 2.4).
  String paraTela() => '${_digitos(dia, 2)}/${_digitos(mes, 2)}/${_digitos(ano, 4)}';

  @override
  int compareTo(DataCivil other) => paraApi().compareTo(other.paraApi());

  @override
  bool operator ==(Object other) => other is DataCivil && other.paraApi() == paraApi();

  @override
  int get hashCode => paraApi().hashCode;

  @override
  String toString() => 'DataCivil(${paraApi()})';

  static String _digitos(int numero, int largura) => numero.toString().padLeft(largura, '0');
}
