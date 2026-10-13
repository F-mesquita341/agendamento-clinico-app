import 'data_civil.dart';
import 'instante.dart';

/// O perfil do paciente, como a API o devolve em `GET /pacientes/me`.
///
/// O e-mail é o da conta — vem do token, e não se edita aqui. O consentimento
/// diz a qual texto do termo a pessoa deu o aceite, e quando.
class Paciente {
  const Paciente({
    required this.id,
    required this.nome,
    required this.email,
    required this.telefone,
    required this.dataNascimento,
    required this.versaoDoTermo,
    required this.termoAceitoEm,
  });

  factory Paciente.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    final email = json['email'];
    final telefone = json['telefone'];
    final consentimento = json['consentimento'];
    if (id is! int ||
        nome is! String ||
        email is! String ||
        (telefone != null && telefone is! String) ||
        consentimento is! Map<String, Object?> ||
        consentimento['versao'] is! String) {
      throw const FormatException('Paciente fora do formato esperado.');
    }
    final aceitoEm = consentimento['aceitoEm'];
    return Paciente(
      id: id,
      nome: nome,
      email: email,
      telefone: telefone as String?,
      dataNascimento: DataCivil.daApi(json['dataNascimento']),
      versaoDoTermo: consentimento['versao']! as String,
      termoAceitoEm: aceitoEm == null ? null : instanteDaApi(aceitoEm),
    );
  }

  final int id;
  final String nome;
  final String email;

  /// Só os dígitos, com DDD — como a API guarda.
  final String? telefone;
  final DataCivil? dataNascimento;
  final String versaoDoTermo;

  /// No horário do aparelho.
  final DateTime? termoAceitoEm;
}
