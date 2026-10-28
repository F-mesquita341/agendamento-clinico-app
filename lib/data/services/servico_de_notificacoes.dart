/// Um lembrete de consulta que chegou ao aparelho: tocado na bandeja, ou
/// recebido com o aplicativo aberto.
class LembreteRecebido {
  const LembreteRecebido({required this.consultaId, this.messageId, this.texto});

  /// A consulta lembrada — é ela que o toque abre (checklist, item 7.2).
  final int consultaId;

  /// O identificador da mensagem no FCM. O mesmo toque, entregue duas vezes,
  /// não abre a consulta duas vezes.
  final String? messageId;

  /// O corpo da notificação, como a API o escreveu: "Você tem uma consulta
  /// amanhã às 14:30." Sem profissional nem especialidade (item 6.5).
  final String? texto;
}

/// Lê os dados de uma mensagem do FCM. Só vale o lembrete de consulta, como a
/// API o envia — `{consultaId: '90', tipo: 'lembrete'}` —; qualquer outra
/// mensagem é ignorada e não abre tela nenhuma.
LembreteRecebido? lembreteDe(Map<String, Object?> dados, {String? messageId, String? texto}) {
  if (dados['tipo'] != 'lembrete') return null;
  final id = dados['consultaId'];
  if (id is! String || !RegExp(r'^[0-9]+$').hasMatch(id)) return null;
  final consultaId = int.tryParse(id);
  if (consultaId == null || consultaId <= 0) return null;
  return LembreteRecebido(consultaId: consultaId, messageId: messageId, texto: texto);
}

/// Falha do serviço de notificações do aparelho — sem o Google Play, sem
/// rede para falar com o FCM. Não é defeito do aplicativo: o lembrete fica
/// desligado, e o aplicativo tenta de novo na próxima abertura.
class FalhaDasNotificacoes implements Exception {
  const FalhaDasNotificacoes(this.motivo);

  final String motivo;

  @override
  String toString() => 'FalhaDasNotificacoes($motivo)';
}

/// As notificações do aparelho: a permissão, o endereço do aparelho no FCM e
/// os lembretes que chegam.
///
/// Interface, como a da autenticação: as telas e o view model são testados
/// com uma implementação em memória, e o adaptador real
/// (`NotificacoesFirebase`) é fino o bastante para ser conferido no aparelho.
///
/// O token é dado pessoal (LGPD): nada aqui o imprime nem o registra em log.
abstract interface class ServicoDeNotificacoes {
  /// Se o sistema deixa o aplicativo mostrar notificações. No Android 13 ou
  /// superior, é a permissão que a pessoa deu; antes dele, vem dada desde a
  /// instalação, a menos que tenha sido desligada nas configurações. Lança
  /// [FalhaDasNotificacoes].
  Future<bool> permitidas();

  /// Mostra a pergunta do sistema e devolve se ficou permitido. Depois de
  /// duas recusas, o Android não pergunta mais e devolve false na hora.
  /// Lança [FalhaDasNotificacoes].
  Future<bool> pedirPermissao();

  /// O endereço deste aparelho no FCM, para onde a API manda o lembrete.
  /// Lança [FalhaDasNotificacoes].
  Future<String> token();

  /// Invalida o token deste aparelho no FCM: o que for enviado para ele não
  /// chega mais, e a API o apaga na próxima tentativa de envio. Lança
  /// [FalhaDasNotificacoes].
  Future<void> apagarToken();

  /// O lembrete cujo toque abriu o aplicativo, que estava fechado. Chamado uma
  /// vez por processo: o FCM guarda também o último toque com o aplicativo em
  /// segundo plano, e o devolveria de novo.
  Future<LembreteRecebido?> lembreteQueAbriuOApp();

  /// Os toques num lembrete com o aplicativo em segundo plano.
  Stream<LembreteRecebido> get lembretesTocados;

  /// Os lembretes que chegam com o aplicativo aberto — o Android não os mostra
  /// na bandeja.
  Stream<LembreteRecebido> get lembretesComOAppAberto;
}
