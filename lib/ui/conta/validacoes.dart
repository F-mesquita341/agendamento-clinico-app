/// Validações dos campos da conta, feitas enquanto o paciente digita
/// (checklist, item 5.4): o erro aparece embaixo do campo e diz como corrigir
/// (item 9.4), antes de qualquer pedido sair do aparelho.
library;

final _formatoDeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

String? validarEmail(String? valor) {
  final email = (valor ?? '').trim();
  if (email.isEmpty) return 'Informe o e-mail.';
  if (!_formatoDeEmail.hasMatch(email)) return 'Confira o e-mail digitado (ex.: nome@email.com).';
  return null;
}

/// Ao entrar, a senha só precisa estar preenchida: a regra de tamanho é de
/// quem cria a senha, e repeti-la aqui não ajuda quem esqueceu a dele.
String? validarSenha(String? valor) => (valor ?? '').isEmpty ? 'Informe a senha.' : null;

/// O mínimo do Firebase Authentication, que a tela mostra antes do erro.
const tamanhoMinimoDaSenha = 6;

String? validarSenhaNova(String? valor) {
  final senha = valor ?? '';
  if (senha.isEmpty) return 'Crie uma senha.';
  if (senha.length < tamanhoMinimoDaSenha) {
    return 'A senha precisa ter pelo menos $tamanhoMinimoDaSenha caracteres.';
  }
  return null;
}
