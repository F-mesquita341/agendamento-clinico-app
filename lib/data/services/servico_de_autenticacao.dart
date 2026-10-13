import 'traducoes_da_autenticacao.dart';

/// Quem está com a sessão aberta no aparelho — só o que o aplicativo usa.
class UsuarioDaSessao {
  const UsuarioDaSessao({required this.uid, required this.email});

  final String uid;
  final String? email;
}

/// Falha do provedor de identidade, já sem o texto dele: só o código, que
/// vira mensagem em português aqui, e nunca a mensagem original, em inglês
/// (checklist, item 9.3).
class ErroDeAutenticacao implements Exception {
  const ErroDeAutenticacao(this.codigo);

  final String codigo;

  String get mensagem => mensagemDeAutenticacao(codigo);

  /// Em que campo do formulário o erro aparece (checklist, item 9.4).
  CampoDoErro get campo => campoDoErro(codigo);

  @override
  String toString() => 'ErroDeAutenticacao($codigo)';
}

/// A conta do paciente no provedor de identidade.
///
/// Interface, para que nenhum teste dependa do Firebase: as telas e a sessão
/// são testadas com uma implementação em memória, e o adaptador real
/// (`AutenticacaoFirebase`) é fino o bastante para ser conferido no aparelho.
abstract interface class ServicoDeAutenticacao {
  /// O usuário atual assim que alguém passa a ouvir, e de novo a cada entrada
  /// e saída.
  Stream<UsuarioDaSessao?> get mudancas;

  /// Lança [ErroDeAutenticacao].
  Future<void> entrar({required String email, required String senha});

  /// Cria a conta e já entra nela. Lança [ErroDeAutenticacao].
  Future<void> criarConta({required String email, required String senha});

  /// Pede o e-mail de redefinição. Não revela se a conta existe: para quem
  /// pede, o resultado é o mesmo (checklist, item 3.10). Lança
  /// [ErroDeAutenticacao] só por falha de rede, e-mail inválido ou excesso de
  /// tentativas.
  Future<void> enviarRedefinicaoDeSenha(String email);

  Future<void> sair();

  /// O token da sessão, para a API — o `FonteDeToken` do `ApiClient`. Null
  /// sem sessão. Falha vira `ErroDaApi`, que é o que o `ApiClient` sabe
  /// tratar: nunca a exceção do provedor.
  Future<String?> token({bool renovar = false});
}
