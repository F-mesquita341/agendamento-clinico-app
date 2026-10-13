import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../../data/repositories/repositorio_do_consentimento.dart';
import '../../domain/models/erro_da_api.dart';
import '../comum/defeitos.dart';
import 'termos_conhecidos.dart';

/// `desatualizado`: a versão vigente não é uma cujo texto o aplicativo tem.
enum EstadoDoTermo { carregando, pronto, desatualizado, falhou }

/// O termo de consentimento a mostrar antes do cadastro (checklist, item 10.4).
///
/// O aceite começa desmarcado e só vale para a versão cujo texto está na
/// tela. Ele não é enviado daqui: segue com o cadastro, que é onde a API o
/// registra.
class TermoViewModel extends ChangeNotifier {
  TermoViewModel(
    this._consentimento, {
    Future<String> Function(String caminho)? lerArquivo,
    this.conhecidos = termosConhecidos,
    this.esperaAteAvisar = const Duration(seconds: 4),
  }) : _lerArquivo = lerArquivo ?? rootBundle.loadString;

  final RepositorioDoConsentimento _consentimento;
  final Future<String> Function(String caminho) _lerArquivo;
  final Map<String, ({String termo, String resumo})> conhecidos;
  final Duration esperaAteAvisar;

  EstadoDoTermo _estado = EstadoDoTermo.carregando;
  String? _versao;
  String? _resumo;
  String? _texto;
  ErroDaApi? _erro;
  bool _aceito = false;

  /// Cada carga ganha um número. Resposta de uma carga já substituída é
  /// descartada: sem isso, a mais lenta venceria, e a tela podia ficar com o
  /// texto de uma versão que já não é a vigente.
  int _geracao = 0;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  EstadoDoTermo get estado => _estado;

  /// A versão vigente, segundo a API.
  String? get versao => _versao;
  String? get resumo => _resumo;
  String? get texto => _texto;
  ErroDaApi? get erro => _erro;
  bool get aceito => _aceito;
  bool get demorando => _aviso.demorando;

  /// Só se pode seguir com o texto da versão vigente na tela e o aceite
  /// marcado pela própria pessoa.
  bool get podeContinuar => _estado == EstadoDoTermo.pronto && _aceito;

  Future<void> carregar() async {
    final geracao = ++_geracao;
    _estado = EstadoDoTermo.carregando;
    _erro = null;
    _aceito = false;
    _aviso.iniciar();
    _notificar();

    try {
      final versao = await _consentimento.versaoVigente();
      if (geracao != _geracao) return;
      _versao = versao;
      final arquivos = conhecidos[versao];
      if (arquivos == null) {
        // Nunca cair num texto que o aplicativo tem: o aceite seria de um
        // texto diferente do que vale para a pessoa.
        _estado = EstadoDoTermo.desatualizado;
        return;
      }
      final resumo = await _lerArquivo(arquivos.resumo);
      final texto = await _lerArquivo(arquivos.termo);
      if (geracao != _geracao) return;
      _resumo = resumo;
      _texto = texto;
      _estado = EstadoDoTermo.pronto;
    } on ErroDaApi catch (erro) {
      if (geracao != _geracao) return;
      _erro = erro;
      _estado = EstadoDoTermo.falhou;
    } catch (erro, pilha) {
      if (geracao != _geracao) return;
      relatarDefeito(erro, pilha, 'ao carregar o termo de consentimento');
      _erro = const ErroDaApi.falhaNoAplicativo();
      _estado = EstadoDoTermo.falhou;
    } finally {
      if (geracao == _geracao) {
        _aviso.parar();
        _notificar();
      }
    }
  }

  void marcarAceite(bool aceito) {
    _aceito = aceito;
    _notificar();
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
