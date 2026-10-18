import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/horario.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';

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
