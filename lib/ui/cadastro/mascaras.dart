import 'package:flutter/services.dart';

/// Máscaras do cadastro (checklist, item 5.4), escritas à mão: são duas, e
/// simples — não justificam um pacote.

/// Os dígitos de um texto, até o limite.
String digitos(String texto, {int? limite}) {
  final so = texto.replaceAll(RegExp(r'\D'), '');
  return limite == null || so.length <= limite ? so : so.substring(0, limite);
}

/// `(88) 3000-0000` ou `(88) 99999-0000`. Enquanto a pessoa digita, o número
/// é tratado como fixo (4 + 4); o décimo primeiro dígito o torna celular
/// (5 + 4).
///
/// Número com o código do Brasil — o preenchimento automático do Android e o
/// "colar" costumam trazer `+55 88 99999-0000` — perde o 55: cortar pelo fim
/// guardaria outro telefone, válido e errado, sem ninguém perceber. Só nos
/// casos sem ambiguidade: o "+55" na frente, ou 13 dígitos começando por 55,
/// que só chegam colados. Quem tem DDD 55 e digita um dígito a mais continua
/// com o excedente ignorado, como qualquer outro DDD.
String formatarTelefone(String texto) {
  var d = digitos(texto);
  final comCodigoDoPais = texto.trimLeft().startsWith('+55') || (d.length == 13 && d.startsWith('55'));
  if (comCodigoDoPais) d = d.substring(2);
  if (d.length > 11) d = d.substring(0, 11);
  if (d.isEmpty) return '';
  if (d.length <= 2) return '($d';
  final ddd = d.substring(0, 2);
  final numero = d.substring(2);
  if (numero.length <= 4) return '($ddd) $numero';
  final corte = d.length == 11 ? 5 : 4;
  return '($ddd) ${numero.substring(0, corte)}-${numero.substring(corte)}';
}

/// `dd/mm/aaaa`. Data que chega inteira no formato `AAAA-MM-DD` — o do
/// preenchimento automático — é reordenada, em vez de virar "19/90/0315".
String formatarData(String texto) {
  final iso = RegExp(r'^\s*(\d{4})-(\d{2})-(\d{2})\s*$').firstMatch(texto);
  final d = iso == null ? digitos(texto, limite: 8) : '${iso[3]}${iso[2]}${iso[1]}';
  if (d.length <= 2) return d;
  if (d.length <= 4) return '${d.substring(0, 2)}/${d.substring(2)}';
  return '${d.substring(0, 2)}/${d.substring(2, 4)}/${d.substring(4)}';
}

/// Aplica uma das formatações acima a cada tecla, com o cursor no fim.
class Mascara extends TextInputFormatter {
  const Mascara(this._formatar);

  const Mascara.telefone() : this(formatarTelefone);
  const Mascara.data() : this(formatarData);

  final String Function(String) _formatar;

  /// A formatação nunca termina em pontuação, então apagar do fim sempre
  /// apaga um dígito.
  @override
  TextEditingValue formatEditUpdate(TextEditingValue antes, TextEditingValue depois) {
    final texto = _formatar(depois.text);
    return TextEditingValue(text: texto, selection: TextSelection.collapsed(offset: texto.length));
  }
}
