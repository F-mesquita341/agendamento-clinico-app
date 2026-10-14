/// A clínica onde o profissional atende: o contato que o paciente usa para
/// ligar ou chegar ao local. Telefone e endereço podem não estar cadastrados.
class Clinica {
  const Clinica({required this.nome, this.telefone, this.endereco});

  factory Clinica.fromJson(Map<String, Object?> json) {
    final nome = json['nome'];
    final telefone = json['telefone'];
    final endereco = json['endereco'];
    if (nome is! String || telefone is! String? || endereco is! String?) {
      throw const FormatException('Clínica fora do formato esperado.');
    }
    return Clinica(nome: nome, telefone: telefone, endereco: endereco);
  }

  final String nome;
  final String? telefone;
  final String? endereco;
}
