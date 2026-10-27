import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/ui/consultas/cancelamento.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/agenda.dart';
import '../../apoio/falsos.dart';

void main() {
  final dasDuas = horario(1, 14, 14);
  final confirmada = consultaNa(dasDuas);
  final cancelada = consultaNa(dasDuas, status: StatusDaConsulta.cancelada, motivo: MotivoDoCancelamento.paciente);
  // A resposta do PATCH, como a API a escreve: sem o horário nem o profissional.
  const respostaDoCancelamento = Consulta(
    id: 50,
    status: StatusDaConsulta.cancelada,
    motivoDoCancelamento: MotivoDoCancelamento.paciente,
    horarioId: 1,
    valorFormatado: 'R\$ 250,00',
  );

  const jaCancelada = ErroDaApi(status: 422, codigo: 'CONSULTA_JA_CANCELADA', mensagem: 'Esta consulta já foi cancelada.');
  const naoCancelavel = ErroDaApi(
    status: 422,
    codigo: 'CONSULTA_NAO_CANCELAVEL',
    mensagem: 'Consultas já realizadas não podem ser canceladas.',
  );

  test('cancelada pelo pedido: a consulta da resposta, sem reler', () async {
    final consultas = ConsultasFalso(cancelar: [respostaDoCancelamento]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(consultas.pedidosDeCancelar, [50]);
    expect(consultas.pedidosDeConsulta, isEmpty);
    expect(desfecho, isA<ConsultaCancelada>().having((d) => d.consulta, 'consulta', respostaDoCancelamento));
  });

  test('"já foi cancelada" — dois toques, outro aparelho: relida, está cancelada, e é isso que vale', () async {
    final consultas = ConsultasFalso(cancelar: [jaCancelada], consulta: [cancelada]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(consultas.pedidosDeConsulta, [50]);
    expect(desfecho, isA<ConsultaCancelada>().having((d) => d.consulta, 'consulta', cancelada));
  });

  test('uma recusa sem ação: relida, não está cancelada, e fica a mensagem da API com a consulta relida', () async {
    final consultas = ConsultasFalso(cancelar: [naoCancelavel], consulta: [confirmada]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(
      desfecho,
      isA<CancelamentoRecusado>()
          .having((d) => d.mensagem, 'mensagem', 'Consultas já realizadas não podem ser canceladas.')
          .having((d) => d.lida, 'lida', confirmada),
    );
  });

  test('a resposta se perdeu depois de a API cancelar: relida, está cancelada', () async {
    final consultas = ConsultasFalso(cancelar: [const ErroDaApi.semConexao()], consulta: [cancelada]);

    expect(await cancelarConsulta(consultas, 50), isA<ConsultaCancelada>());
  });

  test('sem conexão também para reler: fica a mensagem de sem conexão, sem consulta', () async {
    final consultas = ConsultasFalso(
      cancelar: [const ErroDaApi.semConexao()],
      consulta: [const ErroDaApi.semConexao()],
    );

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(
      desfecho,
      isA<CancelamentoRecusado>()
          .having((d) => d.mensagem, 'mensagem', const ErroDaApi.semConexao().mensagem)
          .having((d) => d.lida, 'lida', isNull),
    );
  });

  test('muitas tentativas (429): relida, continua confirmada, e fica a mensagem da API — não conta como cancelada',
      () async {
    const muitas = ErroDaApi(
      status: 429,
      codigo: 'MUITAS_REQUISICOES',
      mensagem: 'Muitas tentativas seguidas. Aguarde um pouco e tente de novo.',
      acao: AcaoSugerida.tentarNovamente,
    );
    final consultas = ConsultasFalso(cancelar: [muitas], consulta: [confirmada]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(desfecho, isA<CancelamentoRecusado>().having((d) => d.mensagem, 'mensagem', muitas.mensagem));
  });

  test('um 200 que não diz "cancelada" não é tomado por cancelamento: quem decide é a releitura', () async {
    final consultas = ConsultasFalso(cancelar: [confirmada], consulta: [confirmada]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(consultas.pedidosDeConsulta, [50]);
    expect(desfecho, isA<CancelamentoRecusado>());
  });

  test('sessão perdida: não relê — o portão da sessão cuida', () async {
    const semSessao = ErroDaApi(
      status: 401,
      codigo: 'NAO_AUTENTICADO',
      mensagem: 'Sua sessão terminou. Entre de novo.',
      acao: AcaoSugerida.autenticar,
    );
    final consultas = ConsultasFalso(cancelar: [semSessao]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(consultas.pedidosDeConsulta, isEmpty);
    expect(desfecho, isA<CancelamentoRecusado>().having((d) => d.mensagem, 'mensagem', semSessao.mensagem));
  });

  test('defeito do aplicativo: é relatado, e a releitura decide', () async {
    final relatados = <FlutterErrorDetails>[];
    final original = FlutterError.onError;
    FlutterError.onError = relatados.add;
    addTearDown(() => FlutterError.onError = original);
    final consultas = ConsultasFalso(cancelar: [StateError('defeito')], consulta: [confirmada]);

    final desfecho = await cancelarConsulta(consultas, 50);

    expect(relatados.single.exception, isA<StateError>());
    expect(
      desfecho,
      isA<CancelamentoRecusado>()
          .having((d) => d.mensagem, 'mensagem', const ErroDaApi.falhaNoAplicativo().mensagem),
    );
  });
}
