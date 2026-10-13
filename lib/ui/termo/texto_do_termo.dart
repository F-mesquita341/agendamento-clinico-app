import 'package:flutter/material.dart';

import '../comum/espaco.dart';

/// Um bloco do texto do termo.
sealed class BlocoDoTermo {
  const BlocoDoTermo();
}

class Titulo extends BlocoDoTermo {
  const Titulo(this.texto, {required this.nivel});
  final String texto;
  final int nivel;
}

class Paragrafo extends BlocoDoTermo {
  const Paragrafo(this.texto);
  final String texto;
}

class Lista extends BlocoDoTermo {
  const Lista(this.itens);
  final List<String> itens;
}

class Separador extends BlocoDoTermo {
  const Separador();
}

/// Lê o texto do termo, escrito num pedaço pequeno de Markdown — o mesmo do
/// `docs/termo-de-consentimento.md` da API, de onde ele é copiado: títulos
/// (`#`, `##`), parágrafos, listas (`- `, com continuação recuada), régua
/// (`---`). Sem pacote de Markdown: o subconjunto é pequeno, e um teste
/// confere que nenhum símbolo sobra no texto mostrado.
List<BlocoDoTermo> lerBlocos(String markdown) {
  final blocos = <BlocoDoTermo>[];
  final paragrafo = <String>[];
  final itens = <String>[];

  void fecharParagrafo() {
    if (paragrafo.isNotEmpty) blocos.add(Paragrafo(paragrafo.join(' ')));
    paragrafo.clear();
  }

  void fecharLista() {
    if (itens.isNotEmpty) blocos.add(Lista([...itens]));
    itens.clear();
  }

  for (final linhaCrua in markdown.replaceAll('\r\n', '\n').split('\n')) {
    final linha = linhaCrua.trimRight();
    final titulo = RegExp(r'^(#{1,2}) (.+)$').firstMatch(linha);
    if (linha.isEmpty) {
      fecharParagrafo();
      fecharLista();
    } else if (titulo != null) {
      fecharParagrafo();
      fecharLista();
      blocos.add(Titulo(titulo[2]!, nivel: titulo[1]!.length));
    } else if (linha == '---') {
      fecharParagrafo();
      fecharLista();
      blocos.add(const Separador());
    } else if (linha.startsWith('- ')) {
      fecharParagrafo();
      itens.add(linha.substring(2));
    } else if (itens.isNotEmpty && linha.startsWith('  ')) {
      // Continuação do item anterior, recuada.
      itens[itens.length - 1] = '${itens.last} ${linha.trim()}';
    } else {
      fecharLista();
      paragrafo.add(linha.trim());
    }
  }
  fecharParagrafo();
  fecharLista();
  return blocos;
}

/// O texto em trechos: `**negrito**` vira negrito, e `` `código` `` vira texto
/// comum, sem as crases.
List<({String texto, bool negrito})> trechos(String linha) {
  final resultado = <({String texto, bool negrito})>[];
  final partes = linha.replaceAll('`', '').split('**');
  for (var i = 0; i < partes.length; i++) {
    if (partes[i].isNotEmpty) resultado.add((texto: partes[i], negrito: i.isOdd));
  }
  return resultado;
}

/// O termo na tela, a partir do Markdown.
class TextoDoTermo extends StatefulWidget {
  const TextoDoTermo(this.markdown, {super.key});

  final String markdown;

  @override
  State<TextoDoTermo> createState() => _TextoDoTermoState();
}

/// Os blocos são lidos uma vez e guardados: a tela do termo se reconstrói a
/// cada toque na caixa do aceite, e ler o texto inteiro de novo a cada toque
/// seria trabalho jogado fora.
class _TextoDoTermoState extends State<TextoDoTermo> {
  late List<BlocoDoTermo> _blocos = lerBlocos(widget.markdown);

  @override
  void didUpdateWidget(TextoDoTermo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.markdown != widget.markdown) _blocos = lerBlocos(widget.markdown);
  }

  @override
  Widget build(BuildContext context) {
    final estilos = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final bloco in _blocos)
          Padding(
            padding: const EdgeInsets.only(bottom: Espaco.medio),
            child: switch (bloco) {
              Titulo(:final texto, :final nivel) => Semantics(
                  header: true,
                  child: _Rico(texto, nivel == 1 ? estilos.titleLarge : estilos.titleMedium),
                ),
              Paragrafo(:final texto) => _Rico(texto, estilos.bodyLarge),
              Lista(:final itens) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final item in itens)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Espaco.pequeno),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ExcludeSemantics(child: Text('•  ', style: estilos.bodyLarge)),
                            Expanded(child: _Rico(item, estilos.bodyLarge)),
                          ],
                        ),
                      ),
                  ],
                ),
              Separador() => const Divider(),
            },
          ),
      ],
    );
  }
}

class _Rico extends StatelessWidget {
  const _Rico(this.texto, this.estilo);

  final String texto;
  final TextStyle? estilo;

  @override
  Widget build(BuildContext context) {
    return Text.rich(TextSpan(
      style: estilo,
      children: [
        for (final trecho in trechos(texto))
          TextSpan(
            text: trecho.texto,
            style: trecho.negrito ? const TextStyle(fontWeight: FontWeight.bold) : null,
          ),
      ],
    ));
  }
}
