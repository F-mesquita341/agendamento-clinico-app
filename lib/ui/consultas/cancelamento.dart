import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/consulta.dart';
import '../../domain/models/erro_da_api.dart';
import '../comum/defeitos.dart';

/// Como terminou um pedido de cancelamento.
sealed class DesfechoDoCancelamento {
  const DesfechoDoCancelamento();
}

/// A consulta está cancelada: pelo pedido, ou porque já estava — dois toques,
/// outro aparelho, uma resposta que se perdeu depois de a API cancelar.
final class ConsultaCancelada extends DesfechoDoCancelamento {
  const ConsultaCancelada(this.consulta);

  /// Como a API a tem agora. O motivo diz se foi a pessoa que cancelou ou se a
  /// reserva já tinha expirado.
  final Consulta consulta;
}

/// A consulta não foi cancelada: a mensagem que explica, e a consulta relida,
/// quando deu para reler.
final class CancelamentoRecusado extends DesfechoDoCancelamento {
  const CancelamentoRecusado(this.mensagem, this.lida);

  final String mensagem;
  final Consulta? lida;
}

/// Pede o cancelamento e diz como terminou. Nunca lança.
///
/// A decisão é pelo status, e não pelo código do erro (checklist, item 1.5):
/// as recusas do cancelamento vêm sem ação, e uma resposta perdida não diz se
/// a API cancelou. Por isso, todo erro — menos os da sessão, de que o portão
/// da sessão cuida — faz reler a consulta: cancelada, ficou cancelada; senão,
/// fica a mensagem da API. Um código novo de recusa não muda nada aqui.
Future<DesfechoDoCancelamento> cancelarConsulta(RepositorioDeConsultas consultas, int id) async {
  ErroDaApi erro;
  try {
    final consulta = await consultas.cancelar(id);
    if (consulta.status == StatusDaConsulta.cancelada) return ConsultaCancelada(consulta);
    // Um 200 que não diz "cancelada" não é o que a API promete: quem decide é
    // a releitura.
    erro = const ErroDaApi.respostaInesperada(200);
  } on ErroDaApi catch (recusa) {
    if (recusa.acao case AcaoSugerida.autenticar || AcaoSugerida.renovarToken) {
      return CancelamentoRecusado(recusa.mensagem, null);
    }
    erro = recusa;
  } catch (defeito, pilha) {
    relatarDefeito(defeito, pilha, 'ao cancelar a consulta');
    erro = const ErroDaApi.falhaNoAplicativo();
  }

  try {
    final lida = await consultas.consulta(id);
    if (lida.status == StatusDaConsulta.cancelada) return ConsultaCancelada(lida);
    return CancelamentoRecusado(erro.mensagem, lida);
  } on ErroDaApi {
    return CancelamentoRecusado(erro.mensagem, null);
  } catch (defeito, pilha) {
    relatarDefeito(defeito, pilha, 'ao reler a consulta depois de cancelar');
    return CancelamentoRecusado(erro.mensagem, null);
  }
}
