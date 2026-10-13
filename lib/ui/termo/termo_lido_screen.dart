import 'package:flutter/material.dart';

import '../comum/defeitos.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import 'termos_conhecidos.dart';
import 'texto_do_termo.dart';

/// O termo que a pessoa aceitou, para reler a partir do perfil.
class TermoLidoScreen extends StatefulWidget {
  const TermoLidoScreen({super.key, required this.versao, required this.lerArquivo});

  final String versao;
  final Future<String> Function(String caminho) lerArquivo;

  @override
  State<TermoLidoScreen> createState() => _TermoLidoScreenState();
}

class _TermoLidoScreenState extends State<TermoLidoScreen> {
  late Future<String?> _texto = _carregar();

  Future<String?> _carregar() async {
    final arquivos = termosConhecidos[widget.versao];
    if (arquivos == null) return null;
    try {
      return await widget.lerArquivo(arquivos.termo);
    } catch (erro, pilha) {
      // O arquivo vem no pacote do aplicativo: não abrir é defeito, e é
      // relatado. A tela mostra a falha e deixa tentar de novo.
      relatarDefeito(erro, pilha, 'ao abrir o texto do termo');
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termo de consentimento')),
      body: SafeArea(
        child: FutureBuilder<String?>(
          future: _texto,
          builder: (context, carga) {
            if (carga.connectionState != ConnectionState.done) return const IndicadorDeCarga(demorando: false);
            if (carga.hasError) {
              // Falha ao abrir o arquivo não é "versão desconhecida": dizer
              // isso seria afirmar algo falso sobre o registro do aceite.
              return FalhaDeCarga(
                mensagem: 'Não foi possível abrir o texto do termo. Tente de novo.',
                // Bloco, e não seta: o setState recusa uma função que devolva
                // o Future atribuído.
                tentarDeNovo: () => setState(() {
                  _texto = _carregar();
                }),
              );
            }
            final texto = carga.data;
            return ListView(
              padding: const EdgeInsets.all(Espaco.margem),
              children: [
                if (texto != null)
                  TextoDoTermo(texto)
                else
                  // Uma versão antiga, que este aplicativo já não traz.
                  Text('O texto da versão ${widget.versao} não está nesta versão do aplicativo.'),
              ],
            );
          },
        ),
      ),
    );
  }
}
