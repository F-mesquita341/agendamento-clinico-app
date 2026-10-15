import 'package:agendamento_clinico/data/services/abridor_de_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discador', () {
    test('o telefone como a clínica o escreve vira só os dígitos', () {
      expect(enderecoDoDiscador('(88) 3000-0000').toString(), 'tel:8830000000');
      expect(enderecoDoDiscador('88 9 9999-0000').toString(), 'tel:88999990000');
    });

    test('o "+" do código do país fica', () {
      expect(enderecoDoDiscador('+55 (88) 3000-0000').toString(), 'tel:+558830000000');
    });
  });

  group('mapa', () {
    test('o lugar vai como busca, com acentos e espaços codificados', () {
      final endereco = enderecoDoMapa('Clínica Exemplo Quixadá, Centro, Quixadá - CE');

      expect(endereco.scheme, 'geo');
      // Espaço como %20: o "+" que os formulários usam não é entendido por
      // todo aplicativo de mapas.
      expect(
        endereco.toString(),
        'geo:0,0?q=Cl%C3%ADnica%20Exemplo%20Quixad%C3%A1%2C%20Centro%2C%20Quixad%C3%A1%20-%20CE',
      );
    });

    test('o que quebraria o endereço — "&", "#", "?" — vai codificado', () {
      expect(enderecoDoMapa('Rua A & B #10?').toString(), 'geo:0,0?q=Rua%20A%20%26%20B%20%2310%3F');
    });
  });
}
