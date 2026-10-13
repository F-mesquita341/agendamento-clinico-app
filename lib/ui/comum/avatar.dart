import 'package:flutter/material.dart';

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
        backgroundColor: cores.primary,
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
