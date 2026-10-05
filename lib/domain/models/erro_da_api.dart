/// O que o aplicativo deve fazer diante de um erro.
///
/// Vem do campo `acao` do envelope de erro da API — um conjunto fechado de
/// seis valores. O aplicativo decide por aqui, nunca interpretando o texto da
/// mensagem, que é para a pessoa ler.
enum AcaoSugerida {
  autenticar,
  renovarToken,
  completarCadastro,
  recarregarHorarios,
  exibirTermo,
  tentarNovamente,

  /// A API não indicou ação: basta mostrar a mensagem.
  nenhuma;

  static AcaoSugerida daApi(Object? valor) => switch (valor) {
        'autenticar' => autenticar,
        'renovar_token' => renovarToken,
        'completar_cadastro' => completarCadastro,
        'recarregar_horarios' => recarregarHorarios,
        'exibir_termo' => exibirTermo,
        'tentar_novamente' => tentarNovamente,
        _ => nenhuma,
      };
}

/// Um campo recusado pela validação (`DADOS_INVALIDOS`).
class ProblemaDeCampo {
  const ProblemaDeCampo({required this.campo, required this.mensagem});

  final String campo;
  final String mensagem;
}

/// Erro devolvido pela API — ou a falta de resposta dela, ou, como rede de
/// segurança, uma falha dentro do próprio aplicativo (`falhaNoAplicativo`).
///
/// O envelope da API é sempre `{erro: {codigo, mensagem, acao, problemas?}}`.
/// A `mensagem` já vem escrita em português para o paciente, e é ela que a
/// tela mostra.
class ErroDaApi implements Exception {
  const ErroDaApi({
    required this.status,
    required this.codigo,
    required this.mensagem,
    this.acao = AcaoSugerida.nenhuma,
    this.problemas = const [],
    this.tenteDeNovoEm,
  });

  /// Monta o erro a partir do corpo de uma resposta de falha. Devolve null se
  /// o corpo não for o envelope da API — uma página de erro do provedor, por
  /// exemplo.
  static ErroDaApi? doEnvelope(int status, Object? corpo, {Duration? tenteDeNovoEm}) {
    if (corpo is! Map<String, Object?>) return null;
    final erro = corpo['erro'];
    if (erro is! Map<String, Object?>) return null;
    final codigo = erro['codigo'];
    final mensagem = erro['mensagem'];
    if (codigo is! String || mensagem is! String) return null;

    final problemas = <ProblemaDeCampo>[
      for (final p in (erro['problemas'] is List<Object?> ? erro['problemas']! as List<Object?> : const <Object?>[]))
        if (p is Map<String, Object?> && p['campo'] is String && p['mensagem'] is String)
          ProblemaDeCampo(campo: p['campo']! as String, mensagem: p['mensagem']! as String),
    ];

    return ErroDaApi(
      status: status,
      codigo: codigo,
      mensagem: mensagem,
      acao: AcaoSugerida.daApi(erro['acao']),
      problemas: problemas,
      tenteDeNovoEm: tenteDeNovoEm,
    );
  }

  /// Não houve resposta: sem internet, servidor fora do ar ou prazo esgotado.
  const ErroDaApi.semConexao()
      : status = 0,
        codigo = 'SEM_CONEXAO',
        mensagem = 'Não foi possível falar com o servidor. Confira a internet e tente de novo.',
        acao = AcaoSugerida.tentarNovamente,
        problemas = const [],
        tenteDeNovoEm = null;

  /// Houve resposta, mas fora do formato da API.
  const ErroDaApi.respostaInesperada(this.status)
      : codigo = 'RESPOSTA_INESPERADA',
        mensagem = 'O servidor respondeu de um jeito inesperado. Tente de novo em instantes.',
        acao = AcaoSugerida.tentarNovamente,
        problemas = const [],
        tenteDeNovoEm = null;

  /// Um defeito do próprio aplicativo, não um problema da API. Existe para a
  /// tela nunca ficar presa carregando: ela mostra esta mensagem e deixa
  /// tentar de novo, e o defeito em si é relatado à parte.
  const ErroDaApi.falhaNoAplicativo()
      : status = 0,
        codigo = 'FALHA_NO_APLICATIVO',
        mensagem = 'Algo deu errado no aplicativo. Tente de novo.',
        acao = AcaoSugerida.tentarNovamente,
        problemas = const [],
        tenteDeNovoEm = null;

  /// Código HTTP; 0 quando não houve resposta.
  final int status;
  final String codigo;
  final String mensagem;
  final AcaoSugerida acao;
  final List<ProblemaDeCampo> problemas;

  /// Quanto esperar antes de tentar de novo, quando a API diz (429).
  final Duration? tenteDeNovoEm;

  @override
  String toString() => 'ErroDaApi($status $codigo)';
}
