import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/instante.dart';
import '../../domain/models/profissional.dart';

/// A consulta reservada, esperando o pagamento: até quando a reserva vale, e
/// quanto falta. A Etapa 15 acrescenta aqui o pagar.
class ReservaViewModel extends ChangeNotifier {
  ReservaViewModel(
    this.consulta, {
    required this.profissional,
    required this.horario,
    required this.relogio,
  }) {
    _marcarRelogio();
  }

  final Consulta consulta;
  final Profissional profissional;
  final Horario horario;

  /// O relógio do aparelho — o mesmo que a grade usa para tirar os horários
  /// que já começaram.
  final DateTime Function() relogio;

  Timer? _relogio;
  bool _descartado = false;

  /// Hoje, na clínica.
  DataCivil get hoje => DataCivil.naClinica(relogio());

  /// Até quando a reserva espera o pagamento, como a API disse.
  DateTime? get prazo => consulta.reservaExpiraEm;

  /// "10:15", na hora da clínica.
  String? get ateAs => switch (prazo) {
        final prazo? => horaNaClinica(prazo),
        null => null,
      };

  /// O prazo passou: a API já não aceita o pagamento desta reserva. É o prazo
  /// que a API deu, e não um status deduzido (checklist, item 1.5); a Etapa 15
  /// passa a conferir o status também.
  bool get expirou => switch (prazo) {
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
  /// faltam diminuem um, ou quando o prazo vence —, e não a cada segundo.
  void _marcarRelogio() {
    _relogio?.cancel();
    if (_descartado) return;
    final resta = _resta();
    final minutos = _minutosQueFaltam();
    if (resta == null || minutos == null) return;
    _relogio = Timer(resta - _proximaTroca(minutos), () {
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
    super.dispose();
  }
}
