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

  /// "faltam 14 minutos", arredondado para cima: logo depois de reservar, são
  /// os 15 minutos prometidos no resumo. No último minuto, "falta menos de 1
  /// minuto". Null sem prazo, ou com ele vencido.
  String? get quantoFalta {
    final minutos = _minutosQueFaltam();
    if (minutos == null) return null;
    // O número não fica numa linha e "minutos" na outra.
    return minutos == 1 ? 'falta menos de 1\u00a0minuto' : 'faltam $minutos\u00a0minutos';
  }

  /// Os minutos que faltam, arredondados para cima; null sem prazo ou vencido.
  int? _minutosQueFaltam() {
    final resta = _resta();
    if (resta == null) return null;
    return (resta.inMicroseconds / Duration.microsecondsPerMinute).ceil();
  }

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
    _relogio = Timer(resta - Duration(minutes: minutos - 1), () {
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
