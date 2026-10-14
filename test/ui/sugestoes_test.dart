import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/ui/busca/sugestoes.dart';
import 'package:flutter_test/flutter_test.dart';

// As especialidades da API publicada.
const especialidades = [
  Especialidade(id: 2, nome: 'Cardiologia'),
  Especialidade(id: 1, nome: 'Clínica Geral'),
  Especialidade(id: 3, nome: 'Dermatologia'),
  Especialidade(id: 4, nome: 'Ginecologia'),
  Especialidade(id: 5, nome: 'Ortopedia'),
  Especialidade(id: 6, nome: 'Pediatria'),
];

List<String> sugeridas(String texto) => [for (final e in especialidadesSugeridas(texto, especialidades)) e.nome];

void main() {
  group('sem acento', () {
    test('minúsculas, sem acento e sem cedilha', () {
      expect(semAcento('Coração'), 'coracao');
      expect(semAcento('CLÍNICA GERAL'), 'clinica geral');
      expect(semAcento('saúde, avô, à, ü'), 'saude, avo, a, u');
    });

    test('também quando o acento vem como sinal à parte da letra', () {
      // "coração" com a cedilha e o til escritos depois do c e do a.
      expect(semAcento('coração'), 'coracao');
    });
  });

  group('especialidades sugeridas', () {
    test('pelo começo do nome, com ou sem acento, em maiúsculas ou não', () {
      expect(sugeridas('cardio'), ['Cardiologia']);
      expect(sugeridas('CLINICA'), ['Clínica Geral']);
      expect(sugeridas('clínica geral'), ['Clínica Geral']);
    });

    test('por uma palavra do meio do nome', () {
      expect(sugeridas('geral'), ['Clínica Geral']);
    });

    test('pelo jeito comum de chamar: "coracao" é Cardiologia', () {
      expect(sugeridas('coracao'), ['Cardiologia']);
      expect(sugeridas('coração'), ['Cardiologia']);
      expect(sugeridas('criança'), ['Pediatria']);
      expect(sugeridas('osso'), ['Ortopedia']);
      expect(sugeridas('mulher'), ['Ginecologia']);
      expect(sugeridas('saude da mulher'), ['Ginecologia']);
      expect(sugeridas('rotina'), ['Clínica Geral']);
    });

    test('mais de uma, na ordem da lista, quando o texto serve a mais de uma', () {
      // "pele" é Dermatologia; "pediatria" começa igual.
      expect(sugeridas('pe'), ['Dermatologia', 'Pediatria']);
    });

    test('pelo começo, e não por qualquer pedaço: "logia" não sugere nada', () {
      expect(sugeridas('logia'), isEmpty);
    });

    test('palavra de ligação não leva a especialidade nenhuma', () {
      // "de" está em "consulta de rotina", mas só Dermatologia começa assim.
      expect(sugeridas('de'), ['Dermatologia']);
      expect(sugeridas('da'), isEmpty);
    });

    test('menos de duas letras, ou só espaços: nada', () {
      expect(sugeridas('c'), isEmpty);
      expect(sugeridas(' c '), isEmpty);
      expect(sugeridas(''), isEmpty);
    });

    test('nome de gente não sugere especialidade', () {
      expect(sugeridas('carlos'), isEmpty);
    });

    test('especialidade que não tem jeito comum cadastrado é achada pelo nome', () {
      const outras = [Especialidade(id: 9, nome: 'Fisioterapia')];
      expect(especialidadesSugeridas('fisio', outras).single.nome, 'Fisioterapia');
    });
  });
}
