/// Endereço da API.
///
/// Vem de `--dart-define=API_URL=...` na hora de rodar ou compilar; sem ele, é
/// a API publicada. Para apontar para uma API rodando no computador, a partir
/// do emulador Android: `--dart-define=API_URL=http://10.0.2.2:3000`.
const String urlDaApi = String.fromEnvironment(
  'API_URL',
  defaultValue: 'https://agendamento-clinico-api.onrender.com',
);
