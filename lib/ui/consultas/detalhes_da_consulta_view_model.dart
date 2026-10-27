import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../comum/defeitos.dart';
import 'cancelamento.dart';
import 'situacao_da_consulta.dart';

/// Uma consulta aberta nos detalhes, e o cancelamento dela.
///
/// O horário e o profissional ficam os que a tela recebeu: a resposta do
/// cancelamento não os traz, e eles não mudam. Só a consulta — o status, o
/// motivo — é trocada pelo que a API disser.
class DetalhesDaConsultaViewModel extends ChangeNotifier {
  DetalhesDaConsultaViewModel(
    ConsultaNaLista item, {
    required RepositorioDeConsultas consultas,
    this.relogio = DateTime.now,
    this.esperaAteAvisar = const Duration(seconds: 4),
  })  : _consulta = item.consulta,
        horario = item.horario,
        profissional = item.profissional,
        _consultas = consultas {
    _marcarRelogio();
  }

  /// A mensagem de quem tenta cancelar depois do começo do horário — o botão
  /// já some nessa hora, mas o diálogo pode ter ficado aberto.
  static const jaComecou = 'O horário desta consulta já começou. Para falar sobre ela, ligue para a clínica.';

  final Horario horario;
  final Profissional profissional;

  /// O relógio do aparelho, o mesmo da lista.
  final DateTime Function() relogio;

  /// Depois deste tempo cancelando, a tela avisa que o servidor está demorando.
  final Duration esperaAteAvisar;

  final RepositorioDeConsultas _consultas;
  Consulta _consulta;
  bool _cancelando = false;
  String? _erro;
  Timer? _relogio;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  Consulta get consulta => _consulta;
  ConsultaNaLista get item => (consulta: _consulta, horario: horario, profissional: profissional);
  bool get cancelando => _cancelando;
  bool get demorando => _aviso.demorando;

  /// Por que o último cancelamento não deu certo.
  String? get erro => _erro;

  /// Hoje, na clínica.
  DataCivil get hoje => DataCivil.naClinica(relogio());

  bool get podeCancelar => item.podeCancelar(relogio());
  bool get podePagar => item.podePagar(relogio());
  bool get reservaVencida => item.reservaVencida(relogio());

  /// Cancela a consulta, depois de a pessoa confirmar. Devolve true só quando
  /// ela foi cancelada pela pessoa agora — é aí que a tela diz "Consulta
  /// cancelada.". Uma reserva que a API já tinha expirado mostra a nota dela,
  /// e não um sucesso.
  Future<bool> cancelar() async {
    if (_cancelando) return false;
    if (!podeCancelar) {
      // O diálogo ficou aberto até depois do horário: nada é enviado.
      _erro = jaComecou;
      _notificar();
      return false;
    }
    _cancelando = true;
    _erro = null;
    _notificar();

    final desfecho = await _aviso.acompanhar(() => cancelarConsulta(_consultas, _consulta.id));
    if (_descartado) return false;
    _cancelando = false;
    final bool cancelouAgora;
    switch (desfecho) {
      case ConsultaCancelada(:final consulta):
        _consulta = consulta;
        cancelouAgora = consulta.motivoDoCancelamento == MotivoDoCancelamento.paciente;
      case CancelamentoRecusado(:final mensagem, :final lida):
        if (lida != null) _consulta = lida;
        _erro = mensagem;
        cancelouAgora = false;
    }
    _marcarRelogio();
    _notificar();
    return cancelouAgora;
  }

  /// Marca o relógio para o próximo instante em que a consulta muda de ação —
  /// o prazo da reserva, o começo do horário —: nessa hora, "Pagar agora" e
  /// "Cancelar consulta" somem sem a pessoa precisar sair e voltar.
  void _marcarRelogio() {
    _relogio?.cancel();
    if (_descartado) return;
    final agora = relogio();
    final mudanca = item.proximaMudanca(agora);
    if (mudanca == null) return;
    _relogio = Timer(mudanca.difference(agora), () {
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
