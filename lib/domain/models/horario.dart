import 'data_civil.dart';
import 'instante.dart';

/// Um horário livre na agenda de um profissional — termo da linguagem ubíqua.
/// Nunca "vaga" nem "slot" (checklist, item 2.2).
///
/// A [versao] é a que a API mandou junto com o horário, e é ela que volta no
/// pedido de agendamento. É assim que a API percebe que outra pessoa reservou
/// o mesmo horário nesse meio-tempo (lock otimista; TCC, Seção 3.8.3). Sem a
/// versão, não há como detectar a colisão.
class Horario {
  const Horario({required this.id, required this.inicio, required this.duracaoMinutos, required this.versao});

  factory Horario.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final duracao = json['duracaoMinutos'];
    final versao = json['versao'];
    if (id is! int || duracao is! int || versao is! int) {
      throw const FormatException('Horário fora do formato esperado.');
    }
    return Horario(id: id, inicio: instanteDaApi(json['inicio']), duracaoMinutos: duracao, versao: versao);
  }

  final int id;

  /// O instante em que a consulta começa, em UTC.
  final DateTime inicio;

  /// Quanto a consulta dura. É do horário, e não do profissional: a agenda
  /// pode ter horários de durações diferentes.
  final int duracaoMinutos;
  final int versao;

  /// O dia da consulta, no calendário da clínica.
  DataCivil get dia => DataCivil.naClinica(inicio);

  /// "14:30", no horário da clínica.
  String get hora => horaNaClinica(inicio);

  /// Antes do meio-dia, na clínica.
  bool get deManha => relogioDaClinica(inicio).hour < 12;
}

/// O primeiro horário livre de um profissional, como vem na busca. Só para
/// mostrar: não traz a versão, e por isso não serve para agendar — quem
/// agenda lê a grade de novo, no perfil.
class ProximoHorario {
  const ProximoHorario({required this.id, required this.inicio});

  factory ProximoHorario.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    if (id is! int) {
      throw const FormatException('Próximo horário fora do formato esperado.');
    }
    return ProximoHorario(id: id, inicio: instanteDaApi(json['inicio']));
  }

  final int id;

  /// Em UTC.
  final DateTime inicio;

  /// O dia, no calendário da clínica.
  DataCivil get dia => DataCivil.naClinica(inicio);

  /// "09:00", no horário da clínica.
  String get hora => horaNaClinica(inicio);
}
