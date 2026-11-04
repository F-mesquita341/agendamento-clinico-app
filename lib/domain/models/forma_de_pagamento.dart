/// Como o profissional aceita receber: pelo aplicativo (o pagamento
/// antecipado da v1), pelo plano de saúde ou na clínica, no dia.
enum FormaDePagamento {
  app,
  plano,
  clinica;

  /// A forma com o nome que a API usa, ou null para um nome que o aplicativo
  /// não conhece — uma forma nova da API não derruba a busca.
  static FormaDePagamento? daApi(String nome) {
    for (final forma in values) {
      if (forma.name == nome) return forma;
    }
    return null;
  }
}
