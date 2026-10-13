import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/especialidade.dart';
import '../comum/defeitos.dart';

/// Estado da primeira carga. Depois que a lista apareceu, atualizar não volta
/// a `carregando`: a lista fica na tela enquanto a nova chega.
enum EstadoDaCarga { carregando, pronto, falhou }

class EspecialidadesViewModel extends ChangeNotifier {
  EspecialidadesViewModel(
    this._catalogo, {
    this.esperaAteAvisar = const Duration(seconds: 4),
  });

  final RepositorioDoCatalogo _catalogo;

  /// Depois deste tempo carregando, a tela avisa que o servidor está
  /// demorando. Visibilidade do estado do sistema (heurística 1 de Nielsen):
  /// sem o aviso, um minuto de espera parece travamento.
  final Duration esperaAteAvisar;

  EstadoDaCarga _estado = EstadoDaCarga.carregando;
  List<Especialidade> _itens = const [];
  ErroDaApi? _erro;
  ErroDaApi? _erroAoAtualizar;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  EstadoDaCarga get estado => _estado;
  List<Especialidade> get itens => _itens;

  /// Por que a primeira carga falhou.
  ErroDaApi? get erro => _erro;

  /// Por que a última atualização falhou — a lista anterior continua na tela.
  ErroDaApi? get erroAoAtualizar => _erroAoAtualizar;

  /// A primeira carga passou do tempo de aviso. Não afirma a causa: pode ser
  /// o servidor acordando, pode ser o servidor fora do ar.
  bool get demorando => _aviso.demorando;

  Future<void> carregar() async {
    // Com a lista já na tela, é uma atualização: ela fica onde está.
    final atualizacao = _estado == EstadoDaCarga.pronto;
    _erroAoAtualizar = null;
    _aviso.parar();
    if (!atualizacao) {
      _estado = EstadoDaCarga.carregando;
      _erro = null;
      _aviso.iniciar();
    }
    _notificar();

    try {
      _itens = await _catalogo.especialidades();
      _estado = EstadoDaCarga.pronto;
    } on ErroDaApi catch (erro) {
      _registrarFalha(erro, atualizacao);
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao carregar as especialidades');
      _registrarFalha(const ErroDaApi.falhaNoAplicativo(), atualizacao);
    } finally {
      _aviso.parar();
      _notificar();
    }
  }

  void _registrarFalha(ErroDaApi erro, bool atualizacao) {
    if (atualizacao) {
      _erroAoAtualizar = erro;
    } else {
      _erro = erro;
      _estado = EstadoDaCarga.falhou;
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
