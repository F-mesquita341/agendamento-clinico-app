import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/coordenadas.dart';
import 'package:agendamento_clinico/ui/comum/distancia.dart';
import 'package:flutter_test/flutter_test.dart';

/// As clínicas do catálogo de demonstração da homologação.
const quixada = Coordenadas(-4.9708, -39.0153);
const quixeramobim = Coordenadas(-5.2011, -39.295);
const fortaleza = Coordenadas(-3.734, -38.529);

void main() {
  group('a distância', () {
    test('entre as clínicas de demonstração, em linha reta', () {
      // Os valores de referência foram calculados fora do aplicativo.
      expect(distanciaEmKm(quixada, fortaleza), closeTo(147.7, 0.5));
      expect(distanciaEmKm(quixada, quixeramobim), closeTo(40.2, 0.5));
    });

    test('é a mesma nos dois sentidos, e zero no mesmo ponto', () {
      expect(distanciaEmKm(fortaleza, quixada), closeTo(distanciaEmKm(quixada, fortaleza), 1e-9));
      expect(distanciaEmKm(quixada, quixada), 0);
    });

    test('latitude e longitude não se trocam: um grau de latitude não vale um de longitude', () {
      // Um grau para o norte e um para o leste, a partir de Quixadá.
      final norte = distanciaEmKm(quixada, const Coordenadas(-3.9708, -39.0153));
      final leste = distanciaEmKm(quixada, const Coordenadas(-4.9708, -38.0153));
      expect(norte, closeTo(111.2, 0.5));
      // Longe do equador, um grau de longitude é menor.
      expect(leste, closeTo(110.8, 0.5));
      expect(leste, lessThan(norte));
    });
  });

  group('as coordenadas da clínica', () {
    test('com as duas, o ponto; faltando uma, nenhum', () {
      expect(const Clinica(nome: 'A', latitude: -4.9708, longitude: -39.0153).coordenadas, quixada);
      expect(const Clinica(nome: 'A', latitude: -4.9708).coordenadas, isNull);
      expect(const Clinica(nome: 'A', longitude: -39.0153).coordenadas, isNull);
      expect(const Clinica(nome: 'A').coordenadas, isNull);
    });

    test('lidas da API, inteiras ou não', () {
      final clinica = Clinica.fromJson({'nome': 'A', 'latitude': -4, 'longitude': -39.5});
      expect(clinica.coordenadas, const Coordenadas(-4, -39.5));
    });
  });

  group('o texto da distância', () {
    test('menos de 1 km não promete metros', () {
      expect(textoDaDistancia(0), (texto: 'a menos de 1 km', leitura: 'a menos de 1 quilômetro'));
      expect(textoDaDistancia(0.95).texto, 'a menos de 1 km');
    });

    test('até 10 km, com uma casa e vírgula', () {
      expect(textoDaDistancia(2.34), (texto: 'a 2,3 km', leitura: 'a 2,3 quilômetros'));
      expect(textoDaDistancia(1).texto, 'a 1,0 km');
      expect(textoDaDistancia(9.94).texto, 'a 9,9 km');
    });

    test('de 10 km em diante, inteiros', () {
      expect(textoDaDistancia(10).texto, 'a 10 km');
      expect(textoDaDistancia(147.72), (texto: 'a 148 km', leitura: 'a 148 quilômetros'));
    });
  });
}
