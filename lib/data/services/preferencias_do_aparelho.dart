/// O que o aplicativo guarda no aparelho entre uma abertura e outra: a cidade
/// escolhida — o id, e nada que identifique a pessoa — ou a escolha de "Perto
/// de mim". A posição da pessoa nunca é guardada.
///
/// Interface, para as telas serem testadas sem o armazenamento do Android.
abstract interface class PreferenciasDoAparelho {
  /// A cidade escolhida da última vez, ou null para "Todas as cidades".
  Future<int?> cidadeEscolhida();

  /// Guarda a cidade escolhida; null apaga, e volta a valer "Todas as cidades".
  Future<void> guardarCidade(int? cidadeId);

  /// A pessoa escolheu "Perto de mim" da última vez.
  Future<bool> pertoDeMim();

  /// Guarda a escolha de "Perto de mim" — só a escolha, e nunca a posição.
  Future<void> guardarPertoDeMim(bool escolhido);
}
