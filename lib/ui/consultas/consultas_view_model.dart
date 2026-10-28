import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/pagina.dart';
import '../comum/defeitos.dart';
import '../comum/estados_de_carga.dart';
import 'situacao_da_consulta.dart';

/// As consultas do paciente, para o Início e para Minhas consultas.
///
/// A API devolve todas, de todos os status, da que acontece mais adiante para
/// a mais antiga, sem filtro. As próximas ficam então no começo da lista — e a
/// mais cedo delas, a "próxima consulta" do Início, é a última do futuro. Por
/// isso a carga pede página após página até chegar a uma consulta do passado:
/// assim a lista das próximas está completa. As anteriores continuam por
/// "mostrar mais".
class ConsultasViewModel extends ChangeNotifier {
  ConsultasViewModel(
    this._consultas, {
    this.relogio = DateTime.now,
    this.esperaAteAvisar = const Duration(seconds: 4),
  });

  /// Até quantas páginas a carga pede atrás do passado: 100 consultas futuras,
  /// muito além do que um paciente tem. Passado esse limite, as que faltarem
  /// aparecem por "mostrar mais".
  static const paginasNaCarga = 5;

  final RepositorioDeConsultas _consultas;

  /// O relógio do aparelho — o mesmo da grade e da reserva.
  final DateTime Function() relogio;

  /// Depois deste tempo carregando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  EstadoDaCarga _estado = EstadoDaCarga.carregando;
  List<ConsultaNaLista> _itens = const [];
  int _total = 0;
  int _pagina = 0;
  bool _temMais = false;
  bool _mostrandoMais = false;
  bool _atualizando = false;
  ErroDaApi? _erro;
  ErroDaApi? _erroAoAtualizar;
  ErroDaApi? _erroAoMostrarMais;

  /// Cada carga leva um número, e só a resposta da última vale: atualizar com
  /// um "mostrar mais" no ar não pode deixar a página antiga entrar na lista
  /// nova (o defeito que a revisão de 19/10 achou na busca).
  int _geracao = 0;
  Timer? _relogio;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  EstadoDaCarga get estado => _estado;
  ErroDaApi? get erro => _erro;
  ErroDaApi? get erroAoAtualizar => _erroAoAtualizar;
  ErroDaApi? get erroAoMostrarMais => _erroAoMostrarMais;
  bool get demorando => _aviso.demorando;
  bool get mostrandoMais => _mostrandoMais;
  bool get atualizando => _atualizando;
  bool get temMais => _temMais;

  /// Hoje, na clínica.
  DataCivil get hoje => DataCivil.naClinica(relogio());

  /// As que ainda vão acontecer — aguardando pagamento ou confirmadas, antes
  /// do horário —, da mais cedo para a mais tarde.
  List<ConsultaNaLista> get proximas {
    final agora = relogio();
    return _itens.where((item) => item.ehProxima(agora)).toList().reversed.toList();
  }

  /// Todas as outras, na ordem da API: canceladas (mesmo as do futuro),
  /// reservas vencidas e as que já começaram.
  List<ConsultaNaLista> get anteriores {
    final agora = relogio();
    return _itens.where((item) => !item.ehProxima(agora)).toList();
  }

  /// Quantas anteriores há, contando as que ainda não vieram: o total da API
  /// menos as próximas, que já vieram todas.
  int get totalDeAnteriores => math.max(anteriores.length, _total - proximas.length);

  /// A reserva que aguarda pagamento, com o prazo valendo — a mais cedo, se
  /// houver mais de uma.
  ConsultaNaLista? get reservaAguardando {
    final agora = relogio();
    return proximas.where((item) => item.aguardandoPagamento(agora)).firstOrNull;
  }

  /// A próxima consulta confirmada.
  ConsultaNaLista? get proximaConfirmada =>
      proximas.where((item) => item.consulta.status == StatusDaConsulta.confirmada).firstOrNull;

  /// Carga do zero: a primeira, e o "Tentar de novo".
  Future<void> carregar() async {
    final geracao = ++_geracao;
    _estado = EstadoDaCarga.carregando;
    _erro = null;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _mostrandoMais = false;
    _atualizando = false;
    _aviso.esquecerPedidos();
    _notificar();

    final (:itens, :ultima, :erro) = await _aviso.acompanhar(() => _carregarAtePassado(geracao));
    if (geracao != _geracao) return;
    if (itens != null && ultima != null) {
      _aplicar(itens, ultima);
    } else {
      _erro = erro;
      _estado = EstadoDaCarga.falhou;
    }
    _notificar();
  }

  /// Puxar para atualizar, e a volta ao shell depois de uma tela por cima: a
  /// lista inteira de novo, com ela na tela. Se falhar, a lista fica, e
  /// [erroAoAtualizar] diz por quê. Invalida um "mostrar mais" no ar.
  Future<void> atualizar() async {
    if (_estado != EstadoDaCarga.pronto) return carregar();
    final geracao = ++_geracao;
    _atualizando = true;
    _mostrandoMais = false;
    _erroAoAtualizar = null;
    _erroAoMostrarMais = null;
    _aviso.esquecerPedidos();
    _notificar();

    final (:itens, :ultima, :erro) = await _aviso.acompanhar(() => _carregarAtePassado(geracao));
    if (geracao != _geracao) return;
    _atualizando = false;
    if (itens != null && ultima != null) {
      _aplicar(itens, ultima);
    } else {
      _erroAoAtualizar = erro;
    }
    _notificar();
  }

  /// A página seguinte, acrescentada às anteriores.
  Future<void> mostrarMais() async {
    if (_mostrandoMais || _atualizando || !_temMais || _estado != EstadoDaCarga.pronto) return;
    final geracao = _geracao;
    _mostrandoMais = true;
    _erroAoMostrarMais = null;
    _notificar();

    final (:pagina, :erro) = await _aviso.acompanhar(() => _pedir(_pagina + 1));
    if (geracao != _geracao) return;
    _mostrandoMais = false;
    if (pagina != null) {
      _aplicar(_semRepetir([..._itens, ...pagina.itens]), pagina);
    } else {
      _erroAoMostrarMais = erro;
    }
    _notificar();
  }

  /// Página após página, até uma consulta do passado, até não haver mais, ou
  /// até [paginasNaCarga]. Null nos itens quando uma carga mais nova passou na
  /// frente, ou quando deu erro.
  Future<({List<ConsultaNaLista>? itens, Pagina<ConsultaNaLista>? ultima, ErroDaApi? erro})> _carregarAtePassado(
    int geracao,
  ) async {
    final itens = <ConsultaNaLista>[];
    for (var numero = 1; numero <= paginasNaCarga; numero++) {
      final (:pagina, :erro) = await _pedir(numero);
      if (geracao != _geracao) return (itens: null, ultima: null, erro: null);
      if (pagina == null) return (itens: null, ultima: null, erro: erro);
      itens.addAll(pagina.itens);
      final chegouAoPassado = pagina.itens.isEmpty || !pagina.itens.last.horario.inicio.isAfter(relogio());
      if (!pagina.temMais || chegouAoPassado || numero == paginasNaCarga) {
        return (itens: _semRepetir(itens), ultima: pagina, erro: null);
      }
    }
    throw StateError('paginasNaCarga precisa ser ao menos 1');
  }

  /// Uma página, nunca lançando: a página, ou o erro que a tela mostra.
  Future<({Pagina<ConsultaNaLista>? pagina, ErroDaApi? erro})> _pedir(int numero) async {
    try {
      final pagina = await _consultas.minhas(pagina: numero);
      return (
        pagina: Pagina(
          itens: [for (final consulta in pagina.itens) _naLista(consulta)],
          pagina: pagina.pagina,
          paginas: pagina.paginas,
          total: pagina.total,
        ),
        erro: null,
      );
    } on ErroDaApi catch (erro) {
      return (pagina: null, erro: erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao carregar as consultas');
      return (pagina: null, erro: const ErroDaApi.falhaNoAplicativo());
    }
  }

  /// O repositório garante o horário e o profissional em cada consulta da
  /// lista; sem eles, é defeito.
  static ConsultaNaLista _naLista(Consulta consulta) =>
      naLista(consulta) ?? (throw StateError('Consulta ${consulta.id} sem o horário ou sem o profissional.'));

  /// Uma consulta pode vir em duas páginas — uma reserva feita em outro lugar
  /// empurra a lista entre um pedido e outro. Fica a primeira vez.
  static List<ConsultaNaLista> _semRepetir(List<ConsultaNaLista> itens) {
    final vistos = <int>{};
    return [
      for (final item in itens)
        if (vistos.add(item.consulta.id)) item,
    ];
  }

  void _aplicar(List<ConsultaNaLista> itens, Pagina<ConsultaNaLista> ultima) {
    _itens = itens;
    _pagina = ultima.pagina;
    _temMais = ultima.temMais;
    _total = ultima.total;
    _estado = EstadoDaCarga.pronto;
    _marcarRelogio();
  }

  /// Marca o relógio para o próximo instante em que alguma consulta muda de
  /// lista ou de ação — o prazo de uma reserva, o começo de um horário —, para
  /// a tela se refazer nessa hora sem pedir nada à API.
  ///
  /// Pode ficar marcado para dias depois, de propósito: é um só, trocado a cada
  /// carga e cancelado ao fechar. Se o aparelho dormir além da hora, ele
  /// dispara na volta.
  void _marcarRelogio() {
    _relogio?.cancel();
    if (_descartado) return;
    final agora = relogio();
    DateTime? proxima;
    for (final item in _itens) {
      final mudanca = item.proximaMudanca(agora);
      if (mudanca != null && (proxima == null || mudanca.isBefore(proxima))) proxima = mudanca;
    }
    if (proxima == null) return;
    _relogio = Timer(proxima.difference(agora), () {
      _marcarRelogio();
      _notificar();
    });
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _relogio?.cancel();
    _aviso.parar();
    super.dispose();
  }
}
