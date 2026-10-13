import 'package:flutter/foundation.dart';

import '../../data/services/servico_de_autenticacao.dart';
import '../../data/services/traducoes_da_autenticacao.dart';
import '../../domain/models/erro_da_api.dart';
import '../comum/defeitos.dart';

/// O envio de um formulário de conta — entrar, criar conta, pedir nova senha.
///
/// Guarda o que as três telas têm em comum: a trava contra o segundo toque
/// (checklist, itens 1.2 e 5.3) e o erro do provedor no lugar certo — embaixo
/// do campo que precisa de correção, ou num aviso geral (item 9.4).
class EnvioDeConta extends ChangeNotifier {
  bool _enviando = false;
  String? _erroDoEmail;
  String? _erroDaSenha;
  String? _erroGeral;
  String? _codigoDoErro;
  bool _descartado = false;

  bool get enviando => _enviando;
  String? get erroDoEmail => _erroDoEmail;
  String? get erroDaSenha => _erroDaSenha;
  String? get erroGeral => _erroGeral;

  /// O código do último erro do provedor, para a tela oferecer a saída certa
  /// — `email-already-in-use` oferece entrar ou recuperar a senha.
  String? get codigoDoErro => _codigoDoErro;

  /// Executa a ação, se não houver outra em andamento. Devolve true se deu
  /// certo; o erro, se houve, fica nos campos.
  Future<bool> enviar(Future<void> Function() acao) async {
    if (_enviando) return false;
    _enviando = true;
    _limpar();
    _notificar();
    try {
      await acao();
      return true;
    } on ErroDeAutenticacao catch (erro) {
      _codigoDoErro = erro.codigo;
      switch (erro.campo) {
        case CampoDoErro.email:
          _erroDoEmail = erro.mensagem;
        case CampoDoErro.senha:
          _erroDaSenha = erro.mensagem;
        case CampoDoErro.geral:
          _erroGeral = erro.mensagem;
      }
      return false;
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao enviar um formulário de conta');
      _erroGeral = const ErroDaApi.falhaNoAplicativo().mensagem;
      return false;
    } finally {
      _enviando = false;
      _notificar();
    }
  }

  /// A pessoa mexeu no campo: o erro do provedor sobre ele deixa de valer.
  void campoMudou(CampoDoErro campo) {
    final antes = (_erroDoEmail, _erroDaSenha);
    if (campo == CampoDoErro.email) _erroDoEmail = null;
    if (campo == CampoDoErro.senha) _erroDaSenha = null;
    if (antes != (_erroDoEmail, _erroDaSenha)) _notificar();
  }

  void _limpar() {
    _erroDoEmail = null;
    _erroDaSenha = null;
    _erroGeral = null;
    _codigoDoErro = null;
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
