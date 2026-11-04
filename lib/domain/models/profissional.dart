import 'clinica.dart';
import 'especialidade.dart';
import 'forma_de_pagamento.dart';
import 'horario.dart';
import 'plano.dart';

/// Quem atende — termo da linguagem ubíqua. Nunca "médico": nem todo
/// profissional da clínica é um (checklist, item 2.2).
///
/// O valor da consulta chega pronto para mostrar, como a API o escreve. Os
/// centavos não são lidos: o aplicativo não faz conta com dinheiro, e assim
/// também não tem como formatar um valor por conta própria.
///
/// Os planos, as formas de pagamento e o próximo horário vieram com a versão 2
/// da API. Ausentes, valem como na v1 — nenhum plano, só o pagamento pelo
/// aplicativo, horário desconhecido —, para o aplicativo continuar
/// funcionando contra a API de produção. Presentes com o tipo errado, a
/// resposta é recusada, como qualquer outro campo.
class Profissional {
  const Profissional({
    required this.id,
    required this.nome,
    required this.registroConselho,
    required this.valorFormatado,
    this.especialidade,
    this.clinica,
    this.planos = const [],
    this.formasDePagamento = const [FormaDePagamento.app],
    this.proximoHorario,
    this.informaProximoHorario = false,
  });

  factory Profissional.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final nome = json['nome'];
    final registro = json['registroConselho'];
    final valor = json['valorFormatado'];
    final especialidade = json['especialidade'];
    final clinica = json['clinica'];
    final planos = json['planos'];
    final formas = json['formasDePagamento'];
    final proximo = json['proximoHorario'];
    if (id is! int ||
        nome is! String ||
        registro is! String ||
        valor is! String ||
        especialidade is! Map<String, Object?>? ||
        clinica is! Map<String, Object?>? ||
        planos is! List<Object?>? ||
        formas is! List<Object?>? ||
        proximo is! Map<String, Object?>?) {
      throw const FormatException('Profissional fora do formato esperado.');
    }
    return Profissional(
      id: id,
      nome: nome,
      registroConselho: registro,
      valorFormatado: valor,
      especialidade: especialidade == null ? null : Especialidade.fromJson(especialidade),
      clinica: clinica == null ? null : Clinica.fromJson(clinica),
      planos: [
        for (final plano in planos ?? const <Object?>[])
          if (plano is Map<String, Object?>) Plano.fromJson(plano) else throw const FormatException('Plano fora do formato esperado.'),
      ],
      formasDePagamento: _formas(formas),
      proximoHorario: proximo == null ? null : ProximoHorario.fromJson(proximo),
      informaProximoHorario: json.containsKey('proximoHorario'),
    );
  }

  /// As formas que o aplicativo conhece, na ordem da API. Uma forma nova é
  /// deixada de fora; se nenhuma sobrar, vale a da v1.
  static List<FormaDePagamento> _formas(List<Object?>? formas) {
    if (formas == null) return const [FormaDePagamento.app];
    final conhecidas = [
      for (final forma in formas)
        if (forma is String) ?FormaDePagamento.daApi(forma) else throw const FormatException('Forma de pagamento fora do formato esperado.'),
    ];
    return conhecidas.isEmpty ? const [FormaDePagamento.app] : conhecidas;
  }

  final int id;
  final String nome;

  /// O registro no conselho da profissão, como a clínica o cadastrou.
  final String registroConselho;

  /// "R$ 250,00".
  final String valorFormatado;
  final Especialidade? especialidade;
  final Clinica? clinica;

  /// Os planos de saúde que o profissional aceita, em ordem de nome.
  final List<Plano> planos;

  /// Nunca vazia: no mínimo, o pagamento pelo aplicativo.
  final List<FormaDePagamento> formasDePagamento;

  /// O primeiro horário livre, só para mostrar; null quando não há — ou quando
  /// a API não informa, o que [informaProximoHorario] diz.
  final ProximoHorario? proximoHorario;

  /// A API mandou o próximo horário, mesmo que nulo. A de produção (v1) não
  /// manda: sem isto, todo card diria "sem horário livre".
  final bool informaProximoHorario;
}
