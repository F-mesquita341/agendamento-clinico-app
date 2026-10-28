import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'servico_de_notificacoes.dart';

/// O Firebase Cloud Messaging atrás da interface do aplicativo.
///
/// Único arquivo que importa `firebase_messaging`. É fino de propósito: cada
/// método repassa a chamada e troca a exceção do plugin por
/// [FalhaDasNotificacoes] — e a leitura da mensagem, que é o que pode estar
/// errado, é a função pura `lembreteDe`, testada à parte. O resto é conferido
/// no aparelho, no portão da etapa.
class NotificacoesFirebase implements ServicoDeNotificacoes {
  NotificacoesFirebase([FirebaseMessaging? mensagens]) : _mensagens = mensagens ?? FirebaseMessaging.instance;

  final FirebaseMessaging _mensagens;

  @override
  Future<bool> permitidas() =>
      _traduzindo(() async => _permitido((await _mensagens.getNotificationSettings()).authorizationStatus));

  @override
  Future<bool> pedirPermissao() =>
      _traduzindo(() async => _permitido((await _mensagens.requestPermission()).authorizationStatus));

  @override
  Future<String> token() => _traduzindo(() async {
        final token = await _mensagens.getToken();
        if (token == null || token.isEmpty) throw const FalhaDasNotificacoes('o FCM não deu um token');
        return token;
      });

  @override
  Future<void> apagarToken() => _traduzindo(_mensagens.deleteToken);

  @override
  Future<LembreteRecebido?> lembreteQueAbriuOApp() => _traduzindo(() async {
        final mensagem = await _mensagens.getInitialMessage();
        return mensagem == null ? null : _lembrete(mensagem);
      });

  @override
  Stream<LembreteRecebido> get lembretesTocados => FirebaseMessaging.onMessageOpenedApp.expand(_soLembrete);

  @override
  Stream<LembreteRecebido> get lembretesComOAppAberto => FirebaseMessaging.onMessage.expand(_soLembrete);

  static bool _permitido(AuthorizationStatus status) =>
      status == AuthorizationStatus.authorized || status == AuthorizationStatus.provisional;

  static LembreteRecebido? _lembrete(RemoteMessage mensagem) =>
      lembreteDe(mensagem.data, messageId: mensagem.messageId, texto: mensagem.notification?.body);

  static Iterable<LembreteRecebido> _soLembrete(RemoteMessage mensagem) => [?_lembrete(mensagem)];

  /// A exceção do plugin vira [FalhaDasNotificacoes], só com o código — nunca
  /// com a mensagem dele, que poderia trazer o token.
  static Future<T> _traduzindo<T>(Future<T> Function() chamada) async {
    try {
      return await chamada();
    } on FalhaDasNotificacoes {
      rethrow;
    } on FirebaseException catch (erro) {
      throw FalhaDasNotificacoes(erro.code);
    } on Exception catch (erro) {
      throw FalhaDasNotificacoes('${erro.runtimeType}');
    }
  }
}
