/// A API fala em instantes UTC, no formato ISO 8601. Toda data que chega da
/// API passa por aqui — e só por aqui.
///
/// O instante fica em UTC. Para mostrar, vale o horário da clínica, e não o do
/// aparelho: a consulta é presencial, e 14:30 é 14:30 em Quixadá, onde quer
/// que o celular esteja. É também o horário que o lembrete da API diz. O dia
/// sai de `DataCivil.naClinica`, e a hora, de [horaNaClinica].
DateTime instanteDaApi(Object? valor) {
  if (valor is! String) {
    throw const FormatException('Instante fora do formato ISO 8601.');
  }
  final instante = DateTime.parse(valor);
  if (!instante.isUtc) {
    // A API sempre manda o "Z" do UTC. Sem ele, o texto seria lido como hora
    // local, e o erro passaria despercebido em qualquer aparelho em UTC-3.
    throw const FormatException('Instante sem fuso: a API sempre manda UTC.');
  }
  return instante;
}

/// O deslocamento da clínica em relação ao UTC. O Ceará não tem horário de
/// verão, então é fixo — o mesmo valor que a API declara para ler as datas da
/// grade e escrever o lembrete.
const deslocamentoDaClinica = Duration(hours: -3);

/// O relógio de parede da clínica no [instante]: ano, mês, dia, hora e minuto
/// como estão lá. Serve só para ler esses campos — não é um instante, e não
/// se compara com um.
DateTime relogioDaClinica(DateTime instante) => instante.toUtc().add(deslocamentoDaClinica);

/// A hora na clínica, em 24 h: "14:30" (checklist, item 2.4).
String horaNaClinica(DateTime instante) {
  final relogio = relogioDaClinica(instante);
  String dois(int numero) => numero.toString().padLeft(2, '0');
  return '${dois(relogio.hour)}:${dois(relogio.minute)}';
}
