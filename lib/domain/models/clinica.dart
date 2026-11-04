import 'cidade.dart';

/// A clínica onde o profissional atende: o contato que o paciente usa para
/// ligar ou chegar ao local. Telefone e endereço podem não estar cadastrados.
///
/// A cidade e as coordenadas vieram com a versão 2 da API. Ausentes — a API
/// de produção, a v1 — ficam null, como os dados que não estão cadastrados.
class Clinica {
  const Clinica({required this.nome, this.telefone, this.endereco, this.cidade, this.latitude, this.longitude});

  factory Clinica.fromJson(Map<String, Object?> json) {
    final nome = json['nome'];
    final telefone = json['telefone'];
    final endereco = json['endereco'];
    final cidade = json['cidade'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    if (nome is! String ||
        telefone is! String? ||
        endereco is! String? ||
        cidade is! Map<String, Object?>? ||
        latitude is! num? ||
        longitude is! num?) {
      throw const FormatException('Clínica fora do formato esperado.');
    }
    return Clinica(
      nome: nome,
      telefone: telefone,
      endereco: endereco,
      cidade: cidade == null ? null : Cidade.fromJson(cidade),
      latitude: latitude?.toDouble(),
      longitude: longitude?.toDouble(),
    );
  }

  final String nome;
  final String? telefone;
  final String? endereco;
  final Cidade? cidade;

  /// As coordenadas, para calcular a distância no aparelho. Podem não estar
  /// cadastradas.
  final double? latitude;
  final double? longitude;
}
