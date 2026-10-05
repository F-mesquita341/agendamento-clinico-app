/// Especialidade médica, como a clínica a nomeia — termo da linguagem ubíqua.
class Especialidade {
  const Especialidade({required this.id, required this.nome});

  factory Especialidade.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    if (id is! int || nome is! String) {
      throw const FormatException('Especialidade fora do formato esperado.');
    }
    return Especialidade(id: id, nome: nome);
  }

  final int id;
  final String nome;
}
