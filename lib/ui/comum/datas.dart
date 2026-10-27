import '../../domain/models/data_civil.dart';
import 'textos.dart';

// Como as datas aparecem para o paciente (checklist, item 2.4): o dia da
// semana por extenso, dia e mês, e o ano só quando não for o corrente.
//
// Os nomes dos dias ficam aqui, e não nos dados de idioma do pacote intl: são
// sete palavras, o aplicativo tem um idioma só, e assim nada precisa ser
// inicializado antes de uma data aparecer — nem no aplicativo, nem num teste.
const _porExtenso = ['segunda-feira', 'terça-feira', 'quarta-feira', 'quinta-feira', 'sexta-feira', 'sábado', 'domingo'];
const _abreviados = ['seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
const _meses = [
  'janeiro', 'fevereiro', 'março', 'abril', 'maio', 'junho', //
  'julho', 'agosto', 'setembro', 'outubro', 'novembro', 'dezembro',
];

String _dois(int numero) => numero.toString().padLeft(2, '0');

/// "15/10", sem o ano — para onde ele nunca é preciso, como a faixa de dias,
/// que não passa de 60 dias.
String diaEMesSemAno(DataCivil dia) => '${_dois(dia.dia)}/${_dois(dia.mes)}';

/// "15/10" — ou "15/10/2027", quando o ano não é o de [hoje].
String diaEMes(DataCivil dia, {required DataCivil hoje}) {
  final semAno = diaEMesSemAno(dia);
  return dia.ano == hoje.ano ? semAno : '$semAno/${dia.ano}';
}

/// "quinta-feira, 15/10".
String diaPorExtenso(DataCivil dia, {required DataCivil hoje}) =>
    '${_porExtenso[dia.diaDaSemana - 1]}, ${diaEMes(dia, hoje: hoje)}';

/// "qui, 15/10" — para onde o espaço é curto.
String diaCurto(DataCivil dia, {required DataCivil hoje}) =>
    '${_abreviados[dia.diaDaSemana - 1]}, ${diaEMes(dia, hoje: hoje)}';

/// "qui" — o rótulo de um dia na faixa de dias.
String diaAbreviado(DataCivil dia) => _abreviados[dia.diaDaSemana - 1];

/// "outubro" — ou "janeiro de 2027", quando o ano não é o de [hoje].
String mesDoAno(DataCivil dia, {required DataCivil hoje}) {
  final mes = _meses[dia.mes - 1];
  return dia.ano == hoje.ano ? mes : '$mes de ${dia.ano}';
}

/// "Hoje" e "Amanhã", para os dois dias em que o nome diz mais que a data;
/// null para os outros.
String? diaRelativo(DataCivil dia, {required DataCivil hoje}) {
  if (dia == hoje) return 'Hoje';
  if (dia == hoje.maisDias(1)) return 'Amanhã';
  return null;
}

/// "Amanhã, quinta-feira, 15/10", ou "Segunda-feira, 19/10" — o dia com tudo
/// o que o identifica, para começar uma linha.
String diaPorInteiro(DataCivil dia, {required DataCivil hoje}) {
  final relativo = diaRelativo(dia, hoje: hoje);
  final porExtenso = diaPorExtenso(dia, hoje: hoje);
  return relativo == null ? comInicialMaiuscula(porExtenso) : '$relativo, $porExtenso';
}

/// "Amanhã, quinta-feira, 15/10 · 14:30": o dia por inteiro e a hora. A data e
/// a hora não se separam numa quebra de linha, e o ponto do meio não fica
/// sozinho no fim de uma.
String diaEHora(DataCivil dia, String hora, {required DataCivil hoje}) =>
    '${diaPorInteiro(dia, hoje: hoje)}\u00a0·\u00a0$hora';
