import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/erro_da_api.dart';

/// Fornece o token de sessão do Firebase.
///
/// `renovar: true` pede um token novo — é o que a API manda fazer quando
/// responde `renovar_token`. Devolve null quando não há sessão.
///
/// Falha ao obter o token não é tratada aqui: cabe à própria fonte (Etapa 12)
/// traduzi-la num `ErroDaApi`. O que ainda assim escapar cai na rede de
/// segurança das telas, que nunca ficam presas carregando.
typedef FonteDeToken = Future<String?> Function({bool renovar});

/// Único ponto de contato do aplicativo com a API.
///
/// Concentra o que toda chamada precisa e nenhuma tela deveria repetir: o
/// token no cabeçalho, a leitura do envelope de erro, a renovação da sessão
/// expirada e a tradução da falta de resposta num erro que a tela sabe mostrar.
class ApiClient {
  ApiClient({
    required http.Client cliente,
    required Uri base,
    FonteDeToken? token,
    this.prazo = const Duration(seconds: 90),
    void Function()? aoPerderSessao,
  })  : _cliente = cliente,
        _base = base,
        _token = token,
        _aoPerderSessao = aoPerderSessao;

  final http.Client _cliente;
  final Uri _base;
  final FonteDeToken? _token;

  /// Chamado quando um pedido autenticado termina em `autenticar` — a sessão
  /// não serve mais, venha isso da API ou da própria fonte de token. Num lugar
  /// só, para nenhuma tela precisar lembrar de levar o paciente de volta à
  /// tela de entrar. O erro continua subindo para quem fez o pedido.
  final void Function()? _aoPerderSessao;

  /// Prazo de cada pedido, do envio ao fim da resposta. Longo de propósito: o
  /// servidor gratuito hiberna depois de 15 minutos parado, e o primeiro
  /// pedido depois disso leva perto de um minuto. Quem espera é avisado pela
  /// tela, não por um erro.
  final Duration prazo;

  Future<Object?> get(String caminho, {Map<String, String>? consulta, bool autenticado = true}) =>
      _enviar('GET', caminho, consulta: consulta, autenticado: autenticado);

  Future<Object?> post(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('POST', caminho, corpo: corpo, autenticado: autenticado);

  Future<Object?> patch(String caminho, {Object? corpo, bool autenticado = true}) =>
      _enviar('PATCH', caminho, corpo: corpo, autenticado: autenticado);

  Future<Object?> delete(String caminho, {bool autenticado = true}) =>
      _enviar('DELETE', caminho, autenticado: autenticado);

  Future<Object?> _enviar(
    String metodo,
    String caminho, {
    Map<String, String>? consulta,
    Object? corpo,
    required bool autenticado,
    bool renovado = false,
  }) async {
    final endereco = _base.resolve(caminho).replace(
          queryParameters: (consulta == null || consulta.isEmpty) ? null : consulta,
        );
    final pedido = http.Request(metodo, endereco)..headers['Accept'] = 'application/json';

    if (autenticado) {
      final String? token;
      try {
        token = await _token?.call(renovar: renovado);
      } on ErroDaApi catch (erro) {
        _falhar(erro, autenticado: true);
      }
      if (token != null) pedido.headers['Authorization'] = 'Bearer $token';
    }
    if (corpo != null) {
      pedido.headers['Content-Type'] = 'application/json; charset=utf-8';
      pedido.body = jsonEncode(corpo);
    }

    final http.Response resposta;
    try {
      // Um prazo só, para o pedido inteiro. Um para os cabeçalhos e outro para
      // o corpo deixariam a espera chegar ao dobro.
      resposta = await _receber(pedido).timeout(prazo);
    } on Exception {
      // Toda falha de transporte é, para quem usa o aplicativo, a mesma coisa:
      // não deu para falar com o servidor. Não basta capturar ClientException:
      // o pacote http só converte falhas de socket e de HTTP, e uma de TLS —
      // relógio errado no aparelho, rede que intercepta o certificado —
      // escaparia como HandshakeException.
      throw const ErroDaApi.semConexao();
    }

    final status = resposta.statusCode;
    if (status >= 200 && status < 300) {
      if (resposta.bodyBytes.isEmpty) return null;
      try {
        return jsonDecode(utf8.decode(resposta.bodyBytes));
      } on FormatException {
        throw ErroDaApi.respostaInesperada(status);
      }
    }

    final erro = ErroDaApi.doEnvelope(
          status,
          _jsonOuNulo(resposta.bodyBytes),
          tenteDeNovoEm: _segundos(resposta.headers['retry-after']),
        ) ??
        ErroDaApi.respostaInesperada(status);

    // Sessão expirada: um token novo e uma única nova tentativa. Se o token
    // novo também for recusado, o erro sobe — repetir para sempre esconderia
    // uma conta desativada atrás de uma tela carregando.
    if (erro.acao == AcaoSugerida.renovarToken && autenticado && !renovado) {
      return _enviar(metodo, caminho, consulta: consulta, corpo: corpo, autenticado: true, renovado: true);
    }
    _falhar(erro, autenticado: autenticado);
  }

  Never _falhar(ErroDaApi erro, {required bool autenticado}) {
    if (autenticado && erro.acao == AcaoSugerida.autenticar) _aoPerderSessao?.call();
    throw erro;
  }

  Future<http.Response> _receber(http.BaseRequest pedido) async =>
      http.Response.fromStream(await _cliente.send(pedido));

  static Object? _jsonOuNulo(List<int> bytes) {
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  static Duration? _segundos(String? cabecalho) {
    final segundos = int.tryParse(cabecalho ?? '');
    return segundos == null ? null : Duration(seconds: segundos);
  }
}
