import 'package:agendamento_clinico/data/services/servico_de_autenticacao.dart';
import 'package:agendamento_clinico/data/services/traducoes_da_autenticacao.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// As traduções das falhas do provedor de identidade: é nelas que mora o que
/// pode dar errado. O adaptador do Firebase só repassa chamadas, e é conferido
/// no aparelho.
void main() {
  group('mensagens do provedor de identidade', () {
    const conhecidos = {
      'email-already-in-use': 'Este e-mail já tem cadastro. Quer entrar ou recuperar a senha?',
      'invalid-email': 'Confira o e-mail digitado (ex.: nome@email.com).',
      'weak-password': 'Senha muito curta. Use pelo menos 6 caracteres.',
      'invalid-credential': 'E-mail ou senha incorretos.',
      'wrong-password': 'E-mail ou senha incorretos.',
      'user-not-found': 'E-mail ou senha incorretos.',
      'user-disabled': 'Esta conta foi desativada. Fale com a clínica.',
      'too-many-requests': 'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
      'network-request-failed': 'Sem conexão com a internet. Verifique e tente de novo.',
    };

    for (final MapEntry(key: codigo, value: mensagem) in conhecidos.entries) {
      test('$codigo vira mensagem em português', () {
        expect(ErroDeAutenticacao(codigo).mensagem, mensagem);
      });
    }

    test('ao entrar, os três erros de credencial dizem o mesmo — não revelam se o e-mail existe', () {
      final mensagens = {'invalid-credential', 'wrong-password', 'user-not-found'}.map(mensagemDeAutenticacao);
      expect(mensagens.toSet(), hasLength(1));
    });

    test('código desconhecido recebe mensagem genérica em português, e nunca o código', () {
      final mensagem = mensagemDeAutenticacao('internal-error');

      expect(mensagem, 'Não foi possível concluir. Tente de novo.');
      expect(mensagem, isNot(contains('internal')));
    });

    test('cada erro aparece no campo que precisa de correção', () {
      expect(campoDoErro('invalid-email'), CampoDoErro.email);
      expect(campoDoErro('email-already-in-use'), CampoDoErro.email);
      expect(campoDoErro('weak-password'), CampoDoErro.senha);
      expect(campoDoErro('password-does-not-meet-requirements'), CampoDoErro.senha);
      // Credencial errada não é culpa de um campo só: aviso geral.
      expect(campoDoErro('invalid-credential'), CampoDoErro.geral);
      expect(campoDoErro('network-request-failed'), CampoDoErro.geral);
    });
  });

  group('redefinição de senha', () {
    test('conta inexistente não é falha: a resposta é a mesma, exista ou não a conta', () {
      expect(redefinicaoFalhouDeVerdade('user-not-found'), isFalse);
    });

    test('falha de rede e e-mail inválido continuam sendo falhas', () {
      expect(redefinicaoFalhouDeVerdade('network-request-failed'), isTrue);
      expect(redefinicaoFalhouDeVerdade('invalid-email'), isTrue);
      expect(redefinicaoFalhouDeVerdade('too-many-requests'), isTrue);
    });
  });

  group('falha ao obter o token', () {
    test('sem rede vira a mesma falta de conexão de qualquer pedido', () {
      expect(erroDoToken('network-request-failed').codigo, 'SEM_CONEXAO');
    });

    test('conta desativada, apagada ou sessão revogada levam a entrar de novo', () {
      for (final codigo in ['user-disabled', 'user-not-found', 'user-token-expired', 'invalid-user-token']) {
        expect(erroDoToken(codigo).acao, AcaoSugerida.autenticar, reason: codigo);
      }
    });

    test('qualquer outra falha deixa tentar de novo, com mensagem em português', () {
      final erro = erroDoToken('internal-error');

      expect(erro.acao, AcaoSugerida.tentarNovamente);
      expect(erro.mensagem, isNot(contains('internal')));
    });
  });
}
