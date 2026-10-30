import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/services/abridor_de_links.dart';
import '../../domain/models/clinica.dart';
import 'retorno.dart';

/// "Abrir no mapa" e "Ligar", lado a lado (checklist, itens 2.9 e 10.3).
/// Cada um só aparece se a clínica tem o dado; e, se o aparelho não tem com o
/// que abrir, o endereço ou o número vai na mensagem.
class AtalhosDaClinica extends StatelessWidget {
  const AtalhosDaClinica({super.key, required this.clinica, this.rotuloDeLigar = 'Ligar'});

  final Clinica clinica;

  /// "Ligar", ao lado do nome da clínica; "Ligar para a clínica", onde ela não
  /// está escrita logo acima.
  final String rotuloDeLigar;

  @override
  Widget build(BuildContext context) {
    final endereco = clinica.endereco;
    final telefone = clinica.telefone;
    return Row(
      children: [
        if (endereco != null)
          Expanded(
            child: TextButton.icon(
              onPressed: () => _abrir(
                context,
                // O nome da clínica ajuda o mapa a achar o lugar certo no endereço.
                (abridor) => abridor.abrirNoMapa('${clinica.nome}, $endereco'),
                seFalhar: 'Não foi possível abrir o mapa. O endereço é $endereco.',
              ),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Abrir no mapa'),
            ),
          ),
        if (telefone != null)
          Expanded(
            child: TextButton.icon(
              onPressed: () => ligarParaAClinica(context, telefone),
              icon: const Icon(Icons.call_outlined),
              label: Text(rotuloDeLigar),
            ),
          ),
      ],
    );
  }

}

/// Abre o discador com o telefone da clínica — daqui, do Perfil e do "Como
/// funciona".
Future<void> ligarParaAClinica(BuildContext context, String telefone) => _abrir(
      context,
      (abridor) => abridor.ligar(telefone),
      seFalhar: 'Não foi possível abrir o telefone. O número da clínica é $telefone.',
    );

/// Sai do aplicativo para o mapa ou o discador. Se o aparelho não tem com o
/// que abrir, o dado vai na mensagem, para a pessoa usá-lo como puder.
Future<void> _abrir(
  BuildContext context,
  Future<bool> Function(AbridorDeLinks abridor) abrir, {
  required String seFalhar,
}) async {
  final abriu = await abrir(context.read<AbridorDeLinks>());
  if (!abriu && context.mounted) mostrarRetorno(context, TipoDeRetorno.erro, seFalhar);
}
