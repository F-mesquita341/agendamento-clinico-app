import 'package:flutter/foundation.dart';

import '../../data/repositories/repositorio_do_paciente.dart';
import '../../domain/models/dados_do_paciente.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/paciente.dart';
import '../comum/defeitos.dart';

/// Os campos do formulário, com os nomes que a API usa em `problemas`.
enum CampoDoPaciente {
  nome('nome'),
  telefone('telefone'),
  dataNascimento('dataNascimento');

  const CampoDoPaciente(this.naApi);
  final String naApi;
}

/// O envio do formulário do paciente — o cadastro, depois do termo, e a
/// edição dos dados, no perfil.
class FormularioDoPacienteViewModel extends ChangeNotifier {
  /// Cadastro, com o aceite da versão do termo que estava na tela.
  FormularioDoPacienteViewModel.cadastro(this._pacientes, {required String this.versaoDoTermo}) : atual = null;

  FormularioDoPacienteViewModel.edicao(this._pacientes, {required Paciente this.atual}) : versaoDoTermo = null;

  final RepositorioDoPaciente _pacientes;
  final String? versaoDoTermo;

  /// O perfil sendo editado; null no cadastro.
  final Paciente? atual;

  bool get cadastro => atual == null;

  bool _enviando = false;
  String? _erroGeral;
  final Map<CampoDoPaciente, String> _errosDosCampos = {};
  bool _termoMudou = false;
  bool _descartado = false;

  bool get enviando => _enviando;
  String? get erroGeral => _erroGeral;
  String? erroDo(CampoDoPaciente campo) => _errosDosCampos[campo];

  /// A versão do termo mudou entre a leitura e o envio: é preciso ler o novo.
  bool get termoMudou => _termoMudou;

  /// Envia, se não houver outro envio em andamento (checklist, itens 1.2 e
  /// 5.3). Devolve o perfil gravado, ou null se não deu certo — e então o
  /// erro fica no campo ou no aviso geral.
  Future<Paciente?> enviar(DadosDoPaciente dados) async {
    if (_enviando) return null;
    _enviando = true;
    _erroGeral = null;
    _errosDosCampos.clear();
    _termoMudou = false;
    _notificar();
    try {
      // Dois níveis de try: um defeito no próprio tratamento do erro — o
      // perfil relido depois de um 409, por exemplo — também cai na rede de
      // segurança, e não escapa do envio.
      try {
        return cadastro
            ? await _pacientes.cadastrar(dados, versaoDoTermo: versaoDoTermo!)
            : await _pacientes.atualizar(dados);
      } on ErroDaApi catch (erro) {
        return await _tratar(erro);
      }
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao enviar os dados do paciente');
      _erroGeral = const ErroDaApi.falhaNoAplicativo().mensagem;
      return null;
    } finally {
      _enviando = false;
      _notificar();
    }
  }

  Future<Paciente?> _tratar(ErroDaApi erro) async {
    // Cadastro repetido — o segundo toque que escapou, o reenvio depois de
    // uma queda de rede: o perfil já existe, e é isso que a pessoa queria.
    if (cadastro && erro.codigo == 'PACIENTE_JA_CADASTRADO') {
      try {
        final perfil = await _pacientes.meu();
        if (perfil != null) return perfil;
      } on ErroDaApi catch (outro) {
        _erroGeral = outro.mensagem;
        return null;
      }
    }
    if (erro.acao == AcaoSugerida.exibirTermo) {
      _termoMudou = true;
      _erroGeral = erro.mensagem;
      return null;
    }
    var semCampo = erro.problemas.isEmpty;
    for (final problema in erro.problemas) {
      final campo = CampoDoPaciente.values.where((c) => c.naApi == problema.campo).firstOrNull;
      if (campo == null) {
        semCampo = true;
      } else {
        _errosDosCampos[campo] = problema.mensagem;
      }
    }
    if (semCampo) _erroGeral = erro.mensagem;
    return null;
  }

  /// A pessoa mexeu no campo: o erro da API sobre ele deixa de valer.
  void campoMudou(CampoDoPaciente campo) {
    if (_errosDosCampos.remove(campo) != null) _notificar();
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    super.dispose();
  }
}
