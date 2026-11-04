import 'dart:async';

import 'package:agendamento_clinico/domain/models/cidade.dart';
import 'package:agendamento_clinico/domain/models/data_civil.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/pagina.dart';
import 'package:agendamento_clinico/domain/models/plano.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/ui/busca/busca_view_model.dart';
import 'package:agendamento_clinico/ui/comum/estados_de_carga.dart';
import 'package:flutter_test/flutter_test.dart';

import '../apoio/falsos.dart';

const especialidades = [Especialidade(id: 2, nome: 'Cardiologia'), Especialidade(id: 6, nome: 'Pediatria')];
const carlos = Profissional(
  id: 2,
  nome: 'Carlos Eduardo Timbó',
  registroConselho: 'CRM-CE 12345',
  valorFormatado: 'R\$ 250,00',
);
const beatriz = Profissional(
  id: 5,
  nome: 'Ana Beatriz Lopes',
  registroConselho: 'CRM-CE 54321',
  valorFormatado: 'R\$ 180,00',
);
const quixada = Cidade(id: 1, nome: 'Quixadá', uf: 'CE');
const fortaleza = Cidade(id: 3, nome: 'Fortaleza', uf: 'CE');
const unimed = Plano(id: 3, nome: 'Unimed');
const hapvida = Plano(id: 4, nome: 'Hapvida');

/// A cidade e o plano no view model da busca, sem a tela (Etapa 20).
void main() {
  BuscaViewModel montar(CatalogoFalso catalogo, {PreferenciasFalsas? preferencias}) {
    final vm = BuscaViewModel(catalogo, preferencias: preferencias);
    addTearDown(vm.dispose);
    return vm;
  }

  group('cidade guardada', () {
    test('é lida antes da primeira busca: a primeira lista já sai na cidade', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada, fortaleza],
        ],
        profissionais: [paginaDe([carlos])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas(cidade: 3));

      await vm.carregar();

      expect(catalogo.filtrosDosPedidos, [(cidadeId: 3, planoId: null)]);
      expect(vm.cidade, fortaleza);
    });

    test('com o armazenamento demorando, a busca espera a cidade guardada', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada, fortaleza],
        ],
        profissionais: [paginaDe([carlos])],
      );
      final leitura = Completer<void>();
      final vm = montar(catalogo, preferencias: PreferenciasFalsas(cidade: 3)..leituraDemorada = leitura);

      final carregando = vm.carregar();
      await pumpEventQueue();
      // Nada sai antes da leitura: uma lista de todas as cidades, mostrada e
      // logo trocada pela da cidade, pareceria um defeito.
      expect(catalogo.pedidosDeProfissionais, isEmpty);

      leitura.complete();
      await carregando;
      expect(catalogo.filtrosDosPedidos, [(cidadeId: 3, planoId: null)]);
    });

    test('a que saiu do catálogo volta a "Todas as cidades", e sai do aparelho', () async {
      final preferencias = PreferenciasFalsas(cidade: 9);
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada],
        ],
        profissionais: [paginaDe([carlos])],
      );
      final vm = montar(catalogo, preferencias: preferencias);

      await vm.carregar();

      expect(catalogo.filtrosDosPedidos.single.cidadeId, isNull);
      expect(vm.cidade, isNull);
      expect(preferencias.guardadas, [null]);
    });

    test('sem a lista de cidades, não filtra — e não é apagada do aparelho', () async {
      final preferencias = PreferenciasFalsas(cidade: 1);
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [const ErroDaApi.semConexao()],
        profissionais: [paginaDe([carlos])],
      );
      final vm = montar(catalogo, preferencias: preferencias);

      await vm.carregar();

      expect(vm.estado, EstadoDaCarga.pronto);
      expect(vm.profissionais, [carlos]);
      expect(vm.cidades, isEmpty);
      expect(vm.cidade, isNull);
      expect(catalogo.filtrosDosPedidos.single.cidadeId, isNull);
      expect(preferencias.guardadas, isEmpty);
    });

    test('a lista que chega depois traz a cidade guardada, e a busca recomeça nela', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          const ErroDaApi.semConexao(),
          [quixada],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([beatriz])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas(cidade: 1));
      await vm.carregar();

      await vm.tentarListasDeNovo();

      expect(vm.cidade, quixada);
      expect(catalogo.filtrosDosPedidos.map((f) => f.cidadeId), [null, 1]);
      expect(vm.profissionais, [beatriz]);
    });

    test('o armazenamento que falha ao ler não segura a busca', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada],
        ],
        profissionais: [paginaDe([carlos])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas(cidade: 1)..erroAoLer = Exception('disco'));

      await vm.carregar();

      expect(vm.estado, EstadoDaCarga.pronto);
      expect(vm.cidade, isNull);
    });

    test('"Tentar de novo" não lê a cidade guardada outra vez', () async {
      final preferencias = PreferenciasFalsas(cidade: 1);
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada, fortaleza],
        ],
        profissionais: [const ErroDaApi.semConexao(), paginaDe([carlos])],
      );
      final vm = montar(catalogo, preferencias: preferencias);
      await vm.carregar();
      expect(vm.estado, EstadoDaCarga.falhou);
      // O que está guardado mudou por fora; quem vale é a cidade da tela.
      preferencias.cidade = 3;

      await vm.carregar();

      expect(vm.cidade, quixada);
      expect(catalogo.filtrosDosPedidos.map((f) => f.cidadeId), [1, 1]);
    });
  });

  group('escolher a cidade', () {
    test('guarda no aparelho e busca de novo nela; "Todas" apaga', () async {
      final preferencias = PreferenciasFalsas();
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada, fortaleza],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([beatriz]), paginaDe([carlos, beatriz])],
      );
      final vm = montar(catalogo, preferencias: preferencias);
      await vm.carregar();

      vm.escolherCidade(1);
      await pumpEventQueue();
      expect(vm.cidade, quixada);
      expect(vm.profissionais, [beatriz]);

      vm.escolherCidade(null);
      await pumpEventQueue();
      expect(vm.cidade, isNull);

      expect(preferencias.guardadas, [1, null]);
      expect(catalogo.filtrosDosPedidos.map((f) => f.cidadeId), [null, 1, null]);
    });

    test('a mesma cidade de novo não busca outra vez', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([beatriz])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas());
      await vm.carregar();
      vm.escolherCidade(1);
      await pumpEventQueue();

      vm.escolherCidade(1);
      await pumpEventQueue();

      expect(catalogo.pedidosDeProfissionais, hasLength(2));
    });

    test('o armazenamento que falha ao guardar não segura a busca', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([beatriz])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas()..erroAoGuardar = Exception('cheio'));
      await vm.carregar();

      vm.escolherCidade(1);
      await pumpEventQueue();

      expect(vm.estado, EstadoDaCarga.pronto);
      expect(vm.profissionais, [beatriz]);
    });

    test('a resposta da cidade anterior, chegando depois, é descartada', () async {
      final daAnterior = Completer<Pagina<Profissional>>();
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada, fortaleza],
        ],
        profissionais: [paginaDe([carlos]), daAnterior, paginaDe([beatriz])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas());
      await vm.carregar();

      vm.escolherCidade(1);
      await pumpEventQueue();
      vm.escolherCidade(3);
      await pumpEventQueue();
      daAnterior.complete(paginaDe([carlos]));
      await pumpEventQueue();

      expect(vm.cidade, fortaleza);
      expect(vm.profissionais, [beatriz]);
    });
  });

  group('plano', () {
    test('vai no pedido, conta como filtro, e "Limpar filtros" o tira — a cidade fica', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          [quixada],
        ],
        planos: [
          [hapvida, unimed],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([carlos]), paginaDe([beatriz]), paginaDe([carlos, beatriz])],
      );
      final vm = montar(catalogo, preferencias: PreferenciasFalsas(cidade: 1));
      await vm.carregar();
      expect(vm.temFiltro, isFalse, reason: 'a cidade não é filtro');

      vm.escolherPlano(3);
      await pumpEventQueue();
      expect(vm.plano, unimed);
      expect(vm.temFiltro, isTrue);
      vm.escolherEspecialidade(2);
      await pumpEventQueue();

      vm.limparFiltros();
      await pumpEventQueue();

      expect(vm.plano, isNull);
      expect(vm.especialidadeId, isNull);
      expect(vm.cidade, quixada);
      expect(vm.temFiltro, isFalse);
      expect(catalogo.filtrosDosPedidos, [
        (cidadeId: 1, planoId: null),
        (cidadeId: 1, planoId: 3),
        (cidadeId: 1, planoId: 3),
        (cidadeId: 1, planoId: null),
      ]);
    });

    test('a especialidade escolhida no Início mantém o plano', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        planos: [
          [unimed],
        ],
        profissionais: [paginaDe([carlos]), paginaDe([carlos]), paginaDe([beatriz])],
      );
      final vm = montar(catalogo);
      await vm.carregar();
      vm.escolherPlano(3);
      await pumpEventQueue();

      vm.mostrarEspecialidade(6);
      await pumpEventQueue();

      expect(vm.plano, unimed);
      expect(catalogo.filtrosDosPedidos.last.planoId, 3);
    });
  });

  group('listas', () {
    test('a lista que falhou é pedida de novo na busca seguinte, e não a cada página', () async {
      final catalogo = CatalogoFalso(
        especialidades: [especialidades],
        cidades: [
          const ErroDaApi.semConexao(),
          [quixada],
        ],
        planos: [
          [unimed],
        ],
        profissionais: [
          paginaDe([carlos], paginas: 2, total: 2),
          paginaDe([beatriz], pagina: 2, paginas: 2, total: 2),
          paginaDe([carlos]),
        ],
      );
      final vm = montar(catalogo);
      await vm.carregar();
      await vm.mostrarMais();
      expect(catalogo.pedidosDeCidades, 1);

      vm.escolherEspecialidade(2);
      await pumpEventQueue();

      expect(catalogo.pedidosDeCidades, 2);
      expect(vm.cidades, [quixada]);
      // A que veio não é pedida de novo.
      expect(catalogo.pedidosDePlanos, 1);
    });

    test('"hoje" é o dia da clínica no relógio dado', () {
      final vm = BuscaViewModel(CatalogoFalso(), relogio: () => DateTime.utc(2026, 11, 10, 2));
      addTearDown(vm.dispose);

      // 23:00 do dia 9 em Quixadá.
      expect(vm.hoje, DataCivil.tentar(2026, 11, 9));
    });
  });
}
