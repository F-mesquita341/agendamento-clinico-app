# Aplicativo do paciente — Agendamento Clínico

Aplicativo Android do Trabalho de Conclusão de Curso **“Desenvolvimento de um
aplicativo móvel para gerenciamento e pagamento centralizado de consultas
clínicas”**, do curso de Sistemas de Informação do Centro Universitário Católica
de Quixadá.

- **Autor:** Felipe Mesquita Pinto
- **Orientador:** Décio Gonçalves de Aguiar Neto
- **API:** [agendamento-clinico](https://github.com/F-mesquita341/agendamento-clinico)

É o MVP do **perfil paciente**: cadastro, busca de profissionais, agendamento,
lembrete por notificação e pagamento da caução em **ambiente de teste (sandbox)
do Mercado Pago — nenhuma transação real é processada**. Os perfis de médico e
de administrador da clínica são um protótipo no Figma, fora deste repositório.

> Repositório público para permitir replicabilidade e auditoria por terceiros,
> conforme declarado na metodologia do projeto de pesquisa.

## Tecnologias

| | |
|---|---|
| Framework | Flutter 3.38 (Dart 3.10), build Android |
| Estado | `ChangeNotifier` + `provider` |
| HTTP | `http` |
| Autenticação | Firebase Authentication, por e-mail e senha |
| Notificações | Firebase Cloud Messaging (Etapa 17) |

## Arquitetura

Segue o guia oficial de arquitetura do Flutter, que espelha as camadas da API:

```
lib/
  config/              endereço da API e tema
  data/services/       ApiClient — token, envelope de erro, renovação da sessão —
                       e a conta no Firebase, atrás de uma interface
  data/repositories/   o que cada tela pede à API, atrás de uma interface
  domain/models/       modelos imutáveis lidos do JSON da API
  ui/comum/            botões, espaçamento, retorno, carregando e falha
  ui/<funcionalidade>/ tela + view model
assets/termos/         o texto do termo de consentimento, um arquivo por versão
```

As telas não falam com a rede: pedem a um repositório, que pede ao `ApiClient`.
Por isso cada tela é testada com um repositório em memória, sem servidor.

**Erros:** a API responde toda falha no mesmo envelope,
`{erro: {codigo, mensagem, acao}}`. A tela mostra a `mensagem` — já escrita em
português para o paciente — e decide o que fazer pela `acao`, um conjunto
fechado de seis valores; nunca pelo texto.

**Conta e sessão.** A raiz do aplicativo (`PortaoDaSessao`) escolhe a tela pelo
estado da sessão: sem sessão, a tela de entrar; com sessão e sem perfil, o termo
de consentimento e o cadastro; com perfil, o aplicativo. Trocar de área fecha as
telas abertas por cima, então depois do cadastro voltar não leva ao formulário.
Qualquer pedido que receba `autenticar` da API leva de volta à tela de entrar,
dizendo por quê.

**Termo de consentimento.** A API diz qual versão está vigente; o texto mora no
aplicativo, em `assets/termos/`. O aceite enviado no cadastro é sempre o da
versão cujo texto foi mostrado. Se a vigente não for uma que o aplicativo tem,
ele pede para ser atualizado em vez de aceitar um texto que não mostrou. Um
teste fixa o conteúdo de cada versão: texto novo é versão nova.

**Datas** chegam da API em UTC e passam todas por `instanteDaApi`, que as
converte para o horário do aparelho. **Dinheiro** é sempre o `valorFormatado`
que a API manda; o aplicativo não faz conta com valores.

## Como rodar

Pré-requisitos: Flutter 3.38 e Android SDK (Android Studio traz os dois) e um
emulador ou aparelho Android.

**Configuração do Firebase.** O arquivo `android/app/google-services.json` fica
fora do Git: ele aponta para um projeto do Firebase, e quem reproduz o trabalho
usa o seu. No [console do Firebase](https://console.firebase.google.com):

1. Crie um projeto, ou use um existente, e em **Authentication → Método de
   login** ative **E-mail/senha**.
2. Em **Configurações do projeto → Seus apps**, adicione um app **Android** com
   o nome de pacote `io.github.fmesquita341.agendamento_clinico`.
3. Baixe o `google-services.json` e salve em `android/app/`.

A API precisa usar o mesmo projeto do Firebase, para aceitar os tokens do
aplicativo. Sem o arquivo, a análise e os testes rodam normalmente — eles não
usam o Firebase —, mas a compilação para Android falha.

```bash
flutter pub get
flutter run
```

Por padrão o aplicativo usa a API publicada. Para usar uma API rodando no
computador, a partir do emulador:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:3000
```

O servidor gratuito da API hiberna depois de 15 minutos parado; o primeiro
acesso depois disso leva perto de um minuto. Depois de 4 segundos de espera, o
aplicativo avisa que o servidor está demorando — sem afirmar a causa, porque um
servidor fora do ar também deixa a conexão pendurada. Passados 90 segundos, a
espera vira uma mensagem de falta de conexão, com a opção de tentar de novo.

## Testes

```bash
flutter analyze --fatal-infos
flutter test
```

A integração contínua roda os dois a cada envio. Cada mecanismo foi confirmado
reintroduzindo de propósito o defeito que ele previne e vendo o teste certo
cair — o registro está no diário do projeto, no repositório da API
(`docs/diario.md`).

**APK de portão ou de sessão com participantes sai sempre de um
`flutter clean`.** Os caches do Flutter e do Gradle decidem pelo conteúdo dos
arquivos, e um arquivo alterado durante uma compilação já deixou um APK com
código que não estava mais no repositório (diário, 05/10/2026).

**Acessibilidade (WCAG 2.1 AA)** também é conferida por teste: o contraste de
cada par de cor e texto do tema (mínimo 4,5:1), a área de toque mínima de 48 dp
e as telas com o texto ampliado a 200%.

## Licença

MIT.
