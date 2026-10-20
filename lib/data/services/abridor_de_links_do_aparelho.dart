import 'package:url_launcher/url_launcher.dart';

import 'abridor_de_links.dart';

/// O discador, o mapa e a página de pagamento de verdade, pelo pacote
/// url_launcher.
///
/// Fino de propósito: o que dá para testar — os endereços `tel:` e `geo:` —
/// está em abridor_de_links.dart, com teste. Isto aqui só entrega o endereço ao
/// Android, e não tem teste automático: é conferido no portão, no emulador,
/// como o adaptador do Firebase.
class AbridorDeLinksDoAparelho implements AbridorDeLinks {
  @override
  Future<bool> ligar(String telefone) => _abrir(enderecoDoDiscador(telefone), LaunchMode.externalApplication);

  @override
  Future<bool> abrirNoMapa(String lugar) => _abrir(enderecoDoMapa(lugar), LaunchMode.externalApplication);

  /// Numa Custom Tab, e não no navegador à parte: a página fica por cima do
  /// aplicativo, e fechá-la devolve a pessoa a ele. Sem navegador que a abra,
  /// o próprio plugin cai numa página dentro do aplicativo.
  @override
  Future<bool> abrirPagamento(Uri endereco) => _abrir(endereco, LaunchMode.inAppBrowserView);

  /// Sem `canLaunchUrl`: no Android, abrir direto já devolve false quando não
  /// há aplicativo que atenda, e assim o manifesto não precisa declarar quais
  /// aplicativos o aplicativo procura.
  Future<bool> _abrir(Uri endereco, LaunchMode modo) async {
    try {
      return await launchUrl(endereco, mode: modo);
    } on Exception {
      // PlatformException do Android, ou MissingPluginException sem o plugin
      // registrado: para a tela, é igual — não abriu.
      return false;
    }
  }
}
