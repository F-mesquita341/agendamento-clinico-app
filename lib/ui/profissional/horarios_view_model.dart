import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';
import '../comum/estados_de_carga.dart';

/// A grade de um profissional: os dias a partir de hoje — hoje na clínica —,
/// os horários livres de cada um, e o dia e o horário que a pessoa escolheu.
class HorariosViewModel extends ChangeNotifier {
  HorariosViewModel(
    this._catalogo,
    this.profissional, {
    DateTime Function() agora = DateTime.now,
    this.esperaAteAvisar = const Duration(seconds: 4),
  })  : _agora = agora,
        _hoje = DataCivil.naClinica(agora());

  /// Quantos dias a grade mostra de início, e quantos a mais a cada pedido.
  static const diasPorVez = 14;

  /// O mais longe que a API deixa olhar.
  static const maximoDeDias = 60;

  final RepositorioDoCatalogo _catalogo;
  final Profissional profissional;
  final DateTime Function() _agora;

  /// Depois deste tempo carregando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  EstadoDaCarga _estado = EstadoDaCarga.carregando;
  DataCivil _hoje;
  int _quantosDias = diasPorVez;
  Map<DataCivil, List<Horario>> _porDia = const {};
  DataCivil? _diaEscolhido;
  Horario? _horarioEscolhido;
  Horario? _horarioPerdido;
  bool _vendoMaisDias = false;
  ErroDaApi? _erro;
  ErroDaApi? _erroAoAtualizar;
  ErroDaApi? _erroAoVerMaisDias;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  Timer? _relogio;
  bool _descartado = false;

  /// Cada pedido leva um número, e só a resposta do último vale. Sem isso, uma
  /// atualização de 14 dias que chegasse depois de um "ver mais dias" deixaria
  /// os dias a mais na tela sem os horários deles.
  int _pedido = 0;

  EstadoDaCarga get estado => _estado;

  /// O relógio que esta grade lê — o resumo e o pagamento seguem com ele.
  DateTime Function() get relogio => _agora;

  /// Hoje, no calendário da clínica.
  DataCivil get hoje => _hoje;

  /// Os dias da grade, de hoje em diante.
  List<DataCivil> get dias => [for (var i = 0; i < _quantosDias; i++) _hoje.maisDias(i)];

  /// Quantos dias a grade está mostrando.
  int get quantosDias => _quantosDias;
  bool get podeVerMaisDias => _quantosDias < maximoDeDias;
  bool get vendoMaisDias => _vendoMaisDias;

  /// Os horários livres do dia que ainda não começaram, na ordem. Vazia em dia
  /// sem horário.
  ///
  /// A API só manda horário futuro, mas a tela pode ficar aberta: o das 9:00
  /// carregado às 8:00 não pode ser escolhido às 9:05.
  List<Horario> horariosDe(DataCivil dia) {
    final agora = _agora();
    return [
      for (final horario in _porDia[dia] ?? const <Horario>[])
        if (horario.inicio.isAfter(agora)) horario,
    ];
  }

  /// O dia cujos horários a tela mostra; null se não há horário em dia nenhum.
  DataCivil? get diaEscolhido => _diaEscolhido;
  Horario? get horarioEscolhido => _horarioEscolhido;

  /// O horário que estava escolhido e deixou de estar livre na última vez que
  /// a grade foi carregada.
  Horario? get horarioPerdido => _horarioPerdido;

  /// Por que a primeira carga falhou.
  ErroDaApi? get erro => _erro;

  /// Por que a última atualização falhou — a grade anterior continua na tela.
  ErroDaApi? get erroAoAtualizar => _erroAoAtualizar;

  /// Por que os dias a mais não vieram — a grade anterior continua na tela.
  ErroDaApi? get erroAoVerMaisDias => _erroAoVerMaisDias;

  bool get demorando => _aviso.demorando;

  /// A primeira carga e o "Tentar de novo".
  Future<void> carregar() async {
    final pedido = ++_pedido;
    _estado = EstadoDaCarga.carregando;
    _erro = null;
    _erroAoAtualizar = null;
    _erroAoVerMaisDias = null;
    _vendoMaisDias = false;
    _aviso.iniciar();
    _notificar();

    final (:grade, :erro) = await _pedir(_quantosDias);
    if (pedido != _pedido) return;
    _aviso.parar();
    if (grade != null) {
      _mostrar(grade);
      _estado = EstadoDaCarga.pronto;
    } else {
      _erro = erro;
      _estado = EstadoDaCarga.falhou;
    }
    _notificar();
  }

  /// Puxar para atualizar: a grade de novo, com a anterior na tela. Se falhar,
  /// ela fica e [erroAoAtualizar] diz por quê.
  Future<void> atualizar() async {
    if (_estado != EstadoDaCarga.pronto) return carregar();
    final pedido = ++_pedido;
    _erroAoAtualizar = null;
    _erroAoVerMaisDias = null;
    _vendoMaisDias = false;
    _aviso.iniciar();
    _notificar();

    final (:grade, :erro) = await _pedir(_quantosDias);
    if (pedido != _pedido) return;
    _aviso.parar();
    if (grade != null) {
      _mostrar(grade);
    } else {
      _erroAoAtualizar = erro;
    }
    _notificar();
  }

  /// Mais [diasPorVez] dias de grade, até o [maximoDeDias].
  Future<void> verMaisDias() async {
    final pedido = ++_pedido;
    _vendoMaisDias = true;
    _erroAoVerMaisDias = null;
    _aviso.iniciar();
    _notificar();

    final (:grade, :erro) = await _pedir(min(_quantosDias + diasPorVez, maximoDeDias));
    if (pedido != _pedido) return;
    _aviso.parar();
    _vendoMaisDias = false;
    if (grade != null) {
      _mostrar(grade);
    } else {
      _erroAoVerMaisDias = erro;
    }
    _notificar();
  }

  /// Troca o dia mostrado. O horário escolhido era de outro dia: sai.
  void escolherDia(DataCivil dia) {
    if (dia == _diaEscolhido) return;
    _diaEscolhido = dia;
    _horarioEscolhido = null;
    _horarioPerdido = null;
    _notificar();
  }

  /// Escolhe o horário — o da grade, com a versão que veio nela. Horário que
  /// já começou, ou que não é desta grade, não é escolhido: a tela diz que ele
  /// não está mais livre. É desta escolha que a Etapa 14 vai agendar.
  void escolherHorario(Horario horario) {
    final daGrade = _aindaLivre(horario.id);
    if (daGrade == null) {
      _horarioPerdido = horario;
      _reconferir();
    } else {
      _horarioEscolhido = daGrade;
      _horarioPerdido = null;
    }
    _notificar();
  }

  /// O horário que outra pessoa reservou antes — o conflito do lock otimista
  /// (TCC, Seção 3.8.3). Sai da grade na hora: mesmo que a atualização que vem
  /// a seguir falhe, ele não é oferecido de novo. Se era o escolhido, a escolha
  /// sai sem o aviso de horário perdido, porque quem explica é a folha do
  /// conflito.
  void perderHorario(Horario perdido) {
    for (final doDia in _porDia.values) {
      doDia.removeWhere((horario) => horario.id == perdido.id);
    }
    if (_horarioEscolhido?.id == perdido.id) _horarioEscolhido = null;
    _horarioPerdido = null;
    _reconferir();
    _notificar();
  }

  /// Os primeiros [quantos] horários livres a partir do dia [aPartirDe], na
  /// ordem — as sugestões depois de um conflito.
  List<Horario> proximosLivres({required DataCivil aPartirDe, int quantos = 4}) => [
        for (final dia in dias)
          if (dia.compareTo(aPartirDe) >= 0) ...horariosDe(dia),
      ].take(quantos).toList();

  /// Pede a grade de [quantos] dias a partir de hoje. Devolve a grade, ou o
  /// erro que a tela mostra: nunca lança, para nenhum pedido deixar a tela
  /// presa carregando.
  Future<({_Grade? grade, ErroDaApi? erro})> _pedir(int quantos) async {
    // Hoje é lido a cada pedido: a tela pode ter ficado aberta de um dia para
    // o outro.
    final hoje = DataCivil.naClinica(_agora());
    try {
      // Até o começo do dia seguinte ao último: os dias da grade vêm inteiros.
      final horarios = await _catalogo.horarios(profissional.id, ate: hoje.maisDias(quantos));
      return (grade: (hoje: hoje, quantosDias: quantos, horarios: horarios), erro: null);
    } on ErroDaApi catch (erro) {
      return (grade: null, erro: erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao carregar os horários');
      return (grade: null, erro: const ErroDaApi.falhaNoAplicativo());
    }
  }

  void _mostrar(_Grade grade) {
    _hoje = grade.hoje;
    _quantosDias = grade.quantosDias;
    _porDia = {};
    for (final horario in grade.horarios) {
      _porDia.putIfAbsent(horario.dia, () => []).add(horario);
    }

    _horarioPerdido = null;
    _reconferir();
    _marcarRelogio();
  }

  /// Confere a escolha e o dia contra a grade e o relógio.
  ///
  /// O horário escolhido continua escolhido se ainda está livre — com a versão
  /// que veio na grade, que é a que vale para agendar. Se não está, a escolha é
  /// desfeita, e a tela diz qual horário se perdeu. E o dia mostrado é sempre
  /// um dia com horário: o que estava, se ainda tem algum; senão, o primeiro
  /// que tiver.
  void _reconferir() {
    final escolhido = _horarioEscolhido;
    if (escolhido != null) {
      _horarioEscolhido = _aindaLivre(escolhido.id);
      if (_horarioEscolhido == null) _horarioPerdido = escolhido;
    }
    final mostrado = _diaEscolhido;
    if (mostrado == null || horariosDe(mostrado).isEmpty) {
      _diaEscolhido = dias.where((dia) => horariosDe(dia).isNotEmpty).firstOrNull;
    }
  }

  /// O horário da grade com este id, se ele ainda não começou.
  Horario? _aindaLivre(int id) {
    final agora = _agora();
    return _porDia.values
        .expand((doDia) => doDia)
        .where((horario) => horario.id == id && horario.inicio.isAfter(agora))
        .firstOrNull;
  }

  /// Marca o relógio para o começo do próximo horário da grade. Nessa hora ele
  /// sai da tela, e a escolha e o dia são conferidos de novo — sem a pessoa
  /// precisar atualizar.
  ///
  /// O relógio pode ficar marcado para dias depois, de propósito: é um só,
  /// trocado a cada carga e cancelado ao fechar a tela. Se o aparelho dormir
  /// além da hora, ele dispara na volta, e a conferência acontece então.
  void _marcarRelogio() {
    _relogio?.cancel();
    // Resposta que chega depois de a tela fechar não deixa relógio para trás.
    if (_descartado) return;
    final agora = _agora();
    DateTime? proximo;
    for (final horario in _porDia.values.expand((doDia) => doDia)) {
      if (horario.inicio.isAfter(agora) && (proximo == null || horario.inicio.isBefore(proximo))) {
        proximo = horario.inicio;
      }
    }
    if (proximo == null) return;
    _relogio = Timer(proximo.difference(agora), () {
      _reconferir();
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
    _aviso.parar();
    _relogio?.cancel();
    super.dispose();
  }
}

/// O que um pedido de grade traz: os horários, e o hoje e a quantidade de dias
/// com que ele foi feito.
typedef _Grade = ({DataCivil hoje, int quantosDias, List<Horario> horarios});
