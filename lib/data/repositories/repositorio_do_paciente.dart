import '../../domain/models/dados_do_paciente.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/paciente.dart';
import '../services/api_client.dart';
import 'leitura_json.dart';

/// O perfil do paciente da conta autenticada. Não há id de paciente em lugar
/// nenhum: a API resolve o "eu" pelo token, e é isso que impede alcançar o
/// perfil de outra pessoa.
abstract interface class RepositorioDoPaciente {
  /// O perfil da conta, ou null se a conta ainda não tem cadastro — o caminho
  /// esperado logo depois de criar a conta.
  Future<Paciente?> meu();

  /// Cria o perfil, com o aceite da versão do termo que a pessoa leu.
  Future<Paciente> cadastrar(DadosDoPaciente dados, {required String versaoDoTermo});

  Future<Paciente> atualizar(DadosDoPaciente dados);
}

class RepositorioDoPacienteRemoto implements RepositorioDoPaciente {
  RepositorioDoPacienteRemoto(this._api);

  final ApiClient _api;

  @override
  Future<Paciente?> meu() async {
    try {
      return lerObjeto(await _api.get('/pacientes/me'), 'paciente', Paciente.fromJson);
    } on ErroDaApi catch (erro) {
      // Decidido pela ação, como sempre — não pelo 404, que a API também usa
      // para outras coisas.
      if (erro.acao == AcaoSugerida.completarCadastro) return null;
      rethrow;
    }
  }

  @override
  Future<Paciente> cadastrar(DadosDoPaciente dados, {required String versaoDoTermo}) async {
    final corpo = await _api.post('/pacientes', corpo: {
      ...dados.paraCadastro(),
      // O aceite é sempre verdadeiro aqui: sem ele, a tela do termo não deixa
      // chegar ao cadastro. A versão é a do texto que estava na tela.
      'consentimento': {'aceito': true, 'versao': versaoDoTermo},
    });
    return lerObjeto(corpo, 'paciente', Paciente.fromJson);
  }

  @override
  Future<Paciente> atualizar(DadosDoPaciente dados) async {
    final corpo = await _api.patch('/pacientes/me', corpo: dados.paraEdicao());
    return lerObjeto(corpo, 'paciente', Paciente.fromJson);
  }
}
