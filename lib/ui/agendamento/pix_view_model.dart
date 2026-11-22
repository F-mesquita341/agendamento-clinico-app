import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/pix.dart';
import '../comum/defeitos.dart';

/// A espera do Pix: enquanto a tela está aberta, pergunta à API a cada
/// [intervalo] se ele foi pago (contrato da versão 2, "Pix"). Para quando a
/// API decide — confirmada, ou cancelada pelo prazo — e entrega a consulta a
/// quem abriu a tela, que decide o que vem depois.
class PixViewModel extends ChangeNotifier {
  PixViewModel(
    this.pix, {
    required this.consultaId,
    required RepositorioDeConsultas consultas,
    required this.relogio,
  }) : _consultas = consultas {
    _marcarProxima();
  }

  /// A cada 5 segundos: 12 conferências por minuto, abaixo do limite de
  /// escritas da API (30 por minuto).
  static const intervalo = Duration(seconds: 5);

  /// Quanto esperar depois do prazo: um Pix pago no último instante ainda
  /// confirma, e a rotina de expiração da API roda a cada minuto. Depois
  /// disso, a tela fecha, e quem a abriu confere a consulta.
  static const esperaDepoisDoPrazo = Duration(minutes: 3);

  final Pix pix;
  final int consultaId;
  final DateTime Function() relogio;
  final RepositorioDeConsultas _consultas;

  Consulta? _decidida;
  bool _indisponivel = false;
  bool _esgotou = false;
  int _rodada = 0;
  Timer? _proxima;
  bool _descartado = false;

  /// A consulta que a API devolveu ao decidir: confirmada, ou cancelada.
  Consulta? get decidida => _decidida;

  /// A API respondeu que o Pix está desligado: a espera parou.
  bool get indisponivel => _indisponivel;

  /// O prazo passou e a API não decidiu a tempo: a tela fecha sem decisão.
  bool get esgotou => _esgotou;

  /// Ainda esperando o pagamento.
  bool get esperando => _decidida == null && !_indisponivel && !_esgotou;

  /// O aplicativo voltou para a frente — por exemplo, do app do banco. A
  /// conferência é feita na hora, sem esperar o intervalo.
  void aoVoltar() {
    if (esperando) conferirAgora();
  }

  /// Uma conferência, e a próxima marcada se a API ainda não decidiu.
  Future<void> conferirAgora() async {
    if (!esperando || _descartado) return;
    _proxima?.cancel();
    final rodada = ++_rodada;
    try {
      final lida = await _consultas.conferirPix(consultaId);
      if (_descartado || rodada != _rodada) return;
      if (lida.status == StatusDaConsulta.confirmada || lida.status == StatusDaConsulta.cancelada) {
        _decidida = lida;
        _notificar();
        return;
      }
    } on ErroDaApi catch (erro) {
      if (_descartado || rodada != _rodada) return;
      if (erro.status == 404 && erro.codigo == 'ROTA_NAO_ENCONTRADA') {
        _indisponivel = true;
        _notificar();
        return;
      }
      // Sem conexão, servidor demorando: tenta de novo no próximo intervalo.
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao conferir o Pix');
      if (_descartado || rodada != _rodada) return;
    }
    _marcarProxima();
  }

  void _marcarProxima() {
    _proxima?.cancel();
    if (_descartado || !esperando) return;
    if (!relogio().isBefore(pix.expiraEm.add(esperaDepoisDoPrazo))) {
      _esgotou = true;
      _notificar();
      return;
    }
    _proxima = Timer(intervalo, conferirAgora);
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _proxima?.cancel();
    super.dispose();
  }
}
