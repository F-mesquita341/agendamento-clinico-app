import 'data_civil.dart';

/// O que o paciente preenche no cadastro e na edição dos dados. O e-mail não
/// entra: é o da conta, e a API o lê do token.
class DadosDoPaciente {
  const DadosDoPaciente({required this.nome, this.telefone, this.dataNascimento});

  /// Já sem espaços sobrando — como a API guarda.
  final String nome;

  /// Só os dígitos, com DDD.
  final String? telefone;
  final DataCivil? dataNascimento;

  /// Corpo do cadastro: campo opcional vazio fica de fora.
  Map<String, Object?> paraCadastro() => {
        'nome': nome,
        'telefone': ?telefone,
        'dataNascimento': ?dataNascimento?.paraApi(),
      };

  /// Corpo da edição: campo opcional vazio vai como null, que é como se apaga
  /// na API — omiti-lo deixaria o valor antigo lá.
  Map<String, Object?> paraEdicao() => {
        'nome': nome,
        'telefone': telefone,
        'dataNascimento': dataNascimento?.paraApi(),
      };
}
