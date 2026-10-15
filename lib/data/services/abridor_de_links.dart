/// O que o aplicativo abre fora dele: o discador do telefone e o aplicativo de
/// mapas, para falar com a clínica e chegar até ela (checklist, itens 2.9 e
/// 10.3). Interface, para as telas serem testadas sem sair do aplicativo.
abstract interface class AbridorDeLinks {
  /// Abre o discador com o número já digitado: quem decide ligar é a pessoa.
  /// Devolve false se o aparelho não tem com o que abrir.
  Future<bool> ligar(String telefone);

  /// Abre o aplicativo de mapas procurando o lugar. Devolve false se o
  /// aparelho não tem com o que abrir.
  Future<bool> abrirNoMapa(String lugar);
}

/// O endereço que abre o discador: só os dígitos do telefone, e o "+" do
/// código do país, se houver.
Uri enderecoDoDiscador(String telefone) => Uri(scheme: 'tel', path: telefone.replaceAll(RegExp('[^0-9+]'), ''));

/// O endereço que abre o aplicativo de mapas numa busca pelo lugar. As
/// coordenadas 0,0 dizem "sem ponto de partida": vale o texto procurado.
Uri enderecoDoMapa(String lugar) => Uri.parse('geo:0,0?q=${Uri.encodeComponent(lugar)}');
