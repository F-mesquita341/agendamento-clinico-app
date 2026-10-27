import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/consultas/situacao_da_consulta.dart';

// A agenda de teste da grade, do resumo e do pagamento: um profissional, a
// clínica dele e horários ditos no relógio da clínica.

const clinica = Clinica(
  nome: 'Clínica Exemplo Quixadá',
  telefone: '(88) 3000-0000',
  endereco: 'Centro, Quixadá - CE',
);

Profissional timboNa(Clinica? clinica) => Profissional(
      id: 2,
      nome: 'Carlos Eduardo Timbó',
      registroConselho: 'CRM-CE 12345',
      valorFormatado: 'R\$ 250,00',
      especialidade: const Especialidade(id: 2, nome: 'Cardiologia'),
      clinica: clinica,
    );
final timbo = timboNa(clinica);

/// Meio-dia de quarta-feira, 14/10/2026, em Quixadá.
final meioDiaDeQuarta = DateTime.utc(2026, 10, 14, 15);

/// Um horário livre, dito no relógio da clínica (UTC−3).
Horario horario(int id, int dia, int hora, {int minuto = 0, int mes = 10, int ano = 2026, int versao = 0}) =>
    Horario(
      id: id,
      inicio: DateTime.utc(ano, mes, dia, hora + 3, minuto),
      duracaoMinutos: 30,
      versao: versao,
    );

/// Uma consulta como a lista e o detalhe da API a trazem: com o horário e o
/// profissional dentro.
Consulta consultaNa(
  Horario horario, {
  int id = 50,
  StatusDaConsulta status = StatusDaConsulta.confirmada,
  MotivoDoCancelamento? motivo,
  DateTime? expiraEm,
  Profissional? profissional,
}) =>
    Consulta(
      id: id,
      status: status,
      motivoDoCancelamento: motivo,
      horarioId: horario.id,
      valorFormatado: 'R\$ 250,00',
      reservaExpiraEm: expiraEm,
      horario: horario,
      profissional: profissional ?? timbo,
    );

/// O item da lista que as telas usam, a partir de uma consulta com o horário
/// e o profissional.
ConsultaNaLista itemDe(Consulta consulta) =>
    (consulta: consulta, horario: consulta.horario!, profissional: consulta.profissional!);
