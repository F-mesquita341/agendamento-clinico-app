/// O que o aplicativo guarda no aparelho entre uma abertura e outra. Hoje,
/// só a cidade escolhida — o id, e nada que identifique a pessoa.
///
/// Interface, para as telas serem testadas sem o armazenamento do Android.
abstract interface class PreferenciasDoAparelho {
  /// A cidade escolhida da última vez, ou null para "Todas as cidades".
  Future<int?> cidadeEscolhida();

  /// Guarda a cidade escolhida; null apaga, e volta a valer "Todas as cidades".
  Future<void> guardarCidade(int? cidadeId);
}
