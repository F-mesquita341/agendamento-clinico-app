# Checklist de usabilidade: heurísticas de Nielsen

Guia para o desenvolvimento do aplicativo do paciente (MVP em Flutter), com um item para o protótipo do Figma de médico e administrador.

**Versão 2**, de 05/10/2026. Adapta a versão 1 (`Checklist_Heuristicas_Nielsen_FrontEnd_1.pdf`, guardada fora do repositório), escrita antes de conferir o contrato da API. A numeração dos itens é a mesma da versão 1, para os dois documentos poderem ser comparados. A seção [Mudanças em relação à versão 1](#mudanças-em-relação-à-versão-1) diz o que mudou e por quê.

---

## Como usar

1. **Ao terminar uma tela**, preencha a coluna "Situação" daquela tela na [Parte 2](#parte-2-checklist-por-tela). Para ver como implementar, volte ao número do item na Parte 1.
2. **Antes de fechar uma etapa**, releia os itens essenciais ligados a ela. Cada tela da Parte 2 indica a etapa em que é construída.
3. **Marque cada item** com um destes símbolos:
   - `✓` atende
   - `~` atende em parte
   - `✗` não atende
   - `NA` não se aplica

   Todo item essencial marcado com `✗` vira tarefa antes da avaliação com os especialistas. Ao marcar `~` ou `✗`, anote também a [severidade](#severidade).
4. **Uma vez por semana**, faça uma passada completa: uma tela nova pode quebrar um item que já estava resolvido.
5. **O "como fazer" é sugestão, não compromisso.** O app usa view models com `provider` (Etapa 11). Cada pacote citado só entra na etapa que precisar dele, pela regra de pacotes mínimos do plano.
6. **Itens `NA` continuam na lista, com a justificativa.** São as limitações do escopo declaradas, que a monografia precisa explicitar (pedido do prof. Bruno).

| Tipo | Significado |
|---|---|
| **Essencial** | Deve estar no MVP antes da avaliação heurística. Se faltar, tende a ser apontado como problema grave pelos avaliadores. |
| **Desejável** | Melhora a experiência e ajuda na nota do SUS. Implementar se houver tempo depois dos essenciais. |
| **NA** | Fora do escopo do trabalho, com o motivo registrado no item. |

### Severidade

Escala de Nielsen (1994), usada ao marcar `~` ou `✗` aqui e na ficha da avaliação com os especialistas:

| Nota | Significado |
|---|---|
| 0 | Não é problema de usabilidade |
| 1 | Cosmético: corrigir se sobrar tempo |
| 2 | Menor: prioridade baixa |
| 3 | Maior: prioridade alta |
| 4 | Catástrofe: corrigir antes de liberar |

### Resumo

| | Heurística | Essenciais | Desejáveis | NA |
|---|---|:-:|:-:|:-:|
| H1 | Visibilidade do status do sistema | 7 | 3 | – |
| H2 | Correspondência entre o sistema e o mundo real | 6 | 3 | – |
| H3 | Controle e liberdade do usuário | 7 | 2 | 1 |
| H4 | Consistência e padrões | 7 | 2 | – |
| H5 | Prevenção de erros | 7 | 3 | – |
| H6 | Reconhecimento em vez de memorização | 6 | 3 | – |
| H7 | Flexibilidade e eficiência de uso | 3 | 5 | 1 |
| H8 | Estética e design minimalista | 7 | 3 | – |
| H9 | Ajudar a reconhecer, diagnosticar e corrigir erros | 6 | 1 | 1 |
| H10 | Ajuda e documentação | 5 | 3 | – |
| | **Total** | **61** | **28** | **3** |

A versão 1 tinha 62 essenciais e 30 desejáveis. Os três itens que viraram `NA` são 3.5, 7.3 e 9.8.

### Dependências externas

Estes itens não fecham só com trabalho no app:

| Depende de | Itens | Situação |
|---|---|---|
| A API devolver `profissional.clinica` (`nome`, `telefone`, `endereco`) | 1.4, 2.9, 5.1, 6.2, 10.3 | Pedido à sessão da API em 05/10/2026 |
| Decisão sobre o estorno do pagamento antecipado no cancelamento | 3.4, 10.1, 10.2 | Pendente, antes da Etapa 16 |
| Texto final do termo, junto ao CEP | 10.4 | Pendente; o app mostra a versão que a API devolver |

---

## Parte 1: itens por heurística

### H1 · Visibilidade do status do sistema

**O que significa:** o app deve sempre informar o que está acontecendo, com retorno adequado e em tempo razoável. O paciente nunca pode ficar em dúvida se o toque funcionou, se a consulta foi marcada ou se o pagamento passou.

**Onde aparece no app:** carregamento de profissionais e horários, envio do agendamento, volta do checkout, status das consultas e conexão com a internet.

> **Limites de tempo de resposta (Nielsen, 1993)**
> - até 0,1 s: parece instantâneo, não precisa de indicador;
> - até 1 s: o usuário nota a espera, mas não perde o fluxo;
> - acima de 1 s: mostre indicador de carregamento;
> - acima de 10 s: mostre progresso e ofereça uma saída.
>
> Neste projeto, o servidor gratuito hiberna e pode levar até um minuto para acordar. Por isso existe o aviso de espera da Etapa 11.

#### 1.1 · Essencial · ajustado
Toda chamada à API mostra indicador de carregamento quando passa de cerca de 1 segundo, na tela ou dentro do botão que disparou a ação. Se a espera se alonga, aparece o aviso de servidor demorando, e voltar continua funcionando.
- **Como fazer:** estado de carga no view model, como na tela de especialidades da Etapa 11 (`carregando`, com o sinal `demorando`). Em listas, um esqueleto é opcional.
- **Onde conferir:** Termo, Busca de profissionais, Perfil do profissional, Escolha de dia e horário, Minhas consultas.
- **Ajuste:** o "como fazer" segue o padrão já construído, em vez de `FutureBuilder`, e o item cita o aviso de espera.

#### 1.2 · Essencial
Botões que disparam ação (Entrar, Criar conta, Confirmar, Pagar) mostram estado de processando e ficam desabilitados até a resposta chegar.
- **Como fazer:** `onPressed: enviando ? null : _enviar`, com um `CircularProgressIndicator` pequeno no lugar do texto do botão.
- **Onde conferir:** Entrar, Criar conta, Esqueci a senha, Completar cadastro, Resumo do agendamento, Pagamento.

#### 1.3 · Essencial
Toda ação concluída gera confirmação visível: "Consulta cancelada", "Dados salvos", "Enviamos o e-mail".
- **Como fazer:** `ScaffoldMessenger.of(context).showSnackBar(...)` para ações simples; tela própria para o agendamento confirmado.
- **Onde conferir:** Esqueci a senha, Status e confirmação, Minhas consultas, Detalhe da consulta.

#### 1.4 · Essencial · ajustado
A tela de consulta confirmada mostra profissional, especialidade, data, hora, endereço da clínica e o status da consulta.
- **Como fazer:** monte a tela a partir de `GET /consultas/:id`, e não dos dados locais, para refletir o que foi gravado. A resposta do `POST /consultas` não traz o profissional.
- **Onde conferir:** Status e confirmação.
- **Ajuste:** "status do pagamento" virou status da consulta (ver 1.5), e o endereço depende de a API devolver `profissional.clinica`.

#### 1.5 · Essencial · ajustado
O status mostrado é sempre o da consulta, lido da API. "Confirmada" só aparece quando a API diz `confirmada`, ou seja, depois que o webhook do Mercado Pago confirmou o pagamento.
- **Como fazer:** os rótulos são os da tabela do item 1.7. Ao voltar do checkout, consulte `GET /consultas/:id`. O retorno do checkout não confirma nada.
- **Onde conferir:** Pagamento, Status e confirmação, Minhas consultas.
- **Ajuste:** a versão 1 mapeava os status do Mercado Pago (`approved`, `pending`, `in_process`, `rejected`) e citava `back_url`. O app nunca recebe esses status: a API confirma pelo webhook e expõe só o status da consulta.

#### 1.6 · Essencial · ajustado
Na grade, horário disponível e horário selecionado são visualmente diferentes, e não só pela cor (use também ícone, borda ou texto). Dias sem horário aparecem desativados, com o texto "sem horários".
- **Como fazer:** `ChoiceChip` com `selected`; o selecionado leva um ícone de confirmação.
- **Onde conferir:** Escolha de dia e horário.
- **Ajuste:** a API devolve só horários disponíveis e futuros, então "ocupado" nunca aparece na grade. O caso de um horário que acabou de ser ocupado é o 9.1.

#### 1.7 · Essencial · ajustado
Cada consulta em Minhas consultas mostra um selo de status com texto e ícone:

| Na API | Selo |
|---|---|
| `pendente_pagamento` | Aguardando pagamento (com o prazo: "até 14:45") |
| `confirmada` | Confirmada |
| `cancelada`, motivo `paciente` ou ausente | Cancelada |
| `cancelada`, motivo `reserva_expirada` | Reserva expirada |
| `realizada` | Realizada |
| `nao_compareceu` | Não compareceu |

- **Como fazer:** `Chip` com cor do `ColorScheme`, ícone e texto. O motivo vem em `motivoCancelamento`.
- **Onde conferir:** Minhas consultas, Detalhe da consulta.
- **Ajuste:** a versão 1 tinha quatro selos (Agendada, Paga, Cancelada, Realizada), que não correspondem aos estados da API.

#### 1.8 · Desejável · ajustado
Sem internet, o app avisa de forma persistente e não deixa o paciente preencher tudo para só falhar no final.
- **Como fazer:** parta do erro `SEM_CONEXAO`, que o `ApiClient` já produz para toda falha de transporte. O pacote `connectivity_plus` só entra se o aviso antecipado valer o pacote.
- **Onde conferir:** Todas as telas.

#### 1.9 · Desejável
No fluxo de agendamento, o paciente vê em que etapa está (ex.: "Etapa 2 de 4").
- **Como fazer:** texto simples na `AppBar` ou `LinearProgressIndicator(value: etapa / total)`.
- **Onde conferir:** Escolha de dia e horário, Resumo do agendamento.

#### 1.10 · Desejável
Listas podem ser atualizadas puxando para baixo, com indicação de que estão atualizando.
- **Como fazer:** `RefreshIndicator` envolvendo a lista. Se a atualização falhar, a lista anterior continua na tela (padrão da Etapa 11).
- **Onde conferir:** Busca de profissionais, Escolha de dia e horário, Minhas consultas.

---

### H2 · Correspondência entre o sistema e o mundo real

**O que significa:** o app deve falar a língua do paciente, com palavras, conceitos e ordem que ele já conhece da vida real, e não termos do sistema ou do código.

**Onde aparece no app:** nomes de especialidades, termos do pagamento, formatos de data, hora e valor, e a ordem do fluxo de marcação.

#### 2.1 · Essencial
Nenhum termo técnico aparece para o paciente: slot, token, sandbox, ID, status code, null, exception, payload.
- **Como fazer:** revise todos os textos visíveis e as mensagens de erro. Nunca exiba `e.toString()` na tela. As mensagens da API já vêm escritas para o paciente; o app mostra a `mensagem` do envelope.
- **Onde conferir:** Todas as telas.

#### 2.2 · Essencial · ajustado
Existe um glossário único, e só ele é usado:

| Use | Não use para a mesma coisa |
|---|---|
| consulta | atendimento, agendamento |
| horário | slot, vaga |
| especialidade | área |
| profissional | médico (quando não for), doutor |
| reserva (o horário guardado enquanto o pagamento não se confirma) | bloqueio, pré-agendamento |
| pagamento antecipado | caução, sinal |

- **Como fazer:** centralize os textos num arquivo do app (ex.: `lib/ui/comum/textos.dart`). Arquivos ARB não são necessários com um idioma só.
- **Onde conferir:** Todas as telas.
- **Ajuste:** entrou "reserva", que o paciente vê durante os 15 minutos do prazo de pagamento.

#### 2.3 · Essencial
A palavra "caução" não aparece na interface. Use "pagamento antecipado" e explique o motivo em uma frase.
- **Como fazer:** ex.: "O pagamento antecipado garante o seu horário." A frase sobre cancelamento depende da decisão do estorno (ver 10.1). Nenhuma mensagem da API usa "caução", e o item do checkout se chama "Consulta médica".
- **Onde conferir:** Resumo do agendamento, Pagamento.

#### 2.4 · Essencial · ajustado
- Datas com o dia da semana por extenso e dia/mês, e hora em 24 h: "quinta-feira, 12/11 · 14:30". O ano aparece só quando não for o ano corrente.
- Data de nascimento em dd/mm/aaaa.
- Valores sempre como a API manda: "R$ 150,00".
- **Como fazer:**
  - **Datas:** `DateFormat('EEEE, dd/MM', 'pt_BR')` e `DateFormat.Hm('pt_BR')`, com `initializeDateFormatting('pt_BR')` no `main()`. Instantes da API passam só pelo conversor único (`lib/domain/models/instante.dart`).
  - **Valores:** venha sempre do `valorFormatado` da API, nunca de `NumberFormat` no app (decisão da Etapa 11).
- **Onde conferir:** Escolha de dia e horário, Resumo do agendamento, Minhas consultas, Detalhe da consulta, Completar cadastro.
- **Ajuste:** a versão 1 pedia dd/mm/aaaa, mas o exemplo e o código não tinham ano. Os valores passaram a vir da API. O texto da notificação é montado pela API (ver 6.5).

#### 2.5 · Essencial
O app inteiro está em português do Brasil, inclusive os componentes nativos: calendário, seletor de data e botões dos diálogos.
- **Como fazer:** já configurado na Etapa 11: `flutter_localizations`, `locale: Locale('pt', 'BR')` e `GlobalMaterialLocalizations.delegates`.
- **Onde conferir:** Todas as telas.

#### 2.6 · Essencial
A ordem do fluxo segue a lógica de quem marca consulta: especialidade → profissional → dia → horário → resumo → pagamento.
- **Como fazer:** desenhe o fluxo de rotas antes de codar e confira que nenhuma tela pede algo fora dessa ordem.
- **Onde conferir:** Busca de profissionais, Perfil do profissional, Escolha de dia e horário, Resumo do agendamento, Pagamento.

#### 2.7 · Desejável · ajustado
Especialidades aparecem com o nome que o paciente usa, com apoio quando o termo for técnico (ex.: "Cardiologia · coração").
- **Como fazer:** um mapa de apoio no próprio app, com o nome da API como chave. A API não muda.
- **Onde conferir:** Busca de profissionais.
- **Ajuste:** a versão 1 pedia um campo novo no back-end. A API está com o contrato fechado, e um item desejável não justifica reabri-lo.

#### 2.8 · Desejável
Ícones têm significado reconhecível (casa, lupa, calendário, sino) e, na navegação, sempre vêm com texto.
- **Como fazer:** `NavigationDestination(icon: ..., label: 'Minhas consultas')`.
- **Onde conferir:** Todas as telas.

#### 2.9 · Desejável · ajustado
Endereço da clínica com a opção "Abrir no mapa" e telefone com toque para ligar.
- **Como fazer:** pacote `url_launcher`, com links `geo:` (ou Google Maps) e `tel:`. Esconda o botão quando o dado vier `null`.
- **Onde conferir:** Perfil do profissional, Detalhe da consulta.
- **Ajuste:** depende de a API devolver `profissional.clinica`.

---

### H3 · Controle e liberdade do usuário

**O que significa:** o paciente erra e muda de ideia. Ele precisa de "saídas de emergência" claras para voltar, desfazer ou desistir sem prejuízo.

**Onde aparece no app:** voltar no fluxo de agendamento, desistir do pagamento, cancelar a consulta, recuperar a senha e o botão voltar do Android.

#### 3.1 · Essencial
Voltar no fluxo de agendamento mantém as escolhas já feitas (especialidade, profissional, dia).
- **Como fazer:** guarde a seleção num view model do fluxo, fornecido acima das telas do agendamento, e não no `State` de cada tela.
- **Onde conferir:** Escolha de dia e horário, Resumo do agendamento.

#### 3.2 · Essencial · ajustado
O paciente pode fechar o checkout e voltar ao app sem perder o horário dentro do prazo:
- o app mostra até quando o horário fica reservado;
- dentro desse prazo, o paciente pode abrir o pagamento de novo;
- depois dele, o app explica que a reserva expirou e leva de volta à grade.
- **Como fazer:** o checkout abre numa Custom Tab. Ao voltar, o app consulta `GET /consultas/:id`. O prazo é o `reservaExpiraEm` (15 minutos). Pedir `POST /consultas/:id/pagamento` de novo devolve o mesmo checkout enquanto ele estiver aberto, e a API já expira as reservas vencidas.
- **Onde conferir:** Pagamento.
- **Ajuste:** a versão 1 falava em `back_urls`, que a API não configura. A volta é pelo fechamento da Custom Tab.

#### 3.3 · Essencial
Depois do pagamento confirmado, o botão voltar não leva de novo ao checkout nem duplica o agendamento.
- **Como fazer:** vá para a tela de confirmação substituindo a pilha, com `Navigator.pushAndRemoveUntil` ou o equivalente do roteador escolhido.
- **Onde conferir:** Status e confirmação.

#### 3.4 · Essencial · ajustado
O paciente consegue cancelar a consulta pelo app, vendo o que acontece com o pagamento antes de confirmar.
- **Como fazer:** mostre a regra no próprio diálogo de confirmação. A API aceita cancelar consulta aguardando pagamento ou confirmada, sem prazo mínimo.
- **Onde conferir:** Detalhe da consulta.
- **Ajuste:** o texto sobre reembolso depende da decisão do estorno, que é pendente e precisa sair antes da Etapa 16.

#### 3.5 · NA · ajustado
~~Remarcar está disponível sem precisar cancelar e marcar de novo.~~
- **Por que NA:** a API não tem operação de remarcar, e o contrato está fechado. O caminho é cancelar e marcar de novo, encurtado pelo 7.6 ("Agendar de novo"). Registrar como limitação do escopo.
- **Ajuste:** era desejável.

#### 3.6 · Essencial
Todo formulário, diálogo e bottom sheet tem saída clara (Cancelar, X ou toque fora). Sair de um formulário preenchido pede confirmação.
- **Como fazer:** `PopScope(canPop: false, onPopInvokedWithResult: ...)` para perguntar "Descartar alterações?".
- **Onde conferir:** Criar conta, Completar cadastro, Ajuda e perfil do usuário.

#### 3.7 · Desejável
Ações leves e reversíveis oferecem "Desfazer" em vez de um diálogo de confirmação (ex.: remover favorito, limpar filtro).
- **Como fazer:** `SnackBar(action: SnackBarAction(label: 'Desfazer', onPressed: ...))`.
- **Onde conferir:** Busca de profissionais.

#### 3.8 · Essencial
O botão e o gesto de voltar do Android se comportam como o paciente espera em todas as telas, e nunca fecham o app no meio de um fluxo sem aviso.
- **Como fazer:** teste o voltar físico em cada rota. Na tela inicial, voltar pode sair do app; nas demais, deve voltar uma etapa.
- **Onde conferir:** Todas as telas.

#### 3.9 · Desejável
Filtros aplicados podem ser removidos de uma vez com "Limpar filtros".
- **Como fazer:** botão de texto visível sempre que houver ao menos um filtro ativo.
- **Onde conferir:** Busca de profissionais.

#### 3.10 · Essencial
A tela de entrar tem "Esqueci minha senha" visível.
- **Como fazer:** `FirebaseAuth.instance.sendPasswordResetEmail(email: ...)`, com uma mensagem que pede para conferir a caixa de entrada e o spam. A mensagem é a mesma exista ou não a conta, para não revelar quais e-mails estão cadastrados.
- **Onde conferir:** Entrar, Esqueci a senha.

---

### H4 · Consistência e padrões

**O que significa:** a mesma coisa deve ter a mesma aparência, o mesmo nome e o mesmo comportamento em todo o app, seguindo as convenções do Android que o paciente já conhece.

**Onde aparece no app:** tema, botões, cards, navegação, mensagens e a coerência entre o MVP em Flutter e o protótipo do Figma.

#### 4.1 · Essencial
Cores, fontes e formas são definidas uma única vez no tema; nenhum widget usa cor "solta".
- **Como fazer:** o tema da Etapa 11 (`lib/config/tema.dart`, `ColorScheme.fromSeed`), com o contraste de cada par conferido por teste. Nos widgets, use `Theme.of(context).colorScheme` e `.textTheme`.
- **Onde conferir:** Todas as telas.

#### 4.2 · Essencial
Existe um único componente para botão principal, um para secundário e um para ação destrutiva. A ação principal fica sempre no mesmo lugar (embaixo, largura total).
- **Como fazer:** widgets próprios (ex.: `BotaoPrincipal`) construídos sobre `FilledButton`, `OutlinedButton` e `TextButton`.
- **Onde conferir:** Todas as telas.

#### 4.3 · Essencial
Um único card de profissional, reutilizado na busca, no perfil e em Minhas consultas.
- **Como fazer:** um widget de card de profissional com parâmetros opcionais, em vez de três versões parecidas.
- **Onde conferir:** Busca de profissionais, Perfil do profissional, Minhas consultas.

#### 4.4 · Essencial
Navegação principal com barra inferior fixa (ex.: Início, Buscar, Minhas consultas, Perfil), sempre com os mesmos itens e na mesma ordem.
- **Como fazer:** `NavigationBar` (Material 3), preservando o estado de cada aba (`IndexedStack`, ou `StatefulShellRoute` se o `go_router` for adotado).
- **Onde conferir:** Todas as telas.

#### 4.5 · Essencial
Espaçamentos seguem uma escala fixa (ex.: 4, 8, 16, 24, 32).
- **Como fazer:** constantes centralizadas em vez de números soltos.
- **Onde conferir:** Todas as telas.

#### 4.6 · Essencial
Cada tipo de retorno tem um padrão único: sucesso, aviso e erro sempre com a mesma cor, ícone e componente.
- **Como fazer:** uma função utilitária usada no app todo.
- **Onde conferir:** Todas as telas.

#### 4.7 · Essencial
Convenções do Android respeitadas: `AppBar` com título e voltar à esquerda, diálogos com a ação de confirmação à direita, teclado com "Próximo" entre campos.
- **Como fazer:** `AlertDialog(actions: [Cancelar, Confirmar])`; `textInputAction: TextInputAction.next` nos campos.
- **Onde conferir:** Todas as telas.

#### 4.8 · Desejável
O protótipo do Figma (médico e administrador) usa as mesmas cores, fontes e componentes do MVP.
- **Como fazer:** crie no Figma *Variables* e *Components* com os mesmos valores do tema Flutter.
- **Onde conferir:** Protótipo Figma.

#### 4.9 · Desejável
Todos os ícones vêm da mesma família e do mesmo estilo (preenchido ou contorno).
- **Como fazer:** use só `Icons.*` (Material), sem misturar pacotes.
- **Onde conferir:** Todas as telas.

---

### H5 · Prevenção de erros

**O que significa:** melhor que uma boa mensagem de erro é impedir que o erro aconteça. Isso significa eliminar as situações que levam a ele ou pedir confirmação antes de ações sérias.

**Onde aparece no app:** cadastro, escolha de horário, confirmação, pagamento e cancelamento.

#### 5.1 · Essencial · ajustado
Antes de confirmar, uma tela de resumo mostra profissional, especialidade, data, hora, endereço da clínica e valor, além do aviso de que o horário fica reservado por 15 minutos para o pagamento. O botão diz exatamente o que vai acontecer (ex.: "Confirmar e ir para o pagamento").
- **Como fazer:** tela própria de resumo.
- **Onde conferir:** Resumo do agendamento.
- **Ajuste:** entrou o aviso da reserva. O endereço depende de a API devolver `profissional.clinica`.

#### 5.2 · Essencial · ajustado
Horários ocupados ou passados não podem ser selecionados, e dias sem vaga aparecem desabilitados.
- **Como fazer:** a API já devolve só horários disponíveis e futuros. No app, os dias sem horário ficam desativados no seletor de dias (ver 1.6).
- **Onde conferir:** Escolha de dia e horário.
- **Ajuste:** a API garante a parte dos ocupados e passados, e sobra para o app a parte dos dias.

#### 5.3 · Essencial · ajustado
Botões de envio são bloqueados após o primeiro toque, evitando agendamento ou cobrança em dobro.
- **Como fazer:** flag de envio no view model (ver 1.2). No back-end, isso já está resolvido: o checkout é criado com `X-Idempotency-Key`, e pedir de novo devolve o mesmo checkout.
- **Onde conferir:** Resumo do agendamento, Pagamento.

#### 5.4 · Essencial · ajustado
Campos com máscara e validação enquanto o paciente digita: telefone e data de nascimento.
- **Como fazer:**
  - `TextFormField` + `validator` + `autovalidateMode: AutovalidateMode.onUserInteraction`, com as mesmas regras da API:
    - nome com ao menos 2 letras;
    - telefone com DDD, 10 ou 11 dígitos;
    - data de nascimento válida e não futura.
  - As máscaras podem vir de um formatter próprio ou de pacote (`brasil_fields`, `mask_text_input_formatter`), decidido na Etapa 12.
- **Onde conferir:** Completar cadastro.
- **Ajuste:**
  - **Sem CPF:** a API não coleta CPF, por minimização de dados (LGPD, art. 6º, III).
  - **E-mail:** vem da conta criada no Firebase, então não é campo do cadastro.

#### 5.5 · Essencial
Cada campo abre o teclado certo e aceita preenchimento automático.
- **Como fazer:**
  - `keyboardType`: `TextInputType.emailAddress`, `.phone` e `.datetime`.
  - `autofillHints`: `AutofillHints.email`, `.password`, `.newPassword`, `.name` e `.telephoneNumber`, dentro de um `AutofillGroup`.
- **Onde conferir:** Entrar, Criar conta, Esqueci a senha, Completar cadastro.

#### 5.6 · Essencial
As regras de senha aparecem antes do erro (ex.: "mínimo de 6 caracteres"), e existe a opção de mostrar ou ocultar a senha.
- **Como fazer:** `helperText` com a regra; `suffixIcon` alternando `obscureText`. O Firebase Auth exige no mínimo 6 caracteres por padrão.
- **Onde conferir:** Entrar, Criar conta.

#### 5.7 · Essencial · ajustado
Ações destrutivas (cancelar consulta, sair da conta) pedem confirmação, com o nome da ação no botão ("Cancelar consulta", nunca só "OK").
- **Como fazer:** `showDialog` com `AlertDialog`; botão destrutivo com `colorScheme.error`.
- **Onde conferir:** Detalhe da consulta, Ajuda e perfil do usuário.
- **Ajuste:** "excluir conta" saiu da lista, porque a API não tem essa operação.

#### 5.8 · Desejável · ajustado
O app avisa quando o paciente tenta marcar duas consultas no mesmo horário.
- **Como fazer:** a API já recusa, com `CONSULTA_SOBREPOSTA` e restrição no banco (migration 007). O app mostra a `mensagem` do erro.
- **Onde conferir:** Resumo do agendamento.

#### 5.9 · Desejável
Campos obrigatórios são indicados antes do envio, e o botão principal mostra o que falta quando o formulário ainda não está completo.
- **Como fazer:** marque os opcionais como "(opcional)" em vez de pôr asterisco em todos os obrigatórios. Na API, telefone e data de nascimento são opcionais.
- **Onde conferir:** Completar cadastro.

#### 5.10 · Desejável
O valor da consulta aparece antes da escolha do horário, para não haver surpresa no pagamento.
- **Como fazer:** `valorFormatado` no card e no perfil do profissional. A API já devolve esse campo na busca.
- **Onde conferir:** Busca de profissionais, Perfil do profissional.

---

### H6 · Reconhecimento em vez de memorização

**O que significa:** o paciente não deve precisar lembrar informações de uma tela para usar em outra. Opções, ações e dados importantes ficam visíveis ou fáceis de recuperar.

**Onde aparece no app:** resumo durante o agendamento, próxima consulta na tela inicial, busca de especialidades e lembretes.

#### 6.1 · Essencial
Durante o agendamento, um resumo fixo mostra o que já foi escolhido (profissional, data) enquanto o paciente escolhe o resto.
- **Como fazer:** card fixo no topo da tela de horários ou resumo na parte de baixo do `Scaffold`.
- **Onde conferir:** Escolha de dia e horário, Resumo do agendamento.

#### 6.2 · Essencial · ajustado
A tela inicial mostra a próxima consulta em destaque (data, hora, profissional, endereço da clínica), com acesso direto aos detalhes.
- **Como fazer:** card no topo do Início, a partir de `GET /consultas`. Se não houver consulta, estado vazio com "Agendar consulta".
- **Onde conferir:** Início.
- **Ajuste:** o endereço depende de a API devolver `profissional.clinica`.

#### 6.3 · Essencial
Especialidades aparecem em lista, chips ou grade, sem exigir que o paciente digite o nome exato.
- **Como fazer:** `Wrap` de `ChoiceChip`/`FilterChip` ou lista, a partir de `GET /especialidades`.
- **Onde conferir:** Busca de profissionais.

#### 6.4 · Essencial · ajustado
A busca encontra resultados mesmo sem acento e com termos parciais, e sugere enquanto o paciente digita.
- **Como fazer:**
  - **Especialidades:** filtre no app a lista de `GET /especialidades`, normalizando minúsculas e acentos. Assim "cardio" acha "Cardiologia".
  - **Profissionais:** use o parâmetro `q` da API, que já ignora acento ("fatima" acha "Fátima") e exige ao menos 2 letras.
  - Aplique um debounce de cerca de 300 ms.
- **Onde conferir:** Busca de profissionais.
- **Ajuste:** o `q` da API busca no nome do profissional, não no nome da especialidade, por isso as duas buscas foram separadas.

#### 6.5 · Essencial · ajustado
O lembrete diz quando é a consulta, e o toque nele abre os detalhes (7.2).
- **Como fazer:** nada a fazer no app além do 7.2. O texto é montado pela API (`src/domain/Lembrete.js`): título "Lembrete de consulta" e corpo como "Você tem uma consulta amanhã às 14:30.".
- **Onde conferir:** Notificação.
- **Ajuste:** a versão 1 pedia profissional, especialidade e endereço no texto. A notificação aparece com a tela bloqueada, e especialidade é dado de saúde (LGPD, art. 11). A API omite esses dados de propósito, e o detalhe da consulta mostra o resto.

#### 6.6 · Essencial
Na tela de pagamento, o resumo da consulta e o valor continuam visíveis.
- **Como fazer:** repita o card de resumo acima do botão que abre o checkout.
- **Onde conferir:** Pagamento.

#### 6.7 · Desejável
Buscas e profissionais recentes aparecem para reutilizar.
- **Como fazer:** histórico local com `shared_preferences` (poucos itens), só no aparelho e com opção de limpar.
- **Onde conferir:** Busca de profissionais.

#### 6.8 · Desejável
O rótulo do campo continua visível depois que o paciente começa a digitar; o placeholder não substitui o rótulo.
- **Como fazer:** `InputDecoration(labelText: ...)` (rótulo flutuante), e não apenas `hintText`.
- **Onde conferir:** Entrar, Criar conta, Completar cadastro.

#### 6.9 · Desejável
Ícones sem texto têm dica e rótulo para leitor de tela.
- **Como fazer:** `IconButton(tooltip: 'Filtrar')`; `Semantics(label: ...)` em imagens e ícones informativos.
- **Onde conferir:** Todas as telas.

---

### H7 · Flexibilidade e eficiência de uso

**O que significa:** atalhos que aceleram quem já conhece o app, sem atrapalhar quem está começando. O caminho básico precisa funcionar sem os atalhos.

**Onde aparece no app:** sessão salva, lembrete que abre a consulta, filtros e "agendar de novo".

#### 7.1 · Essencial
O login fica salvo entre as aberturas do app; o paciente não precisa entrar toda vez.
- **Como fazer:** decida a rota inicial ouvindo `FirebaseAuth.instance.authStateChanges()`. No Android, a sessão já é persistida pelo Firebase.
- **Onde conferir:** Abertura, Entrar.

#### 7.2 · Essencial
Tocar no lembrete abre direto os detalhes daquela consulta.
- **Como fazer:** `FirebaseMessaging.onMessageOpenedApp` (app em segundo plano) e `FirebaseMessaging.instance.getInitialMessage()` (app fechado), lendo `consultaId` em `message.data`. A API já envia `consultaId` e `tipo: 'lembrete'`.
- **Onde conferir:** Notificação, Detalhe da consulta.

#### 7.3 · NA · ajustado
~~Dados já cadastrados (nome, CPF, e-mail) vão automaticamente para o pagamento, sem redigitar.~~
- **Por que NA:** a API não coleta CPF (ver 5.4) e não envia dados do pagador ao Mercado Pago, que recebe só descrição genérica, valor e referência aleatória. No sandbox, quem paga é a conta compradora de teste, preparada antes da sessão.
- **Ajuste:** era essencial.

#### 7.4 · Essencial
Conte quantos toques e telas existem entre o Início e o pagamento, e elimine etapas que não pedem decisão do paciente.
- **Como fazer:** registre essa contagem; ela vira um dado concreto para o capítulo de resultados do TCC.
- **Onde conferir:** Todas as telas.

#### 7.5 · Desejável · ajustado
Filtros opcionais na busca (especialidade, turno manhã ou tarde); quem não quiser usar consegue agendar sem eles.
- **Como fazer:** a especialidade vai como filtro da API. O turno é filtrado no app, sobre a grade já carregada. Use `FilterChip` na tela ou um `showModalBottomSheet`.
- **Onde conferir:** Busca de profissionais, Escolha de dia e horário.
- **Ajuste:** a API filtra só por especialidade e nome.

#### 7.6 · Desejável
Atalho "Agendar de novo" com o mesmo profissional a partir de uma consulta anterior.
- **Como fazer:** botão no detalhe da consulta que abre a grade daquele profissional.
- **Onde conferir:** Minhas consultas, Detalhe da consulta.

#### 7.7 · Desejável
Opção "Adicionar à agenda do celular" depois de confirmar.
- **Como fazer:** pacote `add_2_calendar`, por iniciativa do paciente.
- **Onde conferir:** Status e confirmação, Detalhe da consulta.

#### 7.8 · Desejável
Entrada por biometria como alternativa à senha, depois do primeiro login.
- **Como fazer:** pacote `local_auth`.
- **Onde conferir:** Entrar.

#### 7.9 · Desejável
Profissionais favoritos para acesso rápido.
- **Como fazer:** ícone de favorito no card e seção "Favoritos" no Início ou na busca, guardada no aparelho.
- **Onde conferir:** Busca de profissionais, Início.

---

### H8 · Estética e design minimalista

**O que significa:** cada informação extra compete com a informação importante. Cada tela mostra só o que o paciente precisa para a tarefa daquele momento, com boa legibilidade para todos.

**Onde aparece no app:** cards, hierarquia de texto, contraste, tamanho de toque, fonte aumentada e estados vazios.

> **Valores de referência**
> - **Contraste:** 4,5:1 para texto normal; 3:1 para texto grande (≥ 18 pt, ou 14 pt em negrito), ícones e bordas de componentes (WCAG 2.1 AA).
> - **Área de toque:** 48 × 48 dp (Material Design).
> - **Fonte aumentada:** a tela continua usável com texto a 200%.
> - **Margem lateral:** 16 dp.

#### 8.1 · Essencial
Cada tela tem um objetivo principal e uma única ação primária em destaque.
- **Como fazer:** se uma tela tem dois botões principais, provavelmente são duas tarefas e merecem duas telas.
- **Onde conferir:** Todas as telas.

#### 8.2 · Essencial · ajustado
O card do profissional mostra só o essencial: iniciais, nome, especialidade e valor. O resto fica no perfil.
- **Como fazer:** `ListTile` ou `Card` com no máximo 3 linhas de texto.
- **Onde conferir:** Busca de profissionais.
- **Ajuste:**
  - **Próximo horário livre:** saiu, porque a busca não devolve esse dado e buscá-lo custaria uma consulta à grade por profissional listado.
  - **Foto:** saiu, porque a API não tem foto.

#### 8.3 · Essencial
Hierarquia de texto clara: data e hora da consulta têm o maior destaque nas telas de confirmação, detalhe e início.
- **Como fazer:** `textTheme.titleLarge` ou `headlineSmall` para o principal; `bodyMedium` para o restante.
- **Onde conferir:** Início, Status e confirmação, Detalhe da consulta.

#### 8.4 · Essencial
Contraste mínimo de 4,5:1 para texto normal e de 3:1 para texto grande, ícones e bordas de componentes.
- **Como fazer:** os pares do tema já são conferidos por teste desde a Etapa 11. Em cada tela nova, `meetsGuideline(textContrastGuideline)` no teste de widget (ver o teste abaixo).
- **Onde conferir:** Todas as telas.

#### 8.5 · Essencial
Toda área de toque tem pelo menos 48 × 48 dp, acima dos 44 × 44 px citados no TCC (Seção 3.7).
- **Como fazer:** não reduza `materialTapTargetSize`; valide com `meetsGuideline(androidTapTargetGuideline)`.
- **Onde conferir:** Todas as telas.

#### 8.6 · Essencial
O layout funciona com a fonte do sistema aumentada (teste com 200%) sem cortar texto nem quebrar a tela.
- **Como fazer:** evite altura fixa em widgets com texto; use `Flexible`/`Expanded` e rolagem. Teste mudando a fonte nas configurações do Android.
- **Onde conferir:** Todas as telas.

#### 8.7 · Essencial
A cor nunca é a única forma de passar informação (status, horário selecionado, erro): sempre há texto ou ícone junto.
- **Como fazer:** ex.: o selo "Reserva expirada" com ícone e texto, e não só um ponto vermelho.
- **Onde conferir:** Escolha de dia e horário, Minhas consultas, Completar cadastro.

#### 8.8 · Desejável
Estados vazios têm mensagem útil e uma ação: "Você ainda não tem consultas. Agendar agora".
- **Como fazer:** widget reutilizável de estado vazio (ícone, texto, ação).
- **Onde conferir:** Início, Minhas consultas, Busca de profissionais.

#### 8.9 · Desejável
Respiro visual: margem lateral de 16 dp, espaçamento consistente entre blocos e nenhum parágrafo longo na interface.
- **Como fazer:** textos longos (termo, regras) ficam em telas próprias ou em `ExpansionTile`.
- **Onde conferir:** Todas as telas.

#### 8.10 · Desejável · ajustado
Ícones decorativos não competem com o conteúdo, e o avatar do profissional tem tamanho padronizado.
- **Como fazer:** `CircleAvatar` com tamanho fixo e as iniciais do nome. A API não tem foto.
- **Onde conferir:** Busca de profissionais, Perfil do profissional.

**Teste automático de acessibilidade (`flutter_test`):**

```dart
testWidgets('acessibilidade da busca', (tester) async {
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(const MaterialApp(home: BuscaPage()));
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
});
```

---

### H9 · Ajudar a reconhecer, diagnosticar e corrigir erros

**O que significa:** quando o erro acontece, a mensagem usa linguagem simples, diz qual foi o problema e mostra como resolver, sem códigos técnicos.

**Onde aparece no app:** conflito de horário, reserva expirada, pagamento não confirmado, erros de login e cadastro, falhas de rede e do servidor.

> **Modelo de mensagem de erro:** o que aconteceu + o que fazer agora, com um botão para isso.
> Ex.: "Não foi possível falar com o servidor. Confira a internet e tente de novo." **[Tentar novamente]**

#### 9.1 · Essencial · ajustado
Conflito de horário (409 do lock otimista): a mensagem explica em linguagem simples, e a grade se recarrega sozinha, já sem o horário perdido.
- **Como fazer:** decida pelo campo `acao` (`recarregar_horarios`), nunca pelo código HTTP nem pelo texto (decisão da Etapa 11). Mostre a `mensagem` da API e recarregue a grade antes de exibir o aviso.
- **Onde conferir:** Escolha de dia e horário, Resumo do agendamento.
- **Ajuste:** o "como fazer" usava `statusCode == 409`.

#### 9.2 · Essencial · ajustado
Ao voltar do checkout sem confirmação, a tela diz que o pagamento ainda não foi confirmado, mostra até quando o horário fica reservado e oferece "Abrir pagamento de novo". Se o prazo acabou, explica que a reserva expirou e leva de volta à grade.
- **Como fazer:** consulte `GET /consultas/:id` por alguns segundos, porque o webhook pode chegar depois do retorno. Se a consulta continuar `pendente_pagamento`, mostre o prazo de `reservaExpiraEm`. A API recusa pagar reserva vencida com `RESERVA_EXPIRADA`.
- **Onde conferir:** Pagamento, Status e confirmação.
- **Ajuste:** a versão 1 tratava "pagamento recusado" com "Usar outra forma de pagamento". A recusa acontece dentro do checkout do Mercado Pago, que já oferece outro meio de pagamento; o app só vê se a consulta foi confirmada ou não.

#### 9.3 · Essencial
Erros do Firebase Auth aparecem traduzidos; nunca exiba `e.code` ou `e.message` em inglês.
- **Como fazer:** use a função de tradução do quadro abaixo. Ao entrar, não revele se o e-mail existe: diga só "E-mail ou senha incorretos".
- **Onde conferir:** Entrar, Criar conta, Esqueci a senha.

#### 9.4 · Essencial · ajustado
O erro de cada campo aparece embaixo do próprio campo e diz como corrigir ("Informe o telefone com DDD, com 10 ou 11 dígitos").
- **Como fazer:** o `validator` do `TextFormField` devolve a mensagem. Para erros vindos da API (`DADOS_INVALIDOS`), use os `problemas` do envelope (`ProblemaDeCampo`) em `InputDecoration(errorText: ...)`.
- **Onde conferir:** Entrar, Criar conta, Completar cadastro.
- **Ajuste:** o exemplo usava CPF.

#### 9.5 · Essencial · ajustado
Falha de rede ou do servidor mostra mensagem e botão "Tentar novamente", sem apagar o que o paciente já preencheu.
- **Como fazer:** mantenha os `TextEditingController` no estado da tela. O prazo das requisições é o único de 90 s do `ApiClient` (Etapa 11), com o aviso de espera antes dele.
- **Onde conferir:** Todas as telas.
- **Ajuste:** a versão 1 sugeria `.timeout(Duration(seconds: 15))`. Com o servidor gratuito hibernando, a primeira requisição depois de uma pausa sempre falharia.

#### 9.6 · Essencial
Toda tela que carrega dados trata três estados além do sucesso: carregando, erro (com tentar novamente) e vazio.
- **Como fazer:** estados do view model, como na tela de especialidades da Etapa 11. A tela nunca fica presa carregando.
- **Onde conferir:** Termo, Busca de profissionais, Escolha de dia e horário, Minhas consultas.

#### 9.7 · Desejável
Em formulários longos, ao enviar com erro, a tela rola até o primeiro campo com problema e coloca o foco nele.
- **Como fazer:** `FocusNode.requestFocus()` no primeiro campo inválido; `Scrollable.ensureVisible(context)`.
- **Onde conferir:** Completar cadastro.

#### 9.8 · NA · ajustado
~~Os erros ficam registrados para investigar, sem mostrar detalhes técnicos ao paciente (`firebase_crashlytics`).~~
- **Por que NA:** decisão do plano do front-end: sem analytics nem relatório de falhas, porque dado de saúde não sai do aparelho para terceiros. Os erros do lado do servidor ficam nos logs da API.
- **Ajuste:** era desejável.

**Mensagens para os erros mais comuns:**

| Código ou situação | Mensagem para o paciente |
|---|---|
| `email-already-in-use` | Este e-mail já tem cadastro. Quer entrar ou recuperar a senha? |
| `invalid-email` | Confira o e-mail digitado (ex.: nome@email.com). |
| `weak-password` | Senha muito curta. Use pelo menos 6 caracteres. |
| `invalid-credential` · `wrong-password` · `user-not-found` | E-mail ou senha incorretos. |
| `too-many-requests` | Muitas tentativas seguidas. Aguarde alguns minutos e tente de novo. |
| `network-request-failed` | Sem conexão com a internet. Verifique e tente de novo. |
| API: `HORARIO_INDISPONIVEL` (409) | A `mensagem` da API ("Este horário acabou de ser reservado por outro paciente."), com a grade já recarregada |
| API: `CONSULTA_SOBREPOSTA` | A `mensagem` da API ("Você já tem uma consulta marcada nesse mesmo horário.") |
| API: `RESERVA_EXPIRADA` | A `mensagem` da API ("O prazo para pagar esta reserva terminou. Escolha o horário de novo.") |
| App: `SEM_CONEXAO` | Não foi possível falar com o servidor. Confira a internet e tente de novo. |
| Volta do checkout sem confirmação | Ainda não recebemos a confirmação do pagamento. Seu horário fica reservado até 14:45. **[Abrir pagamento de novo]** |

**Tradução dos erros do Firebase Auth (Dart 3):**

```dart
String mensagemAuth(FirebaseAuthException e) => switch (e.code) {
      'email-already-in-use' => 'Este e-mail já tem cadastro. Quer entrar ou recuperar a senha?',
      'invalid-email' => 'Confira o e-mail digitado (ex.: nome@email.com).',
      'weak-password' => 'Senha muito curta. Use pelo menos 6 caracteres.',
      'invalid-credential' || 'wrong-password' || 'user-not-found' => 'E-mail ou senha incorretos.',
      'too-many-requests' => 'Muitas tentativas seguidas. Aguarde alguns minutos.',
      'network-request-failed' => 'Sem conexão com a internet. Verifique e tente de novo.',
      _ => 'Não foi possível concluir. Tente de novo.',
    };
```

---

### H10 · Ajuda e documentação

**O que significa:** o ideal é o app não precisar de explicação, mas a ajuda deve existir, ser fácil de achar, curta e ligada à tarefa que o paciente está fazendo.

**Onde aparece no app:** explicação do pagamento antecipado, regras de cancelamento, contato da clínica, consentimento (LGPD), permissão de notificações e primeiro uso.

#### 10.1 · Essencial
No momento em que o pagamento antecipado aparece, uma explicação curta diz por que ele é pedido e o que acontece se o paciente faltar ou cancelar.
- **Como fazer:** uma frase de apoio e um link "Saiba mais" abrindo `showModalBottomSheet`. A parte sobre cancelamento depende da decisão do estorno.
- **Onde conferir:** Resumo do agendamento, Pagamento.

#### 10.2 · Essencial
A política de cancelamento e reembolso está acessível no detalhe da consulta.
- **Como fazer:** link "Regras de cancelamento" perto do botão Cancelar. O texto depende da decisão do estorno.
- **Onde conferir:** Detalhe da consulta.

#### 10.3 · Essencial · ajustado
O telefone da clínica está sempre a um toque, para quem preferir atendimento humano.
- **Como fazer:** `url_launcher` com `tel:`, a partir de `profissional.clinica.telefone`. Esconda o botão se o telefone vier `null`.
- **Onde conferir:** Perfil do profissional, Detalhe da consulta, Ajuda e perfil do usuário.
- **Ajuste:**
  - **Dependência:** depende de a API devolver `profissional.clinica`.
  - **WhatsApp:** saiu, porque o cadastro da clínica tem um telefone só. Registrar como limitação.

#### 10.4 · Essencial · ajustado
O consentimento de dados (LGPD) está em linguagem simples, com um resumo em tópicos e o texto completo, e o aceite é explícito, com a caixa desmarcada.
- **Como fazer:**
  - O termo fica em tela própria, antes de completar o cadastro, carregado de `GET /consentimento/termo-vigente`.
  - A caixa começa desmarcada (`CheckboxListTile(value: false, ...)`) e é obrigatória para seguir.
  - Se o app não tiver o texto daquela versão, ele pede atualização e nunca envia o aceite de um texto que não mostrou.
- **Onde conferir:** Termo.
- **Ajuste:** o termo saiu de dentro do cadastro para uma tela própria, como no plano da Etapa 12.

#### 10.5 · Essencial · ajustado
Antes de pedir a permissão de notificações (Android 13 ou superior), uma tela explica em uma frase por que os lembretes são úteis.
- **Como fazer:** mostre a explicação e só então chame `FirebaseMessaging.instance.requestPermission()`. O pedido vem depois do cadastro: sem conta, não há aparelho para registrar.
- **Onde conferir:** Notificação.
- **Ajuste:** a versão 1 punha o pedido na abertura do app.

#### 10.6 · Desejável
Uma tela de Ajuda com perguntas frequentes curtas: como agendar, como pagar, como cancelar, não recebi o lembrete.
- **Como fazer:** `ExpansionTile` para cada pergunta. É a tela "Como funciona" da Etapa 18.
- **Onde conferir:** Ajuda e perfil do usuário.

#### 10.7 · Desejável
O primeiro uso tem no máximo 3 telas de apresentação, com botão "Pular".
- **Como fazer:** `PageView` + indicador de página; salve "já viu" com `shared_preferences`.
- **Onde conferir:** Abertura.

#### 10.8 · Desejável
Telas menos óbvias têm uma dica no primeiro uso (ex.: "Toque em um horário para selecionar").
- **Como fazer:** texto de apoio discreto acima da grade, que some depois do primeiro uso.
- **Onde conferir:** Escolha de dia e horário.

---

## Parte 2: checklist por tela

Os mesmos itens da Parte 1, reorganizados pela tela em que aparecem. Preencha a coluna "Situação" (`✓`, `~`, `✗` ou `NA`) e, quando for `~` ou `✗`, a severidade (0–4). Os itens de "Todas as telas" valem para qualquer tela nova.

**Tipo:** E = essencial · D = desejável · NA = fora do escopo.

### Abertura — Etapa 12
2 itens · 1 essencial

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 7.1 | Sessão salva entre aberturas | E | |
| 10.7 | Apresentação curta com Pular | D | |

### Entrar — Etapa 12
9 itens · 7 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 3.10 | Esqueci minha senha visível | E | |
| 5.5 | Teclado certo e preenchimento automático | E | |
| 5.6 | Regras de senha visíveis e mostrar senha | E | |
| 6.8 | Rótulo do campo sempre visível | D | |
| 7.1 | Sessão salva entre aberturas | E | |
| 7.8 | Entrar com biometria | D | |
| 9.3 | Erros do Firebase traduzidos | E | |
| 9.4 | Erro junto ao campo, dizendo como corrigir | E | |

### Criar conta — Etapa 12
7 itens · 6 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 3.6 | Saída clara, com confirmação se preenchido | E | |
| 5.5 | Teclado certo e preenchimento automático | E | |
| 5.6 | Regras de senha visíveis e mostrar senha | E | |
| 6.8 | Rótulo do campo sempre visível | D | |
| 9.3 | Erros do Firebase traduzidos | E | |
| 9.4 | Erro junto ao campo, dizendo como corrigir | E | |

### Esqueci a senha — Etapa 12
5 itens · 5 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 1.3 | Confirmação de que o e-mail foi enviado | E | |
| 3.10 | Mesma mensagem exista ou não a conta | E | |
| 5.5 | Teclado de e-mail e preenchimento automático | E | |
| 9.3 | Erros do Firebase traduzidos | E | |

### Termo — Etapa 12
4 itens · 3 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.1 | Indicador de carregamento ao buscar o termo | E | |
| 8.9 | Texto longo em tela própria, sem parágrafos enormes | D | |
| 9.6 | Estados de carregando e erro | E | |
| 10.4 | Consentimento simples e explícito, caixa desmarcada | E | |

### Completar cadastro — Etapa 12
10 itens · 7 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 2.4 | Data de nascimento em dd/mm/aaaa | E | |
| 3.6 | Saída clara, com confirmação se preenchido | E | |
| 5.4 | Máscara e validação em tempo real (telefone, data) | E | |
| 5.5 | Teclado certo e preenchimento automático | E | |
| 5.9 | Opcionais marcados como "(opcional)" | D | |
| 6.8 | Rótulo do campo sempre visível | D | |
| 8.7 | Informação não depende só de cor | E | |
| 9.4 | Erro junto ao campo, inclusive os vindos da API | E | |
| 9.7 | Foco no primeiro campo com erro | D | |

### Início — Etapa 16
4 itens · 2 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 6.2 | Próxima consulta em destaque, com endereço | E | |
| 7.9 | Profissionais favoritos | D | |
| 8.3 | Data e hora em destaque | E | |
| 8.8 | Estado vazio com "Agendar consulta" | D | |

### Busca de profissionais — Etapa 13
17 itens · 7 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.1 | Indicador de carregamento nas chamadas à API | E | |
| 1.10 | Puxar para atualizar | D | |
| 2.6 | Ordem natural do fluxo de marcação | E | |
| 2.7 | Especialidades com nomes populares | D | |
| 3.7 | Desfazer em ações leves | D | |
| 3.9 | Limpar filtros com um toque | D | |
| 4.3 | Card de profissional reutilizado | E | |
| 5.10 | Valor visível antes de escolher horário | D | |
| 6.3 | Especialidades para escolher, não digitar | E | |
| 6.4 | Busca sem acento e com sugestões | E | |
| 6.7 | Buscas e profissionais recentes | D | |
| 7.5 | Filtros opcionais | D | |
| 7.9 | Profissionais favoritos | D | |
| 8.2 | Card de profissional enxuto | E | |
| 8.8 | Estados vazios com ação | D | |
| 8.10 | Avatar padronizado, com iniciais | D | |
| 9.6 | Estados de carregando, erro e vazio | E | |

### Perfil do profissional — Etapa 13
7 itens · 4 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.1 | Indicador de carregamento nas chamadas à API | E | |
| 2.6 | Ordem natural do fluxo de marcação | E | |
| 2.9 | Abrir endereço no mapa e ligar com um toque | D | |
| 4.3 | Card de profissional reutilizado | E | |
| 5.10 | Valor visível antes de escolher horário | D | |
| 8.10 | Avatar padronizado, com iniciais | D | |
| 10.3 | Telefone da clínica a um toque | E | |

### Escolha de dia e horário — Etapas 13 e 14
14 itens · 10 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.1 | Indicador de carregamento nas chamadas à API | E | |
| 1.6 | Disponível e selecionado distinguíveis; dias sem horário desativados | E | |
| 1.9 | Indicador de etapa no agendamento | D | |
| 1.10 | Puxar para atualizar | D | |
| 2.4 | Data e hora no formato brasileiro | E | |
| 2.6 | Ordem natural do fluxo de marcação | E | |
| 3.1 | Voltar sem perder as escolhas | E | |
| 5.2 | Dias sem vaga desativados | E | |
| 6.1 | Resumo fixo das escolhas | E | |
| 7.5 | Filtro de turno | D | |
| 8.7 | Informação não depende só de cor | E | |
| 9.1 | Conflito de horário explicado, grade recarregada | E | |
| 9.6 | Estados de carregando, erro e vazio | E | |
| 10.8 | Dica no primeiro uso | D | |

### Resumo do agendamento — Etapa 14
12 itens · 10 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 1.9 | Indicador de etapa no agendamento | D | |
| 2.3 | "Pagamento antecipado" em vez de "caução" | E | |
| 2.4 | Data, hora e valor no formato brasileiro | E | |
| 2.6 | Ordem natural do fluxo de marcação | E | |
| 3.1 | Voltar sem perder as escolhas | E | |
| 5.1 | Resumo antes de confirmar, com endereço e aviso da reserva | E | |
| 5.3 | Impedir envio duplicado | E | |
| 5.8 | Aviso de consulta no mesmo horário (mensagem da API) | D | |
| 6.1 | Resumo fixo das escolhas | E | |
| 9.1 | Conflito de horário explicado, grade recarregada | E | |
| 10.1 | Explicação do pagamento antecipado | E | |

### Pagamento — Etapa 15
10 itens · 9 essenciais · 1 NA

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.2 | Botão em estado de processando | E | |
| 1.5 | Status da consulta lido da API, nunca deduzido | E | |
| 2.3 | "Pagamento antecipado" em vez de "caução" | E | |
| 2.6 | Ordem natural do fluxo de marcação | E | |
| 3.2 | Fechar o checkout sem perder o horário dentro do prazo | E | |
| 5.3 | Impedir envio duplicado | E | |
| 6.6 | Resumo visível no pagamento | E | |
| 7.3 | Dados do cadastro no pagamento | NA | NA |
| 9.2 | Volta sem confirmação: prazo e "Abrir pagamento de novo" | E | |
| 10.1 | Explicação do pagamento antecipado | E | |

### Status e confirmação — Etapa 15
7 itens · 6 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.3 | Confirmação visível após cada ação | E | |
| 1.4 | Tela de confirmação com todos os dados da consulta | E | |
| 1.5 | Status da consulta lido da API, nunca deduzido | E | |
| 3.3 | Voltar após pagar não reabre o checkout | E | |
| 7.7 | Adicionar à agenda do celular | D | |
| 8.3 | Data e hora em destaque | E | |
| 9.2 | Volta sem confirmação: prazo e "Abrir pagamento de novo" | E | |

### Minhas consultas — Etapa 16
11 itens · 8 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.1 | Indicador de carregamento nas chamadas à API | E | |
| 1.3 | Confirmação visível após cada ação | E | |
| 1.5 | Status da consulta lido da API, nunca deduzido | E | |
| 1.7 | Selo de status com texto e ícone (seis selos) | E | |
| 1.10 | Puxar para atualizar | D | |
| 2.4 | Data, hora e valor no formato brasileiro | E | |
| 4.3 | Card de profissional reutilizado | E | |
| 7.6 | Agendar de novo | D | |
| 8.7 | Informação não depende só de cor | E | |
| 8.8 | Estados vazios com ação | D | |
| 9.6 | Estados de carregando, erro e vazio | E | |

### Detalhe da consulta — Etapa 16
13 itens · 9 essenciais · 1 NA

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.3 | Confirmação visível após cada ação | E | |
| 1.7 | Selo de status com texto e ícone | E | |
| 2.4 | Data, hora e valor no formato brasileiro | E | |
| 2.9 | Abrir endereço no mapa e ligar com um toque | D | |
| 3.4 | Cancelar consulta pelo app, vendo a regra | E | |
| 3.5 | Remarcar sem cancelar | NA | NA |
| 5.7 | Confirmar ações destrutivas | E | |
| 7.2 | Lembrete abre a consulta | E | |
| 7.6 | Agendar de novo | D | |
| 7.7 | Adicionar à agenda do celular | D | |
| 8.3 | Data e hora em destaque | E | |
| 10.2 | Política de cancelamento acessível | E | |
| 10.3 | Telefone da clínica a um toque | E | |

### Notificação — Etapa 17
3 itens · 3 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 6.5 | Lembrete diz quando, sem dado de saúde | E | |
| 7.2 | Tocar no lembrete abre a consulta | E | |
| 10.5 | Explicar antes de pedir a permissão, depois do cadastro | E | |

### Ajuda e perfil do usuário — Etapas 12 e 18
4 itens · 3 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 3.6 | Saída clara de formulários e diálogos | E | |
| 5.7 | Confirmar ações destrutivas (sair da conta) | E | |
| 10.3 | Telefone da clínica a um toque | E | |
| 10.6 | Perguntas frequentes ("Como funciona") | D | |

### Todas as telas — passada semanal e Etapa 18
22 itens · 16 essenciais · 1 NA

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 1.8 | Aviso de sem conexão | D | |
| 2.1 | Sem termos técnicos na interface | E | |
| 2.2 | Glossário único de termos | E | |
| 2.5 | Componentes nativos em pt-BR | E | |
| 2.8 | Ícones reconhecíveis e com rótulo | D | |
| 3.8 | Voltar do Android previsível | E | |
| 4.1 | Tema único, sem cores soltas | E | |
| 4.2 | Botões padronizados e na mesma posição | E | |
| 4.4 | Barra de navegação fixa e estável | E | |
| 4.5 | Escala fixa de espaçamento | E | |
| 4.6 | Mesmo padrão para sucesso, aviso e erro | E | |
| 4.7 | Convenções do Android | E | |
| 4.9 | Uma única família de ícones | D | |
| 6.9 | Tooltip e rótulo de acessibilidade em ícones | D | |
| 7.4 | Fluxo de agendamento sem etapas inúteis | E | |
| 8.1 | Uma ação principal por tela | E | |
| 8.4 | Contraste mínimo | E | |
| 8.5 | Área de toque de 48 dp | E | |
| 8.6 | Funciona com fonte aumentada | E | |
| 8.9 | Respiro visual e textos curtos | D | |
| 9.5 | Tentar novamente sem perder dados; prazo de 90 s | E | |
| 9.8 | Erros registrados para depuração | NA | NA |

### Protótipo Figma (médico e administrador)
1 item · 0 essenciais

| Item | O que conferir | Tipo | Situação |
|---|---|:-:|:-:|
| 4.8 | Figma igual ao tema do MVP | D | |

---

## Mudanças em relação à versão 1

A versão 1 foi escrita antes de conferir o contrato da API. Em 05/10/2026, cada item que depende da API ou do app foi conferido contra o código.

### Contrariavam decisões já tomadas

| Item | Versão 1 | Versão 2 | Motivo |
|---|---|---|---|
| 6.5 | Lembrete com profissional, especialidade e endereço | Lembrete diz só quando; o toque abre o detalhe | Tela bloqueada; especialidade é dado de saúde (LGPD, art. 11). A API omite de propósito. |
| 5.4 | CPF com dígito verificador | Sem CPF; telefone e data de nascimento | Minimização de dados (LGPD, art. 6º, III); a API não coleta CPF. |
| 7.3 | Essencial: dados do pagador no checkout | NA | Sem CPF, sem dados do pagador; o sandbox usa conta compradora de teste. |
| 9.8 | Desejável: `firebase_crashlytics` | NA | Plano: dado de saúde não sai do aparelho para terceiros. |
| 9.5 | `.timeout` de 15 s | Prazo único de 90 s do `ApiClient` | O servidor gratuito hiberna; 15 s faria a primeira requisição falhar. |
| 1.5 · 9.2 | Status do Mercado Pago (`approved`, `rejected`…) e "usar outra forma de pagamento" | Status da consulta; volta sem confirmação com prazo e "Abrir pagamento de novo" | O app nunca recebe o status do Mercado Pago; a recusa acontece dentro do checkout. |
| 1.7 | Quatro selos (Agendada, Paga, Cancelada, Realizada) | Seis selos, com o motivo do cancelamento | Estados reais da API. |
| 3.2 | `back_urls` | Fechar a Custom Tab e consultar a consulta | A API não configura `back_urls`; esse é o desenho do plano. |
| 9.1 | Decidir por `statusCode == 409` | Decidir pelo campo `acao` | Decisão da Etapa 11. |

### Dependiam de dados que a API não entrega

| Item | Mudança | Motivo |
|---|---|---|
| 1.4, 2.9, 5.1, 6.2, 10.3 | Mantidos, com a dependência marcada | A API vai devolver `profissional.clinica` (pedido à sessão da API). |
| 10.3 | WhatsApp saiu | A clínica tem um telefone só. |
| 8.2 | Saiu "próximo horário livre" e "foto" do card | A busca não devolve esses dados. |
| 3.5 | Desejável virou NA | Não há operação de remarcar na API. |
| 2.7 | O nome popular fica no app, não no back-end | Item desejável não justifica reabrir o contrato. |
| 6.4 | Busca de especialidade no app; de profissional pela API | O `q` da API busca no nome do profissional. |
| 7.5 | O turno é filtrado no app | A API filtra só por especialidade e nome. |
| 1.6 · 5.2 | "Ocupado" não aparece na grade | A API devolve só horários disponíveis e futuros. |

### Ajustes menores

- **2.4:** formato de data coerente com o exemplo; valores pelo `valorFormatado` da API.
- **2.2:** "reserva" entrou no glossário.
- **5.7:** "excluir conta" saiu, porque não há essa operação.
- **10.4:** o termo virou tela própria, antes do cadastro, como no plano da Etapa 12.
- **10.5:** o pedido de permissão de notificação foi para depois do cadastro.
- **Parte 2:**
  - "Cadastro" foi dividido em Criar conta, Termo e Completar cadastro, e entrou a tela Esqueci a senha, como no plano da Etapa 12;
  - cada tela ganhou a etapa em que é construída e a coluna "Situação";
  - o 5.8 saiu da Escolha de dia e horário e ficou só no Resumo, porque o aviso de sobreposição vem da API ao confirmar;
  - entraram o 1.10 e o 7.5 na Escolha de dia e horário, o 1.7 no Detalhe da consulta e o 8.8 no Início.
- **Severidade:** entrou a escala de Nielsen, que a ficha da avaliação com os especialistas também usa.
- **"Como fazer":**
  - os exemplos seguem o que a Etapa 11 já construiu: view models com `provider`, `ApiClient`, tema e conversor de datas;
  - os pacotes passam a ser sugestões, decididos em cada etapa.

---

**Referências:**
- NIELSEN, J. *10 Usability Heuristics for User Interface Design*. Nielsen Norman Group, 1994 (atualizado em 2024).
- NIELSEN, J. *Severity Ratings for Usability Problems*. Nielsen Norman Group, 1994.
- NIELSEN, J. *Usability Engineering*. 1993 (limites de tempo de resposta).
- W3C. *WCAG 2.1*, 2018 (contraste, cor e redimensionamento de texto).
- Google. *Material Design 3* (área de toque e componentes).
