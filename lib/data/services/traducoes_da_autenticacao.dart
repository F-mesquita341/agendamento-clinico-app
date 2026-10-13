import '../../domain/models/erro_da_api.dart';

// As falhas do provedor de identidade traduzidas para o que o aplicativo
// mostra e decide. Funções puras, sem o Firebase: é aqui que mora o que pode
// estar errado, e por isso é aqui que estão os testes.

/// O erro em português para o paciente (checklist, itens 9.3 e 9.4).
///
/// A tradução é pelo código, nunca pela mensagem do provedor — que vem em
/// inglês, e às vezes com detalhes técnicos. Código desconhecido recebe uma
/// mensagem genérica, e não o texto original.
String mensagemDeAutenticacao(String codigo) => switch (codigo) {
      'email-already-in-use' => 'Este e-mail já tem cadastro. Quer entrar ou recuperar a senha?',
      'invalid-email' => 'Confira o e-mail digitado (ex.: nome@email.com).',
      'weak-password' => 'Senha muito curta. Use pelo menos 6 caracteres.',
      'password-does-not-meet-requirements' => 'A senha não atende às regras de segurança. Tente uma senha mais longa.',
      // Ao entrar, nunca dizer se o e-mail existe: a mesma mensagem para os três.
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'E-mail ou senha incorretos.',
      'user-disabled' => 'Esta conta foi desativada. Fale com a clínica.',
      'too-many-requests' => 'Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo.',
      'network-request-failed' => 'Sem conexão com a internet. Verifique e tente de novo.',
      _ => 'Não foi possível concluir. Tente de novo.',
    };

/// Onde o erro aparece no formulário: embaixo do campo que precisa de
/// correção, ou num aviso acima do botão quando não é culpa de um campo só.
enum CampoDoErro { email, senha, geral }

CampoDoErro campoDoErro(String codigo) => switch (codigo) {
      'email-already-in-use' || 'invalid-email' => CampoDoErro.email,
      'weak-password' || 'password-does-not-meet-requirements' => CampoDoErro.senha,
      _ => CampoDoErro.geral,
    };

/// Na redefinição de senha, conta inexistente não é falha: a resposta para
/// quem pede é a mesma exista ou não a conta, para não revelar quais e-mails
/// estão cadastrados (checklist, item 3.10). Com a proteção contra enumeração
/// de e-mails ligada no Firebase, ele nem chega a lançar esse erro; sem ela,
/// lança, e é aqui que ele some.
bool redefinicaoFalhouDeVerdade(String codigo) => codigo != 'user-not-found';

/// Falha ao obter o token traduzida no erro que o `ApiClient` e as telas sabem
/// tratar. A exceção do provedor nunca passa daqui.
ErroDaApi erroDoToken(String codigo) => switch (codigo) {
      'network-request-failed' => const ErroDaApi.semConexao(),
      // A conta não serve mais — desativada, apagada, ou a sessão foi revogada:
      // a saída é entrar de novo.
      'user-disabled' || 'user-not-found' || 'user-token-expired' || 'invalid-user-token' => sessaoEncerrada,
      _ => const ErroDaApi(
          status: 0,
          codigo: 'FALHA_NA_SESSAO',
          mensagem: 'Não foi possível confirmar sua sessão. Tente de novo.',
          acao: AcaoSugerida.tentarNovamente,
        ),
    };

/// A sessão terminou sem a pessoa pedir; o aplicativo leva de volta à tela de
/// entrar, como faz com o `autenticar` da API.
const sessaoEncerrada = ErroDaApi(
  status: 401,
  codigo: 'SESSAO_ENCERRADA',
  mensagem: 'Sua sessão terminou. Entre de novo para continuar.',
  acao: AcaoSugerida.autenticar,
);
