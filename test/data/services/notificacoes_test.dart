import 'package:agendamento_clinico/data/services/servico_de_notificacoes.dart';
import 'package:flutter_test/flutter_test.dart';

/// A leitura da mensagem do FCM: é nela que mora o que pode dar errado. O
/// adaptador do Firebase só repassa chamadas, e é conferido no aparelho.
void main() {
  group('lembreteDe', () {
    test('o lembrete como a API o envia: a consulta, a mensagem e o texto', () {
      final lembrete = lembreteDe(
        {'consultaId': '90', 'tipo': 'lembrete'},
        messageId: '0:1730',
        texto: 'Você tem uma consulta amanhã às 14:30.',
      )!;

      expect(lembrete.consultaId, 90);
      expect(lembrete.messageId, '0:1730');
      expect(lembrete.texto, 'Você tem uma consulta amanhã às 14:30.');
    });

    test('outro tipo de mensagem não é lembrete', () {
      expect(lembreteDe({'consultaId': '90', 'tipo': 'promocao'}), isNull);
      expect(lembreteDe({'consultaId': '90'}), isNull);
    });

    for (final id in <Object?>['abc', '0', '-3', ' 90', '9.5', '', null, 90]) {
      test('consultaId ${id is String ? '"$id"' : id} não abre consulta nenhuma', () {
        expect(lembreteDe({'consultaId': id, 'tipo': 'lembrete'}), isNull);
      });
    }
  });
}
