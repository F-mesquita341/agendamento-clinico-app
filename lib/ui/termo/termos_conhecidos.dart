/// Os textos do termo de consentimento que este aplicativo tem, por versão.
///
/// A API diz qual versão está vigente (`GET /consentimento/termo-vigente`);
/// o texto mora aqui. O aceite enviado no cadastro é sempre o da versão cujo
/// texto foi mostrado — e, se a vigente não estiver neste mapa, o aplicativo
/// pede para ser atualizado em vez de mostrar um texto e aceitar outro.
///
/// Ao acrescentar uma versão: copie o texto do `docs/termo-de-consentimento.md`
/// da API sem o aviso de rascunho, escreva o resumo, e atualize o teste que
/// fixa o conteúdo de cada arquivo (test/ui/termo_test.dart). Nunca edite o
/// texto de uma versão que já existe: quem a aceitou aceitou aquele texto.
const termosConhecidos = <String, ({String termo, String resumo})>{
  '2026-09-v2': (
    termo: 'assets/termos/termo-2026-09-v2.md',
    resumo: 'assets/termos/resumo-2026-09-v2.md',
  ),
};
