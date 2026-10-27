import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../data/services/abridor_de_links.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/instante.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';
import '../consultas/cancelamento.dart';

/// Em que pé está o pagamento da reserva, do ponto de vista da tela.
enum SituacaoDoPagamento {
  /// O checkout ainda não foi aberto.
  aguardando,

  /// Pedindo a página de pagamento e abrindo a aba.
  abrindo,

  /// A aba de pagamento foi aberta; a pessoa está lá, ou acabou de voltar.
  noCheckout,

  /// De volta ao aplicativo: conferindo com a API, por alguns segundos.
  conferindo,

  /// A API ainda não confirmou. A conferência continua, mais espaçada.
  pendente,

  /// O prazo passou com o checkout aberto: a pessoa pode ter pago no último
  /// minuto, e a API ainda pode confirmar. Conferindo antes de dizer que a
  /// reserva expirou.
  conferindoDepoisDoPrazo,

  /// Cancelando a reserva, a pedido da pessoa.
  cancelando,

  /// A API disse `confirmada`.
  confirmada,

  /// A reserva acabou: o prazo venceu, ou a consulta foi cancelada.
  encerrada,

  /// A pessoa cancelou a reserva por esta tela.
  cancelada,
}

/// A consulta reservada, esperando o pagamento: até quando a reserva vale,
/// quanto falta, e o pagamento em si — abrir a página do Mercado Pago, em
/// ambiente de teste, e saber pela API se ele foi confirmado (TCC, Seção
/// 3.9.5; checklist, itens 1.5, 3.2 e 9.2).
class ReservaViewModel extends ChangeNotifier {
  ReservaViewModel(
    this.consulta, {
    required RepositorioDeConsultas consultas,
    required AbridorDeLinks abridor,
    required this.profissional,
    required this.horario,
    required this.relogio,
    this.esperaAteAvisar = const Duration(seconds: 4),
  })  : _consultas = consultas,
        _abridor = abridor {
    _marcarRelogio();
  }

  /// Logo depois da volta do checkout, a API é consultada [conferenciasRapidas]
  /// vezes, com este intervalo: o aviso do Mercado Pago chega em segundos (27 s
  /// no portão da Etapa 8).
  static const intervaloDaConferencia = Duration(seconds: 3);
  static const conferenciasRapidas = 5;

  /// Depois disso, a conferência continua sozinha, mais espaçada, enquanto a
  /// tela estiver aberta: a confirmação que chega tarde leva a pessoa à tela
  /// de confirmação sem ela fazer nada.
  static const intervaloDaConferenciaContinuada = Duration(seconds: 10);

  /// Um teto para a conferência continuada: o tempo de uma reserva, 15
  /// minutos a cada 10 s. Com o prazo, o relógio da reserva a encerra antes.
  /// Sem ele — a API sempre o manda, mas a tela não depende disso —, ela não
  /// fica perguntando para sempre; voltar ao aplicativo recomeça (revisão de
  /// 19/10, P6).
  static const conferenciasContinuadas = 90;

  /// Quanto esperar a API decidir depois do prazo, com o checkout aberto. A
  /// rotina de expiração da API roda a cada minuto e, antes de expirar, pergunta
  /// ao Mercado Pago se houve pagamento: a confirmação pode chegar até um
  /// minuto depois do prazo, ou mais, se o provedor demorar.
  static const esperaDepoisDoPrazo = Duration(minutes: 3);

  final Consulta consulta;
  final Profissional profissional;
  final Horario horario;

  /// O relógio do aparelho — o mesmo que a grade usa para tirar os horários
  /// que já começaram.
  final DateTime Function() relogio;

  /// Depois deste tempo abrindo o pagamento, a tela avisa que o servidor está
  /// demorando.
  final Duration esperaAteAvisar;

  final RepositorioDeConsultas _consultas;
  final AbridorDeLinks _abridor;

  SituacaoDoPagamento _situacao = SituacaoDoPagamento.aguardando;
  String? _erro;
  Consulta? _confirmada;
  MotivoDoCancelamento? _motivoDoFim;
  bool _abriuOCheckout = false;
  bool _pagamentoTalvezFeito = false;
  int _conferencias = 0;

  /// Cada leitura da API leva um número, e só a da última vale: voltar ao
  /// aplicativo com uma conferência no ar não pode deixar duas correndo.
  int _rodada = 0;
  DateTime? _desdeOPrazo;
  Timer? _relogio;
  Timer? _conferencia;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  SituacaoDoPagamento get situacao => _situacao;

  /// Por que a última tentativa de abrir o pagamento não deu certo.
  String? get erro => _erro;

  bool get demorando => _aviso.demorando;

  /// A consulta como a API a devolveu ao confirmar — é dela que sai a tela de
  /// confirmação (checklist, item 1.4).
  Consulta? get confirmada => _confirmada;

  /// Por que a reserva acabou, quando acabou por cancelamento.
  MotivoDoCancelamento? get motivoDoFim => _motivoDoFim;

  /// O checkout foi aberto, e o prazo passou sem a API decidir: a pessoa pode
  /// ter pago. A folha da reserva vencida diz isso.
  bool get pagamentoTalvezFeito => _pagamentoTalvezFeito;

  /// O checkout já foi aberto nesta tela: o botão vira "Abrir pagamento de
  /// novo".
  bool get abriuOCheckout => _abriuOCheckout;

  /// Hoje, na clínica.
  DataCivil get hoje => DataCivil.naClinica(relogio());

  /// Até quando a reserva espera o pagamento, como a API disse.
  DateTime? get prazo => consulta.reservaExpiraEm;

  /// "10:15", na hora da clínica.
  String? get ateAs => switch (prazo) {
        final prazo? => horaNaClinica(prazo),
        null => null,
      };

  /// O prazo que a API deu passou. Não é o status da consulta: quem diz se ela
  /// foi confirmada ou expirou é a API (checklist, item 1.5).
  bool get prazoPassou => switch (prazo) {
        final prazo? => !prazo.isAfter(relogio()),
        null => false,
      };

  /// "faltam 14 minutos": logo depois de reservar, são os 15 minutos
  /// prometidos no resumo. No último minuto, "falta menos de 1 minuto". Null
  /// sem prazo, ou com ele vencido.
  String? get quantoFalta {
    // O número não fica numa linha e "minutos" na outra.
    return switch (_minutosQueFaltam()) {
      null => null,
      0 => 'falta menos de 1\u00a0minuto',
      1 => 'falta 1\u00a0minuto',
      final minutos => 'faltam $minutos\u00a0minutos',
    };
  }

  bool get _ocupado => switch (_situacao) {
        SituacaoDoPagamento.abrindo ||
        SituacaoDoPagamento.conferindo ||
        SituacaoDoPagamento.conferindoDepoisDoPrazo ||
        SituacaoDoPagamento.cancelando ||
        SituacaoDoPagamento.confirmada ||
        SituacaoDoPagamento.encerrada ||
        SituacaoDoPagamento.cancelada =>
          true,
        _ => false,
      };

  /// Pede a página de pagamento à API e a abre numa aba. Pedir de novo devolve
  /// a mesma página enquanto ela estiver aberta, então "Abrir pagamento de
  /// novo" é o mesmo pedido. Ocupado, não faz nada: um toque a mais não abre
  /// duas abas (checklist, item 5.3).
  Future<void> abrirPagamento() async {
    if (_ocupado) return;
    final antes = _situacao;
    _situacao = SituacaoDoPagamento.abrindo;
    _erro = null;
    _notificar();

    try {
      final checkout = await _aviso.acompanhar(() => _consultas.pagar(consulta.id));
      if (_descartado) return;
      final abriu = await _abridor.abrirPagamento(checkout.endereco);
      if (_descartado) return;
      if (abriu) {
        _abriuOCheckout = true;
        _situacao = SituacaoDoPagamento.noCheckout;
      } else {
        _situacao = antes;
        _erro = 'Não foi possível abrir a página de pagamento. Tente de novo.';
      }
    } on ErroDaApi catch (erro) {
      if (_descartado) return;
      if (erro.status >= 400 && erro.status < 500) {
        // A API recusou — já paga, não pagável, prazo vencido. A recusa vem
        // sem ação, e o código não decide nada aqui: quem decide é o status
        // da consulta, relido agora.
        await _decidirPeloStatus(seNaoDecidir: erro.mensagem, antes: antes);
      } else {
        _situacao = antes;
        _erro = erro.mensagem;
      }
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao abrir o pagamento');
      if (_descartado) return;
      _situacao = antes;
      _erro = const ErroDaApi.falhaNoAplicativo().mensagem;
    }
    // O prazo pode ter vencido com o pedido no ar: o relógio encontrou a tela
    // ocupada e não decidiu nada. Se a página não abriu, a decisão é agora, e
    // não no próximo toque (revisão de 19/10, P4). Se abriu, é na volta.
    if (prazoPassou && _situacao != SituacaoDoPagamento.noCheckout) _aoVencerOPrazo();
    _notificar();
  }

  /// "Cancelar reserva" vale quando a tela não está fazendo outra coisa nem
  /// já decidiu.
  bool get podeCancelarAReserva => !_ocupado;

  /// Cancela a reserva por esta tela, depois de a pessoa confirmar. É o mesmo
  /// cancelamento dos detalhes da consulta: a decisão é pelo status relido.
  Future<void> cancelarReserva() async {
    if (_ocupado) return;
    final antes = _situacao;
    // A conferência que segue sozinha poderia decidir a tela no meio do
    // cancelamento — a API dizendo "cancelada" antes da resposta dele. Ela
    // para aqui, e volta se o cancelamento não acontecer.
    _conferencia?.cancel();
    _rodada++;
    _situacao = SituacaoDoPagamento.cancelando;
    _erro = null;
    _notificar();

    final desfecho = await _aviso.acompanhar(() => cancelarConsulta(_consultas, consulta.id));
    if (_descartado) return;
    _situacao = antes;
    switch (desfecho) {
      case ConsultaCancelada(consulta: Consulta(motivoDoCancelamento: MotivoDoCancelamento.paciente)):
        _encerrarConferencias();
        _situacao = SituacaoDoPagamento.cancelada;
      case ConsultaCancelada(:final consulta):
        // A API já tinha expirado a reserva: a folha da reserva vencida explica.
        _aplicar(consulta);
      case CancelamentoRecusado(:final mensagem, :final lida):
        if (lida == null || !_aplicar(lida)) _erro = mensagem;
    }
    if (_situacao == SituacaoDoPagamento.pendente) _marcarProximaConferencia();
    // O prazo pode ter vencido durante o pedido, com a tela ocupada.
    if (prazoPassou && _situacao != SituacaoDoPagamento.noCheckout) _aoVencerOPrazo();
    _notificar();
  }

  /// O aplicativo voltou para a frente — a pessoa fechou a aba de pagamento,
  /// ou voltou de outro lugar. Se o checkout foi aberto e nada foi decidido
  /// ainda, a API é consultada: a volta em si não confirma nada.
  void aoVoltar() {
    if (_descartado || !_abriuOCheckout) return;
    if (_situacao != SituacaoDoPagamento.noCheckout && _situacao != SituacaoDoPagamento.pendente) return;
    if (prazoPassou) return _aoVencerOPrazo();
    _situacao = SituacaoDoPagamento.conferindo;
    _conferencias = 0;
    _notificar();
    _conferirAgora();
  }

  /// Uma consulta à API, e o que vem depois dela, conforme a situação.
  Future<void> _conferirAgora() async {
    _conferencia?.cancel();
    final rodada = ++_rodada;
    final Consulta lida;
    try {
      lida = await _consultas.consulta(consulta.id);
    } on ErroDaApi {
      // Sem conexão, servidor demorando: a conferência segue na próxima vez.
      if (rodada == _rodada) _marcarProximaConferencia();
      return;
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao conferir o pagamento');
      if (rodada == _rodada) _marcarProximaConferencia();
      return;
    }
    if (_descartado || rodada != _rodada) return;
    if (!_aplicar(lida)) _marcarProximaConferencia();
    _notificar();
  }

  /// O status que a API devolveu decide. Devolve true se decidiu — confirmada
  /// ou encerrada.
  bool _aplicar(Consulta lida) {
    switch (lida.status) {
      case StatusDaConsulta.confirmada:
        _confirmada = lida;
        _encerrarConferencias();
        _situacao = SituacaoDoPagamento.confirmada;
        return true;
      case StatusDaConsulta.cancelada:
        _motivoDoFim = lida.motivoDoCancelamento;
        _encerrarConferencias();
        _situacao = SituacaoDoPagamento.encerrada;
        return true;
      default:
        return false;
    }
  }

  /// Marca a próxima consulta à API, conforme a situação: rápida logo depois
  /// da volta, espaçada depois, e até um limite depois do prazo.
  void _marcarProximaConferencia() {
    _conferencia?.cancel();
    if (_descartado) return;
    switch (_situacao) {
      case SituacaoDoPagamento.conferindo:
        _conferencias++;
        if (_conferencias < conferenciasRapidas) {
          _conferencia = Timer(intervaloDaConferencia, _conferirAgora);
        } else {
          _situacao = SituacaoDoPagamento.pendente;
          _conferencia = Timer(intervaloDaConferenciaContinuada, _conferirAgora);
          _notificar();
        }
      case SituacaoDoPagamento.pendente:
        _conferencias++;
        if (_conferencias < conferenciasRapidas + conferenciasContinuadas) {
          _conferencia = Timer(intervaloDaConferenciaContinuada, _conferirAgora);
        }
      case SituacaoDoPagamento.conferindoDepoisDoPrazo:
        final desde = _desdeOPrazo ?? relogio();
        if (relogio().difference(desde) >= esperaDepoisDoPrazo) {
          // A API não decidiu a tempo. A reserva é dada como vencida, mas a
          // folha avisa que um pagamento feito ainda pode ser confirmado.
          _pagamentoTalvezFeito = true;
          _situacao = SituacaoDoPagamento.encerrada;
          _notificar();
        } else {
          _conferencia = Timer(intervaloDaConferenciaContinuada, _conferirAgora);
        }
      default:
        break;
    }
  }

  /// O prazo da reserva passou. Sem checkout aberto, não houve pagamento
  /// possível, e a reserva acabou. Com ele, a pessoa pode ter pago no último
  /// minuto: a API é consultada antes de dizer que a reserva expirou.
  void _aoVencerOPrazo() {
    if (_descartado || (_ocupado && _situacao != SituacaoDoPagamento.conferindo)) return;
    // O erro da última tentativa de abrir a página não vale mais: agora é o
    // prazo que fala.
    _erro = null;
    if (!_abriuOCheckout) {
      _situacao = SituacaoDoPagamento.encerrada;
      _encerrarConferencias();
      _notificar();
      return;
    }
    _situacao = SituacaoDoPagamento.conferindoDepoisDoPrazo;
    _desdeOPrazo = relogio();
    _notificar();
    _conferirAgora();
  }

  /// Uma recusa do pagamento: relê a consulta e deixa o status decidir. Se ela
  /// ainda espera pagamento, a mensagem da API fica na tela. Com o prazo já
  /// passado, quem decide é o vencimento, ao fim de [abrirPagamento]: com a
  /// página aberta antes, a pessoa pode ter pago, e a API é consultada antes
  /// de a reserva ser dada como vencida.
  Future<void> _decidirPeloStatus({required String seNaoDecidir, required SituacaoDoPagamento antes}) async {
    try {
      final lida = await _consultas.consulta(consulta.id);
      if (_descartado || _aplicar(lida)) return;
    } on ErroDaApi {
      // Sem a releitura, fica a mensagem da recusa.
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao reler a consulta');
    }
    if (_descartado) return;
    _situacao = antes;
    _erro = seNaoDecidir;
  }

  void _encerrarConferencias() {
    _rodada++;
    _conferencia?.cancel();
    _relogio?.cancel();
  }

  /// Os minutos que faltam, arredondados para o mais próximo — e não para cima:
  /// o relógio do aparelho pode estar uns segundos atrás do servidor, e logo
  /// depois de reservar mostraria "faltam 16 minutos" de uma reserva de 15
  /// (portão da Etapa 14). Assim, diferenças de até meio minuto não aparecem.
  /// No último minuto, zero; null sem prazo, ou com ele vencido.
  int? _minutosQueFaltam() {
    final resta = _resta();
    if (resta == null) return null;
    if (resta <= const Duration(minutes: 1)) return 0;
    // Com meio minuto a menos, arredondar para cima é arredondar para o mais
    // próximo — e o meio exato fica com o menor, para a troca nunca cair no
    // instante em que o relógio é marcado.
    return ((resta - _meioMinuto).inMicroseconds / Duration.microsecondsPerMinute).ceil();
  }

  static const _meioMinuto = Duration(seconds: 30);

  /// Quanto falta quando o texto troca de novo: no meio minuto de baixo; de
  /// "falta 1 minuto" para "menos de 1", com um minuto; e, no último, no prazo.
  static Duration _proximaTroca(int minutos) => switch (minutos) {
        0 => Duration.zero,
        1 => const Duration(minutes: 1),
        _ => Duration(minutes: minutos - 1) + _meioMinuto,
      };

  Duration? _resta() {
    final prazo = this.prazo;
    if (prazo == null) return null;
    final resta = prazo.difference(relogio());
    return resta > Duration.zero ? resta : null;
  }

  /// Marca o relógio para a próxima troca do texto — quando os minutos que
  /// faltam diminuem um, ou quando o prazo vence —, e não a cada segundo. No
  /// prazo, a reserva é conferida (ver [_aoVencerOPrazo]).
  void _marcarRelogio() {
    _relogio?.cancel();
    if (_descartado) return;
    if (prazoPassou) {
      // A reserva achada depois de uma resposta perdida pode chegar já
      // vencida: a decisão fica para depois da construção.
      _relogio = Timer(Duration.zero, () {
        _aoVencerOPrazo();
      });
      return;
    }
    final resta = _resta();
    final minutos = _minutosQueFaltam();
    if (resta == null || minutos == null) return;
    _relogio = Timer(resta - _proximaTroca(minutos), () {
      if (prazoPassou) {
        _aoVencerOPrazo();
      } else {
        _marcarRelogio();
      }
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
    _conferencia?.cancel();
    super.dispose();
  }
}
