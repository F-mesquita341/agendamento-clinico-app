/// A cidade de uma clínica, como a API a cadastra: uma tabela própria, para
/// "Quixadá" e "Quixada" não virarem duas cidades.
class Cidade {
  const Cidade({required this.id, required this.nome, required this.uf});

  factory Cidade.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    final uf = json['uf'];
    if (id is! int || nome is! String || uf is! String) {
      throw const FormatException('Cidade fora do formato esperado.');
    }
    return Cidade(id: id, nome: nome, uf: uf);
  }

  final int id;
  final String nome;

  /// "CE".
  final String uf;

  /// "Quixadá, CE".
  String get rotulo => '$nome, $uf';
}
