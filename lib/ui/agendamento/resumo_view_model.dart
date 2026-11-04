import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/forma_de_pagamento.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';

/// Como o resumo termina, para quem o abriu.
sealed class DesfechoDoResumo {
  const DesfechoDoResumo();
}

/// O horário foi reservado: a consulta segue para o pagamento.
final class Reservada extends DesfechoDoResumo {
  const Reservada(this.consulta);

  final Consulta consulta;
}

/// A consulta já saiu confirmada — com o plano de saúde ou na clínica, sem
/// pagamento pelo aplicativo (versão 2): segue para a confirmação.
final class Confirmada extends DesfechoDoResumo {
  const Confirmada(this.consulta);

  final Consulta consulta;
}

/// Outra pessoa reservou o horário antes — o lock otimista da API percebeu
/// pela versão (TCC, Seção 3.8.3). A grade recarrega e explica, com a mensagem
/// da API.
final class Conflito extends DesfechoDoResumo {
  const Conflito(this.erro);

  final ErroDaApi erro;
}

/// O resumo da consulta: o que vai ser reservado, como vai ser pago, e a
/// reserva em si.
///
/// A forma de pagamento (versão 2): quem só aceita o aplicativo não pergunta
/// nada, como na v1. Com mais de uma forma, nenhuma vem marcada — a pessoa
/// escolhe, e só então confirma.
class ResumoViewModel extends ChangeNotifier {
  ResumoViewModel(
    this._consultas, {
    required this.profissional,
    required this.horario,
    required this.hoje,
    int? planoPreferido,
    this.esperaAteAvisar = const Duration(seconds: 4),
  }) {
    final formas = formasOferecidas;
    if (formas.length == 1) _forma = formas.single;
    final planos = profissional.planos;
    if (planos.length == 1) {
      _planoId = planos.single.id;
    } else if (planos.any((plano) => plano.id == planoPreferido)) {
      // O plano escolhido no filtro da Busca, se este profissional o aceita.
      _planoId = planoPreferido;
    }
  }

  /// Quantas páginas de consultas a conferência olha, no máximo. A reserva
  /// procurada é de um horário futuro, e a lista começa pelas mais adiante:
  /// ela está na primeira página, a não ser que a pessoa tenha dezenas de
  /// consultas marcadas.
  static const paginasParaConferir = 5;

  final RepositorioDeConsultas _consultas;
  final Profissional profissional;

  /// O horário escolhido na grade, com a versão que veio nela.
  final Horario horario;

  /// Hoje, na clínica — o mesmo da grade que abriu o resumo.
  final DataCivil hoje;

  /// Depois deste tempo enviando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  FormaDePagamento? _forma;
  int? _planoId;
  bool _enviando = false;
  String? _erro;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  /// Uma tentativa terminou sem resposta, e a reserva pode ter sido feita
  /// mesmo assim. Enquanto isso valer, nada é dito sobre o horário antes de
  /// conferir as consultas da pessoa.
  bool _incerto = false;

  bool get enviando => _enviando;

  /// As formas que a pessoa pode escolher, na ordem da API. O plano só entra
  /// se o profissional tem algum plano cadastrado; sem nenhuma forma que
  /// sirva, vale o aplicativo.
  List<FormaDePagamento> get formasOferecidas {
    final formas = [
      for (final forma in profissional.formasDePagamento)
        if (forma != FormaDePagamento.plano || profissional.planos.isNotEmpty) forma,
    ];
    return formas.isEmpty ? const [FormaDePagamento.app] : formas;
  }

  /// O resumo pergunta como pagar: quando há outra forma além do aplicativo.
  bool get pergunta => !(formasOferecidas.length == 1 && formasOferecidas.single == FormaDePagamento.app);

  /// A forma escolhida; null enquanto a pessoa não escolheu.
  FormaDePagamento? get forma => _forma;

  /// O plano escolhido, quando a forma é o plano.
  int? get planoId => _planoId;

  /// Dá para confirmar: há forma escolhida, e plano, quando a forma é o plano.
  bool get podeConfirmar => _forma != null && (_forma != FormaDePagamento.plano || _planoId != null);

  /// Pelo aplicativo, há a etapa do pagamento: três. Com o plano ou na
  /// clínica, a consulta se confirma no resumo: duas. Antes de escolher,
  /// conta a etapa do pagamento se ela é possível.
  int get etapas {
    final pagaPeloApp = _forma == null
        ? formasOferecidas.contains(FormaDePagamento.app)
        : _forma == FormaDePagamento.app;
    return pagaPeloApp ? 3 : 2;
  }

  void escolherForma(FormaDePagamento forma) {
    if (_enviando || forma == _forma || !formasOferecidas.contains(forma)) return;
    _forma = forma;
    // A recusa era da escolha anterior.
    _erro = null;
    _notificar();
  }

  void escolherPlano(int planoId) {
    if (_enviando || planoId == _planoId) return;
    _planoId = planoId;
    _erro = null;
    _notificar();
  }

  /// Por que a última tentativa não reservou — a mensagem da API, quando ela
  /// recusou (checklist, item 5.8).
  String? get erro => _erro;

  bool get demorando => _aviso.demorando;

  /// Reserva o horário. Devolve [Reservada] ou [Conflito] para a tela seguir;
  /// null quando fica no resumo, com [erro] dizendo por quê.
  ///
  /// Chamado de novo antes de terminar, não faz nada: um toque a mais não pode
  /// reservar duas vezes (checklist, item 5.3).
  Future<DesfechoDoResumo?> confirmar() async {
    if (_enviando || !podeConfirmar) return null;
    _enviando = true;
    _erro = null;
    _notificar();

    final desfecho = await _aviso.acompanhar(_tentar);
    _enviando = false;
    _notificar();
    return desfecho;
  }

  Future<DesfechoDoResumo?> _tentar() async {
    if (_incerto) {
      final (:achada, :falha) = await _procurarReserva();
      if (achada != null) return _desfechoDe(achada);
      if (falha != null) return _naoConfirmou(falha);
      // Não estava lá: a tentativa anterior não reservou, e pedir de novo é
      // seguro.
    }

    try {
      final forma = _forma!;
      return _desfechoDe(await _consultas.agendar(
        horarioId: horario.id,
        versao: horario.versao,
        formaDePagamento: forma,
        planoId: forma == FormaDePagamento.plano ? _planoId : null,
      ));
    } on ErroDaApi catch (erro) {
      // Decide pela ação, nunca pelo código HTTP nem pelo texto.
      if (erro.acao == AcaoSugerida.recarregarHorarios) {
        // Depois de uma tentativa sem resposta, quem reservou o horário pode
        // ter sido a própria pessoa.
        if (_incerto) {
          final (:achada, :falha) = await _procurarReserva();
          if (achada != null) return _desfechoDe(achada);
          if (falha != null) return _naoConfirmou(falha);
        }
        return Conflito(erro);
      }
      if (_recusou(erro)) {
        _erro = erro.mensagem;
        return null;
      }
      return _semResposta(erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao reservar o horário');
      return _semResposta(const ErroDaApi.falhaNoAplicativo());
    }
  }

  /// Confirmada já — plano ou clínica — vai à confirmação; aguardando o
  /// pagamento, ao pagamento. Vale também para a consulta achada depois de
  /// uma resposta perdida.
  static DesfechoDoResumo _desfechoDe(Consulta consulta) =>
      consulta.status == StatusDaConsulta.confirmada ? Confirmada(consulta) : Reservada(consulta);

  /// A API recebeu e recusou: com certeza não reservou.
  ///
  /// Todo o resto — sem conexão, prazo esgotado, resposta fora do formato,
  /// falha no servidor — pode ter acontecido depois de a reserva ser gravada.
  static bool _recusou(ErroDaApi erro) => erro.status >= 400 && erro.status < 500;

  /// A tentativa terminou sem saber se reservou: confere nas consultas da
  /// pessoa antes de dizer qualquer coisa. Se a reserva está lá, segue como
  /// se a resposta tivesse chegado.
  Future<DesfechoDoResumo?> _semResposta(ErroDaApi erro) async {
    _incerto = true;
    final (:achada, :falha) = await _procurarReserva();
    if (achada != null) return _desfechoDe(achada);
    if (falha != null) return _naoConfirmou(falha);
    _erro = erro.mensagem;
    return null;
  }

  DesfechoDoResumo? _naoConfirmou(ErroDaApi falha) {
    _erro = 'Não foi possível confirmar se o horário foi reservado. ${falha.mensagem}';
    return null;
  }

  /// Procura, nas consultas da pessoa, a que segura este horário. A lista vem
  /// da consulta mais adiante para a mais antiga: passada a data do horário,
  /// ele não aparece mais à frente.
  Future<({Consulta? achada, ErroDaApi? falha})> _procurarReserva() async {
    try {
      for (var numero = 1; numero <= paginasParaConferir; numero++) {
        final pagina = await _consultas.minhas(pagina: numero);
        for (final consulta in pagina.itens) {
          if (consulta.horarioId == horario.id && consulta.status.seguraOHorario) {
            return (achada: consulta, falha: null);
          }
        }
        final ultimo = pagina.itens.lastOrNull?.horario;
        if (!pagina.temMais || (ultimo != null && ultimo.inicio.isBefore(horario.inicio))) break;
      }
      return (achada: null, falha: null);
    } on ErroDaApi catch (erro) {
      return (achada: null, falha: erro);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao conferir a reserva');
      return (achada: null, falha: const ErroDaApi.falhaNoAplicativo());
    }
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _aviso.parar();
    super.dispose();
  }
}
