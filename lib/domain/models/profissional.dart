import 'clinica.dart';
import 'especialidade.dart';

/// Quem atende — termo da linguagem ubíqua. Nunca "médico": nem todo
/// profissional da clínica é um (checklist, item 2.2).
///
/// O valor da consulta chega pronto para mostrar, como a API o escreve. Os
/// centavos não são lidos: o aplicativo não faz conta com dinheiro, e assim
/// também não tem como formatar um valor por conta própria.
class Profissional {
  const Profissional({
    required this.id,
    required this.nome,
    required this.registroConselho,
    required this.valorFormatado,
    this.especialidade,
    this.clinica,
  });

  factory Profissional.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    final registro = json['registroConselho'];
    final valor = json['valorFormatado'];
    final especialidade = json['especialidade'];
    final clinica = json['clinica'];
    if (id is! int ||
        nome is! String ||
        registro is! String ||
        valor is! String ||
        especialidade is! Map<String, Object?>? ||
        clinica is! Map<String, Object?>?) {
      throw const FormatException('Profissional fora do formato esperado.');
    }
    return Profissional(
      id: id,
      nome: nome,
      registroConselho: registro,
      valorFormatado: valor,
      especialidade: especialidade == null ? null : Especialidade.fromJson(especialidade),
      clinica: clinica == null ? null : Clinica.fromJson(clinica),
    );
  }

  final int id;
  final String nome;

  /// O registro no conselho da profissão, como a clínica o cadastrou.
  final String registroConselho;

  /// "R$ 250,00".
  final String valorFormatado;
  final Especialidade? especialidade;
  final Clinica? clinica;
}
