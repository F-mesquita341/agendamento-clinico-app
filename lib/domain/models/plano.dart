/// Um plano de saúde que algum profissional aceita. Só o nome: o aplicativo
/// não pede carteirinha, e a clínica confere o plano no dia.
class Plano {
  const Plano({required this.id, required this.nome});

  factory Plano.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    if (id is! int || nome is! String) {
      throw const FormatException('Plano fora do formato esperado.');
    }
    return Plano(id: id, nome: nome);
  }

  final int id;
  final String nome;
}
