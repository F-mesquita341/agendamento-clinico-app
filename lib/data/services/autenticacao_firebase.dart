import 'package:firebase_auth/firebase_auth.dart';

import 'servico_de_autenticacao.dart';
import 'traducoes_da_autenticacao.dart';

/// O Firebase Authentication atrás da interface do aplicativo.
///
/// Único arquivo que importa `firebase_auth`. É fino de propósito: cada
/// método repassa a chamada e traduz a exceção — e as traduções, que são o
/// que pode estar errado, são funções puras testadas à parte. O resto é
/// conferido no aparelho, no portão da etapa.
class AutenticacaoFirebase implements ServicoDeAutenticacao {
  AutenticacaoFirebase([FirebaseAuth? auth]) : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<UsuarioDaSessao?> get mudancas => _auth.authStateChanges().map(_doFirebase);

  @override
  Future<void> entrar({required String email, required String senha}) =>
      _traduzindo(() => _auth.signInWithEmailAndPassword(email: email, password: senha));

  @override
  Future<void> criarConta({required String email, required String senha}) =>
      _traduzindo(() => _auth.createUserWithEmailAndPassword(email: email, password: senha));

  @override
  Future<void> enviarRedefinicaoDeSenha(String email) async {
    try {
      // O e-mail de redefinição sai no idioma pedido aqui, sem depender do
      // idioma configurado no console do Firebase. Dentro do try: falha aqui
      // também é do provedor, e também vira mensagem em português.
      await _auth.setLanguageCode('pt-BR');
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (erro) {
      if (!redefinicaoFalhouDeVerdade(erro.code)) return;
      throw ErroDeAutenticacao(erro.code);
    }
  }

  @override
  Future<void> sair() => _auth.signOut();

  @override
  Future<String?> token({bool renovar = false}) async {
    final usuario = _auth.currentUser;
    if (usuario == null) return null;
    try {
      return await usuario.getIdToken(renovar);
    } on FirebaseException catch (erro) {
      throw erroDoToken(erro.code);
    }
  }

  static UsuarioDaSessao? _doFirebase(User? usuario) =>
      usuario == null ? null : UsuarioDaSessao(uid: usuario.uid, email: usuario.email);

  static Future<void> _traduzindo(Future<Object?> Function() chamada) async {
    try {
      await chamada();
    } on FirebaseAuthException catch (erro) {
      throw ErroDeAutenticacao(erro.code);
    }
  }
}
