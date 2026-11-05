import '../../domain/models/coordenadas.dart';

/// Em que pé está a localização do aparelho, para "Perto de mim".
enum PermissaoDaLocalizacao {
  /// A pessoa permitiu, e a localização do celular está ligada.
  concedida,

  /// Ainda não se pediu: o aplicativo explica antes de o Android perguntar.
  naoPedida,

  /// A pessoa recusou, e dá para pedir de novo.
  negada,

  /// A pessoa recusou de vez: só nas configurações do celular.
  negadaDeVez,

  /// A localização do celular está desligada.
  servicoDesligado,
}

/// A localização do aparelho ("Perto de mim", versão 2): só a aproximada, e
/// só para ordenar os profissionais pela distância. A posição não sai do
/// aparelho nem é guardada.
///
/// Interface, para as telas serem testadas sem o Android; o adaptador fica em
/// `localizacao_geolocator.dart`, o único arquivo que importa o pacote.
abstract interface class ServicoDeLocalizacao {
  /// Em que pé está, sem perguntar nada à pessoa.
  Future<PermissaoDaLocalizacao> permissao();

  /// Pergunta à pessoa, pelo diálogo do Android, e diz como ficou.
  Future<PermissaoDaLocalizacao> pedirPermissao();

  /// Onde o aparelho está, aproximadamente; null se não deu para saber a tempo.
  Future<Coordenadas?> posicaoAproximada();

  /// Abre a tela do aplicativo nas configurações do celular.
  Future<bool> abrirConfiguracoes();

  /// Abre as configurações da localização do celular, para ligá-la.
  Future<bool> abrirConfiguracoesDaLocalizacao();
}
