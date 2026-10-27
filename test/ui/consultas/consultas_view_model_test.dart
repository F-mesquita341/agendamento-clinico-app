import 'dart:async';

import 'package:agendamento_clinico/domain/models/consulta.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/pagina.dart';
import 'package:agendamento_clinico/ui/comum/estados_de_carga.dart';
import 'package:agendamento_clinico/ui/consultas/consultas_view_model.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../apoio/agenda.dart';
import '../../apoio/falsos.dart';

void main() {
  // Meio-dia de quarta, 14/10, na clínica.
  late DateTime agora;
  setUp(() => agora = meioDiaDeQuarta);

  ConsultasViewModel criar(ConsultasFalso consultas) => ConsultasViewModel(consultas, relogio: () => agora);

  Pagina<Consulta> pagina(List<Consulta> itens, {int numero = 1, int paginas = 1, int? total}) =>
      Pagina(itens: itens, pagina: numero, paginas: paginas, total: total ?? itens.length);

  // Na ordem da API: a mais adiante primeiro.
  final dia22 = consultaNa(horario(13, 22, 9), id: 13);
  final dia21 = consultaNa(horario(12, 21, 9), id: 12);
  final dia20 = consultaNa(horario(11, 20, 9), id: 11);
  final ontem = consultaNa(horario(1, 13, 9), id: 1);
  final anteontem = consultaNa(horario(2, 12, 9), id: 2);

  List<int> ids(Iterable<({Consulta consulta, Object horario, Object profissional})> itens) =>
      [for (final item in itens) item.consulta.id];

  group('a carga', () {
    test('pede páginas até chegar ao passado; as próximas, da mais cedo para a mais tarde', () async {
      final consultas = ConsultasFalso(minhas: [
        pagina([dia22, dia21], paginas: 3, total: 5),
        pagina([dia20, ontem], numero: 2, paginas: 3, total: 5),
      ]);
      final vm = criar(consultas);

      await vm.carregar();

      expect(consultas.pedidosDeMinhas, [1, 2]);
      expect(vm.estado, EstadoDaCarga.pronto);
      expect(ids(vm.proximas), [11, 12, 13]);
      expect(ids(vm.anteriores), [1]);
      expect(vm.temMais, isTrue);
      vm.dispose();
    });

    test('para na última página, mesmo sem chegar ao passado', () async {
      final consultas = ConsultasFalso(minhas: [pagina([dia22, dia21])]);
      final vm = criar(consultas);

      await vm.carregar();

      expect(consultas.pedidosDeMinhas, [1]);
      expect(ids(vm.proximas), [12, 13]);
      expect(vm.temMais, isFalse);
      vm.dispose();
    });

    test('não passa de cinco páginas', () async {
      final consultas = ConsultasFalso(minhas: [
        for (var n = 1; n <= 5; n++) pagina([consultaNa(horario(20 + n, 25, 9), id: 20 + n)], numero: n, paginas: 9),
      ]);
      final vm = criar(consultas);

      await vm.carregar();

      expect(consultas.pedidosDeMinhas, [1, 2, 3, 4, 5]);
      expect(vm.temMais, isTrue);
      vm.dispose();
    });

    test('a consulta que vem em duas páginas aparece uma vez', () async {
      final consultas = ConsultasFalso(minhas: [
        pagina([dia22, dia21], paginas: 2, total: 4),
        pagina([dia21, ontem], numero: 2, paginas: 2, total: 4),
      ]);
      final vm = criar(consultas);

      await vm.carregar();

      expect(ids(vm.proximas), [12, 13]);
      expect(ids(vm.anteriores), [1]);
      vm.dispose();
    });

    test('cada consulta na sua lista: cancelada no futuro e reserva vencida vão para as anteriores', () async {
      final reserva = consultaNa(
        horario(14, 23, 9),
        id: 14,
        status: StatusDaConsulta.pendentePagamento,
        expiraEm: agora.add(const Duration(minutes: 10)),
      );
      final vencida = consultaNa(
        horario(15, 23, 10),
        id: 15,
        status: StatusDaConsulta.pendentePagamento,
        expiraEm: agora.subtract(const Duration(minutes: 1)),
      );
      final cancelada = consultaNa(
        horario(16, 24, 9),
        id: 16,
        status: StatusDaConsulta.cancelada,
        motivo: MotivoDoCancelamento.paciente,
      );
      final vm = criar(ConsultasFalso(minhas: [
        pagina([cancelada, vencida, reserva, dia20, ontem]),
      ]));

      await vm.carregar();

      expect(ids(vm.proximas), [11, 14]);
      expect(ids(vm.anteriores), [16, 15, 1]);
      expect(vm.reservaAguardando?.consulta.id, 14);
      expect(vm.proximaConfirmada?.consulta.id, 11);
      vm.dispose();
    });

    test('a contagem das anteriores inclui as que ainda não vieram', () async {
      final vm = criar(ConsultasFalso(minhas: [
        pagina([dia20, ontem, anteontem], paginas: 4, total: 30),
      ]));

      await vm.carregar();

      expect(vm.proximas, hasLength(1));
      expect(vm.anteriores, hasLength(2));
      expect(vm.totalDeAnteriores, 29);
      vm.dispose();
    });

    test('falha: o erro, e "Tentar de novo" carrega do zero', () async {
      final consultas = ConsultasFalso(minhas: [const ErroDaApi.semConexao(), pagina([dia20])]);
      final vm = criar(consultas);

      await vm.carregar();
      expect(vm.estado, EstadoDaCarga.falhou);
      expect(vm.erro?.codigo, 'SEM_CONEXAO');

      await vm.carregar();
      expect(vm.estado, EstadoDaCarga.pronto);
      expect(ids(vm.proximas), [11]);
      vm.dispose();
    });
  });

  group('mostrar mais e atualizar', () {
    test('"mostrar mais" acrescenta a página seguinte às anteriores', () async {
      final consultas = ConsultasFalso(minhas: [
        pagina([dia20, ontem], paginas: 2, total: 3),
        pagina([anteontem], numero: 2, paginas: 2, total: 3),
      ]);
      final vm = criar(consultas);
      await vm.carregar();

      await vm.mostrarMais();

      expect(consultas.pedidosDeMinhas, [1, 2]);
      expect(ids(vm.anteriores), [1, 2]);
      expect(vm.temMais, isFalse);
      vm.dispose();
    });

    test('atualizar com "mostrar mais" no ar: a página antiga não entra na lista nova', () async {
      final pagina2 = Completer<Pagina<Consulta>>();
      final consultas = ConsultasFalso(minhas: [
        pagina([dia20, ontem], paginas: 2, total: 3),
        pagina2,
        pagina([dia21, dia20, ontem], paginas: 2, total: 4),
      ]);
      final vm = criar(consultas);
      await vm.carregar();

      final mais = vm.mostrarMais();
      await vm.atualizar();
      pagina2.complete(pagina([anteontem], numero: 2, paginas: 2, total: 3));
      await mais;

      expect(ids(vm.proximas), [11, 12]);
      expect(ids(vm.anteriores), [1]);
      expect(vm.mostrandoMais, isFalse);
      vm.dispose();
    });

    test('durante a atualização, "mostrar mais" não pede nada', () async {
      final atualizacao = Completer<Pagina<Consulta>>();
      final consultas = ConsultasFalso(minhas: [
        pagina([dia20, ontem], paginas: 2, total: 3),
        atualizacao,
      ]);
      final vm = criar(consultas);
      await vm.carregar();

      final atualizando = vm.atualizar();
      await vm.mostrarMais();
      expect(consultas.pedidosDeMinhas, [1, 1]);

      atualizacao.complete(pagina([dia20, ontem], paginas: 2, total: 3));
      await atualizando;
      vm.dispose();
    });

    test('atualizar que falha deixa a lista e diz por quê', () async {
      final vm = criar(ConsultasFalso(minhas: [pagina([dia20]), const ErroDaApi.semConexao()]));
      await vm.carregar();

      await vm.atualizar();

      expect(vm.estado, EstadoDaCarga.pronto);
      expect(ids(vm.proximas), [11]);
      expect(vm.erroAoAtualizar?.codigo, 'SEM_CONEXAO');
      vm.dispose();
    });
  });

  group('o relógio das fronteiras', () {
    testWidgets('no prazo da reserva, o aviso some e ela vai para as anteriores, sem pedir nada', (tester) async {
      final reserva = consultaNa(
        horario(14, 23, 9),
        id: 14,
        status: StatusDaConsulta.pendentePagamento,
        expiraEm: agora.add(const Duration(minutes: 15)),
      );
      final consultas = ConsultasFalso(minhas: [pagina([reserva])]);
      final vm = criar(consultas);
      var avisos = 0;
      vm.addListener(() => avisos++);
      await vm.carregar();
      expect(vm.reservaAguardando?.consulta.id, 14);
      avisos = 0;

      agora = agora.add(const Duration(minutes: 15));
      await tester.pump(const Duration(minutes: 15));

      expect(avisos, 1);
      expect(vm.reservaAguardando, isNull);
      expect(ids(vm.anteriores), [14]);
      expect(consultas.pedidosDeMinhas, [1]);
      vm.dispose();
    });

    testWidgets('no começo do horário, a confirmada sai das próximas', (tester) async {
      agora = horario(11, 20, 9).inicio.subtract(const Duration(minutes: 1));
      final vm = criar(ConsultasFalso(minhas: [pagina([dia20])]));
      await vm.carregar();
      expect(ids(vm.proximas), [11]);

      agora = agora.add(const Duration(minutes: 1));
      await tester.pump(const Duration(minutes: 1));

      expect(vm.proximas, isEmpty);
      expect(vm.proximaConfirmada, isNull);
      vm.dispose();
    });

    testWidgets('fechar a tela cancela o relógio', (tester) async {
      final vm = criar(ConsultasFalso(minhas: [pagina([dia20])]));
      await vm.carregar();

      vm.dispose();
      // Um relógio esquecido seria um Timer pendente no fim do teste.
    });
  });
}
