/// Validações do cadastro, com as mesmas regras e, sempre que o formato da
/// tela permite, as mesmas mensagens da API (`src/interfaces/http/esquemas.js`):
/// a pessoa vê o erro enquanto digita, antes de qualquer pedido.
library;

import '../../domain/models/data_civil.dart';
import 'mascaras.dart';

/// O nome como a API guarda: sem espaços nas pontas nem repetidos no meio.
String normalizarNome(String texto) => texto.trim().replaceAll(RegExp(r'\s+'), ' ');

String? validarNome(String? valor) {
  final nome = normalizarNome(valor ?? '');
  if (nome.isEmpty) return 'Informe o nome.';
  if (nome.length < 2) return 'O nome precisa ter ao menos duas letras.';
  if (nome.length > 120) return 'O nome é longo demais.';
  return null;
}

/// Opcional: vazio passa.
String? validarTelefone(String? valor) {
  final d = digitos(valor ?? '');
  if (d.isEmpty) return null;
  if (d.length != 10 && d.length != 11) return 'Informe o telefone com DDD, com 10 ou 11 dígitos.';
  return null;
}

/// Opcional: vazio passa.
String? validarDataDeNascimento(String? valor, {DateTime? agora}) {
  final texto = valor ?? '';
  if (texto.isEmpty) return null;
  final partes = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);
  if (partes == null) return 'Informe a data completa, no formato dd/mm/aaaa.';
  final data = DataCivil.tentar(int.parse(partes[3]!), int.parse(partes[2]!), int.parse(partes[1]!));
  if (data == null) return 'Essa data de nascimento não existe no calendário.';
  if (data.ano < 1900) return 'Confira o ano da data de nascimento.';
  // "Hoje" é o dia na clínica, como na API: perto da meia-noite, o do aparelho
  // ou o do UTC já pode ser outro.
  if (data.compareTo(DataCivil.naClinica(agora ?? DateTime.now())) > 0) {
    return 'A data de nascimento não pode estar no futuro.';
  }
  return null;
}

/// A data digitada, já validada por [validarDataDeNascimento]; null se vazia.
DataCivil? lerDataDeNascimento(String texto) {
  final partes = RegExp(r'^(\d{2})/(\d{2})/(\d{4})$').firstMatch(texto);
  if (partes == null) return null;
  return DataCivil.tentar(int.parse(partes[3]!), int.parse(partes[2]!), int.parse(partes[1]!));
}
