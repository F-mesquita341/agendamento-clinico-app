import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/especialidade.dart';
import '../../domain/models/pagina.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';
import '../comum/estados_de_carga.dart';
import 'sugestoes.dart';

/// A busca de profissionais: os dois filtros — a especialidade e o texto —, a
/// lista paginada que eles dão, e o estado de cada pedido.
class BuscaViewModel extends ChangeNotifier {
  BuscaViewModel(
    this._catalogo, {
    this.esperaAteAvisar = const Duration(seconds: 4),
    this.esperaAoDigitar = const Duration(milliseconds: 300),
  });

  final RepositorioDoCatalogo _catalogo;

  /// Depois deste tempo carregando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  /// Quanto esperar, depois da última tecla, antes de buscar. Sem a espera,
  /// digitar "ana" faria três pedidos, um por letra.
  final Duration esperaAoDigitar;

  EstadoDaCarga _estado = EstadoDaCarga.carregando;
  List<Especialidade>? _especialidades;
  int? _especialidadeId;
  String _texto = '';
  String? _termo;
  List<Profissional> _profissionais = const [];
  int _total = 0;
  int _pagina = 1;
  bool _temMais = false;
  bool _mostrandoMais = false;
  bool _atualizando = false;
  ErroDaApi? _erro;
  ErroDaApi? _erroAoAtualizar;
  ErroDaApi? _erroAoMostrarMais;
  Timer? _esperaDoTexto;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  /// Cada busca nova leva um número. A resposta que chega com o número de uma
  /// busca antiga é descartada: sem isso, o resultado de "an" podia chegar
  /// depois e cobrir o de "ana".
  int _busca = 0;

  /// O estado da lista: muda a cada busca nova, e não só na primeira.
  EstadoDaCarga get estado => _estado;

  /// As especialidades para escolher. Vazia até a primeira resposta.
  List<Especialidade> get especialidades => _especialidades ?? const [];

  /// A especialidade escolhida; null é "Todas".
  int? get especialidadeId => _especialidadeId;
  Especialidade? get especialidade => especialidades.where((e) => e.id == _especialidadeId).firstOrNull;

  /// O texto que foi de fato buscado no nome — o digitado, sem os espaços em
  /// volta —, ou null quando ele tem menos de duas letras.
  String? get termo => _termo;

  /// Há uma letra só no campo: a API pede duas, e a tela diz isso.
  /// O texto do campo, como a pessoa digitou — ou vazio, quando outra tela
  /// escolheu a especialidade.
  String get texto => _texto;

  bool get textoCurto => _texto.trim().length == 1;

  bool get temFiltro => _especialidadeId != null || _texto.trim().isNotEmpty;

  /// Especialidades que o texto buscado parece procurar, fora a já escolhida.
  List<Especialidade> get sugestoes => [
        for (final sugerida in especialidadesSugeridas(_termo ?? '', especialidades))
          if (sugerida.id != _especialidadeId) sugerida,
      ];

  List<Profissional> get profissionais => _profissionais;

  /// Quantos profissionais a busca achou ao todo, somando as páginas.
  int get total => _total;
  bool get temMais => _temMais;
  bool get mostrandoMais => _mostrandoMais;

  /// A lista está sendo pedida de novo, com ela na tela.
  bool get atualizando => _atualizando;

  /// Por que a busca falhou.
  ErroDaApi? get erro => _erro;

  /// Por que a última atualização falhou — a lista anterior continua na tela.
  ErroDaApi? get erroAoAtualizar => _erroAoAtualizar;

  /// Por que a página seguinte não veio — as anteriores continuam na tela.
  ErroDaApi? get erroAoMostrarMais => _erroAoMostrarMais;

  bool get demorando => _aviso.demorando;

  /// Busca com os filtros de agora, trocando a lista. É a primeira carga e o
  /// "Tentar de novo".
  Future<void> carregar() => _buscar();

  /// O texto do campo mudou. A busca espera a pessoa parar de digitar.
  void aoDigitar(String texto) {
    _texto = texto;
    _esperaDoTexto?.cancel();
    // Com uma letra só, ou só espaços a mais, a busca continua a mesma.
    if (_termoDe(texto) != _termo) _esperaDoTexto = Timer(esperaAoDigitar, _buscar);
    _notificar();
  }

  void escolherEspecialidade(int? id) {
    if (id == _especialidadeId) return;
    _especialidadeId = id;
    _buscar();
  }

  /// Volta a todos os profissionais. Quem mostra o campo de busca o esvazia.
  void limparFiltros() => _ficarSoCom(null);

  /// Troca o texto digitado pela especialidade que ele procurava. Quem mostra
  /// o campo de busca o esvazia.
  void aceitarSugestao(Especialidade sugerida) => _ficarSoCom(sugerida.id);

  /// Os profissionais de uma especialidade, escolhida fora da busca — no
  /// Início. O texto digitado sai, para a lista ser a da especialidade toda.
  void mostrarEspecialidade(int especialidadeId) => _ficarSoCom(especialidadeId);

  void _ficarSoCom(int? especialidadeId) {
    _texto = '';
    _especialidadeId = especialidadeId;
    _buscar();
  }

  /// Puxar para atualizar: a primeira página de novo, com a lista na tela. Se
  /// falhar, a lista fica e [erroAoAtualizar] diz por quê.
  ///
  /// A página 1 nova invalida um "mostrar mais" que ainda esteja no ar: a
  /// página seguinte da lista antiga, chegando depois, seria acrescentada à
  /// lista nova (revisão de 19/10). Enquanto atualiza, "mostrar mais" espera.
  Future<void> atualizar() async {
    if (_estado != EstadoDaCarga.pronto) return _buscar();
    final busca = ++_busca;
    _atualizando = true;
    _mostrandoMais = false;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _aviso.esquecerPedidos();
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(1));
    if (busca != _busca) return;
    _atualizando = false;
    if (pagina != null) {
      _mostrar(pagina);
    } else {
      _erroAoAtualizar = erro;
    }
    _notificar();
  }

  /// A página seguinte, acrescentada à lista.
  ///
  /// A tela esconde o botão enquanto a página carrega, mas a trava fica aqui:
  /// um segundo pedido da mesma página duplicaria os profissionais na lista, e
  /// um pedido durante uma busca nova levaria a página de uma lista que já saiu.
  Future<void> mostrarMais() async {
    if (_mostrandoMais || _atualizando || !_temMais || _estado != EstadoDaCarga.pronto) return;
    final busca = _busca;
    _mostrandoMais = true;
    _erroAoMostrarMais = null;
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(_pagina + 1));
    if (busca != _busca) return;
    _mostrandoMais = false;
    if (pagina != null) {
      _mostrar(pagina, depois: _profissionais);
    } else {
      _erroAoMostrarMais = erro;
    }
    _notificar();
  }

  Future<void> _buscar() async {
    final busca = ++_busca;
    _esperaDoTexto?.cancel();
    _termo = _termoDe(_texto);
    _estado = EstadoDaCarga.carregando;
    _erro = null;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _mostrandoMais = false;
    _atualizando = false;
    // As respostas das buscas anteriores vão ser descartadas: não contam mais
    // para o aviso de demora.
    _aviso.esquecerPedidos();
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(1));
    if (busca != _busca) return;
    if (pagina != null) {
      _mostrar(pagina);
      _estado = EstadoDaCarga.pronto;
    } else {
      _erro = erro;
      _estado = EstadoDaCarga.falhou;
    }
    _notificar();
  }

  /// Pede uma página com os filtros de agora — e, antes, as especialidades, se
  /// ainda não vieram. Devolve a página, ou o erro que a tela mostra: nunca
  /// lança, para nenhum pedido deixar a tela presa carregando.
  Future<({Pagina<Profissional>? pagina, ErroDaApi? erro})> _pedir(int numero) async {
    final especialidadeId = _especialidadeId;
    final termo = _termo;
    try {
      _especialidades ??= await _catalogo.especialidades();
      final pagina = await _catalogo.profissionais(especialidadeId: especialidadeId, termo: termo, pagina: numero);
      return (pagina: pagina, erro: null);
    } on ErroDaApi catch (erro) {
      return (pagina: null, erro: erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao buscar profissionais');
      return (pagina: null, erro: const ErroDaApi.falhaNoAplicativo());
    }
  }

  void _mostrar(Pagina<Profissional> pagina, {List<Profissional> depois = const []}) {
    _profissionais = [...depois, ...pagina.itens];
    _pagina = pagina.pagina;
    _total = pagina.total;
    _temMais = pagina.temMais;
  }

  static String? _termoDe(String texto) {
    final limpo = texto.trim();
    return limpo.length >= 2 ? limpo : null;
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _esperaDoTexto?.cancel();
    _aviso.parar();
    super.dispose();
  }
}
