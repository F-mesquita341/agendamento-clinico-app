import 'package:flutter/material.dart';

import '../../config/tema.dart';

/// As iniciais de um nome: a primeira letra do primeiro nome e a do último.
/// Com um nome só, a primeira letra dele.
String iniciaisDe(String nome) {
  final partes = nome.trim().split(RegExp(r'\s+')).where((parte) => parte.isNotEmpty).toList();
  if (partes.isEmpty) return '';
  // Por caractere como a pessoa o vê: "Á" é uma letra, não duas.
  final primeira = partes.first.characters.first;
  if (partes.length == 1) return primeira.toUpperCase();
  return (primeira + partes.last.characters.first).toUpperCase();
}

/// A cor de fundo das iniciais: sempre a mesma para o mesmo nome, e espalhada
/// entre as cores do tema. A conta é própria — a soma dos códigos das letras —
/// porque o `hashCode` de um texto não tem garantia de ser o mesmo de uma
/// versão do Dart para outra, e a cor de cada profissional mudaria.
Color corDoAvatar(String nome) {
  var soma = 0;
  for (final codigo in nome.trim().codeUnits) {
    soma += codigo;
  }
  return coresDosAvatares[soma % coresDosAvatares.length];
}

/// O círculo com as iniciais, no lugar da foto que o aplicativo não tem
/// (checklist, item 8.10). É reforço visual: o nome vem sempre escrito ao
/// lado, e é ele que o leitor de tela lê.
class AvatarDeIniciais extends StatelessWidget {
  const AvatarDeIniciais({super.key, required this.nome, required this.tamanho});

  final String nome;
  final double tamanho;

  @override
  Widget build(BuildContext context) {
    final cores = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CircleAvatar(
        radius: tamanho / 2,
        backgroundColor: corDoAvatar(nome),
        // O CircleAvatar não deixa o conteúdo crescer com o texto ampliado: o
        // círculo tem tamanho fixo, e as iniciais sairiam dele.
        child: Text(
          iniciaisDe(nome),
          style: TextStyle(fontSize: tamanho * 0.36, fontWeight: FontWeight.w800, color: cores.onPrimary),
        ),
      ),
    );
  }
}
