# Marcaí — aplicativo do paciente

Aplicativo Android do Trabalho de Conclusão de Curso **"Desenvolvimento de um
aplicativo móvel para gerenciamento e pagamento centralizado de consultas
clínicas"**, do curso de Sistemas de Informação do Centro Universitário Católica
de Quixadá (UniCatólica).

- **Autor:** Felipe Mesquita Pinto
- **Orientador:** Prof. Décio Gonçalves de Aguiar Neto
- **API:** [agendamento-clinico](https://github.com/F-mesquita341/agendamento-clinico)

O aplicativo é o perfil do paciente. Os perfis do médico, da recepção e do
administrador da clínica existem como protótipo no Figma, fora deste
repositório. **Todo pagamento é feito no ambiente de teste (sandbox) do Mercado
Pago: nenhum valor real é cobrado.**

## O que o aplicativo faz

- **Conta:** cadastro e entrada por e-mail e senha, com o aceite do termo de
  consentimento.
- **Busca:** profissionais por especialidade, nome, cidade, plano de saúde ou
  distância ("Perto de mim"), com o próximo horário livre de cada um.
- **Agendamento:** a grade de horários e a reserva protegida contra dois
  pacientes no mesmo horário (lock otimista na API). Se alguém reservou antes, o
  aplicativo avisa e sugere os horários livres mais próximos.
- **Pagamento:** pelo aplicativo (página do Mercado Pago ou, a partir da 2.1.0,
  Pix com QR Code), pelo plano de saúde ou na clínica, no dia.
- **Minhas consultas:** as próximas e as anteriores, com os detalhes e o
  cancelamento.
- **Lembrete:** notificação um dia antes de cada consulta confirmada.

## Versões

| Versão | Onde | O que traz |
|---|---|---|
| `v1.0.0` | `main` | O MVP, congelado em 06/11/2026. |
| `v2.0.0` | `versao-2` | Nova identidade visual, cidade, plano de saúde, próximo horário, formas de pagamento e "Perto de mim". |
| `v2.0.1` | `versao-2` | **A versão usada nas sessões com participantes.** Igual à 2.0.0, sem a lista de telefones das clínicas no Perfil. |
| 2.1.0 e 2.1.1 | `pix` | Pagamento por Pix em ambiente de teste, acrescentado depois das sessões. Não fez parte da avaliação. |

## Tecnologias

| | |
|---|---|
| Framework | Flutter 3.38 (Dart 3.10), Android |
| Estado | `ChangeNotifier` + `provider` |
| Autenticação | Firebase Authentication |
| Lembretes | Firebase Cloud Messaging |
| Pagamento | Mercado Pago, em sandbox, pela API |

## Arquitetura

Segue o guia oficial de arquitetura do Flutter:

```
lib/
  config/              endereço da API e tema
  data/services/       cliente HTTP, conta, notificações, localização
  data/repositories/   o que cada tela pede à API, atrás de interfaces
  domain/models/       modelos lidos do JSON da API
  ui/<funcionalidade>/ tela + view model
```

As telas não falam com a rede: pedem a um repositório, que pede ao cliente HTTP.
A API responde todo erro no mesmo formato, e o aplicativo mostra a mensagem dela
e decide o que fazer pela ação sugerida, nunca pelo texto. Datas e horas são
sempre as da clínica, e os valores vêm prontos da API.

## Qualidade

- **Testes automáticos** de telas, view models, repositórios e modelos, contra
  uma API falsa, sem rede. A integração contínua roda a análise e os testes a
  cada envio. Cada mecanismo importante foi confirmado reintroduzindo o defeito
  que ele previne e vendo o teste falhar.
- **Acessibilidade (WCAG 2.1 AA):** contraste das cores, áreas de toque de 48 dp,
  nomes para o leitor de tela e telas conferidas em quatro tamanhos de aparelho,
  com o texto a até 200%. A fonte é a Atkinson Hyperlegible Next, feita para quem
  tem baixa visão.
- **Heurísticas de Nielsen:** autoavaliação com checklist antes das sessões.

## Privacidade

- O aplicativo não usa ferramentas de análise de uso nem de relatório de falhas.
- A busca no catálogo vai sem a identificação da conta.
- "Perto de mim" usa só a localização aproximada, e a distância é calculada no
  próprio aparelho: a posição não é enviada nem guardada.
- A notificação de lembrete não traz o profissional nem a especialidade.
- O aplicativo fica fora do backup do Android.

## Licença

MIT.
