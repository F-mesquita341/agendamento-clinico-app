/// A distância até a clínica, como o card a mostra e como o leitor de tela a
/// lê ("Perto de mim", versão 2): "a 2,3 km", lido "a 2,3 quilômetros".
///
/// Menos de 1 km vira "a menos de 1 km": a posição é a aproximada, e metros
/// prometeriam uma precisão que ela não tem. Até 10 km, com uma casa; daí em
/// diante, em quilômetros inteiros. O espaço antes de "km" não quebra.
({String texto, String leitura}) textoDaDistancia(double km) {
  if (km < 1) return (texto: 'a menos de 1 km', leitura: 'a menos de 1 quilômetro');
  final numero = km < 10 ? km.toStringAsFixed(1).replaceAll('.', ',') : km.round().toString();
  return (texto: 'a $numero km', leitura: 'a $numero quilômetros');
}
