import '../../domain/models/especialidade.dart';

/// Como as pessoas chamam cada especialidade (checklist, item 2.7): quem
/// procura "coração" quer Cardiologia, mesmo sem saber o nome. A chave é o
/// nome da especialidade, como [semAcento] o devolve. Especialidade que não
/// está aqui é achada só pelo próprio nome.
const _apoio = {
  'cardiologia': 'coração',
  'clinica geral': 'consulta de rotina',
  'dermatologia': 'pele',
  'ginecologia': 'saúde da mulher',
  'ortopedia': 'ossos e articulações',
  'pediatria': 'crianças',
};

const _comAcento = 'áàâãäéèêëíìîïóòôõöúùûüç';
const _semAcento = 'aaaaaeeeeiiiiooooouuuuc';

/// Acento escrito como sinal à parte da letra, como alguns teclados mandam.
final _sinais = RegExp('[̀-ͯ]');

/// O texto em minúsculas e sem acento, para comparar o que a pessoa digitou
/// com um nome: ninguém digita "coração" com cedilha e til numa busca.
String semAcento(String texto) => texto.toLowerCase().replaceAll(_sinais, '').split('').map((letra) {
      final posicao = _comAcento.indexOf(letra);
      return posicao < 0 ? letra : _semAcento[posicao];
    }).join();

/// As especialidades que o texto digitado parece procurar: aquelas em que ele
/// começa o nome, a forma comum de chamá-la, ou uma palavra de um dos dois.
///
/// A busca da API olha só o nome dos profissionais. É por aqui que quem
/// digita "cardio" ou "coração" chega aos cardiologistas.
List<Especialidade> especialidadesSugeridas(String texto, List<Especialidade> especialidades) {
  final procurado = semAcento(texto.trim());
  if (procurado.length < 2) return const [];
  return [
    for (final especialidade in especialidades)
      if (_formasDeChamar(especialidade).any((forma) => forma.startsWith(procurado))) especialidade,
  ];
}

Iterable<String> _formasDeChamar(Especialidade especialidade) {
  final nome = semAcento(especialidade.nome);
  final apoio = semAcento(_apoio[nome] ?? '');
  // As palavras de ligação ("de", "da", "e") não levam a especialidade nenhuma.
  return [nome, apoio, ...nome.split(' '), ...apoio.split(' ')].where((forma) => forma.length > 2);
}

/// Como as pessoas chamam a especialidade — "coração", para Cardiologia —,
/// para aparecer junto do nome (checklist, item 2.7). Null se não há.
String? apoioDaEspecialidade(Especialidade especialidade) => _apoio[semAcento(especialidade.nome)];
