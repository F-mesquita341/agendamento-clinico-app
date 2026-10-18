import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
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

/// Outra pessoa reservou o horário antes — o lock otimista da API percebeu
/// pela versão (TCC, Seção 3.8.3). A grade recarrega e explica, com a mensagem
/// da API.
final class Conflito extends DesfechoDoResumo {
  const Conflito(this.erro);

  final ErroDaApi erro;
}

/// O resumo da consulta: o que vai ser reservado, e a reserva em si.
class ResumoViewModel extends ChangeNotifier {
  ResumoViewModel(
    this._consultas, {
    required this.profissional,
    required this.horario,
    required this.hoje,
    this.esperaAteAvisar = const Duration(seconds: 4),
  });

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

  bool _enviando = false;
  String? _erro;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  /// Uma tentativa terminou sem resposta, e a reserva pode ter sido feita
  /// mesmo assim. Enquanto isso valer, nada é dito sobre o horário antes de
  /// conferir as consultas da pessoa.
  bool _incerto = false;

  bool get enviando => _enviando;

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
    if (_enviando) return null;
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
      if (achada != null) return Reservada(achada);
      if (falha != null) return _naoConfirmou(falha);
      // Não estava lá: a tentativa anterior não reservou, e pedir de novo é
      // seguro.
    }

    try {
      return Reservada(await _consultas.agendar(horarioId: horario.id, versao: horario.versao));
    } on ErroDaApi catch (erro) {
      // Decide pela ação, nunca pelo código HTTP nem pelo texto.
      if (erro.acao == AcaoSugerida.recarregarHorarios) {
        // Depois de uma tentativa sem resposta, quem reservou o horário pode
        // ter sido a própria pessoa.
        if (_incerto) {
          final (:achada, :falha) = await _procurarReserva();
          if (achada != null) return Reservada(achada);
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
    if (achada != null) return Reservada(achada);
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
