import 'package:url_launcher/url_launcher.dart';

import 'abridor_de_links.dart';

/// O discador e o mapa de verdade, pelo pacote url_launcher.
///
/// Fino de propósito: o que dá para testar — os endereços `tel:` e `geo:` —
/// está em abridor_de_links.dart, com teste. Isto aqui só entrega o endereço ao
/// Android, e não tem teste automático: é conferido no portão, no emulador,
/// como o adaptador do Firebase.
class AbridorDeLinksDoAparelho implements AbridorDeLinks {
  @override
  Future<bool> ligar(String telefone) => _abrir(enderecoDoDiscador(telefone));

  @override
  Future<bool> abrirNoMapa(String lugar) => _abrir(enderecoDoMapa(lugar));

  /// Sem `canLaunchUrl`: no Android, abrir direto já devolve false quando não
  /// há aplicativo que atenda, e assim o manifesto não precisa declarar quais
  /// aplicativos o aplicativo procura.
  Future<bool> _abrir(Uri endereco) async {
    try {
      return await launchUrl(endereco, mode: LaunchMode.externalApplication);
    } on Exception {
      // PlatformException do Android, ou MissingPluginException sem o plugin
      // registrado: para a tela, é igual — não abriu.
      return false;
    }
  }
}
