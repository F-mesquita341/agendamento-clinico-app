import 'dart:async';

import 'package:agendamento_clinico/data/services/servico_de_localizacao.dart';
import 'package:agendamento_clinico/domain/models/cidade.dart';
import 'package:agendamento_clinico/domain/models/clinica.dart';
import 'package:agendamento_clinico/domain/models/coordenadas.dart';
import 'package:agendamento_clinico/domain/models/erro_da_api.dart';
import 'package:agendamento_clinico/domain/models/especialidade.dart';
import 'package:agendamento_clinico/domain/models/plano.dart';
import 'package:agendamento_clinico/domain/models/profissional.dart';
import 'package:agendamento_clinico/config/tema.dart';
import 'package:agendamento_clinico/ui/busca/busca_screen.dart';
import 'package:agendamento_clinico/ui/busca/busca_view_model.dart';
import 'package:agendamento_clinico/ui/busca/perto_de_mim.dart';
import 'package:agendamento_clinico/ui/busca/seletores.dart';
import 'package:agendamento_clinico/ui/comum/card_do_profissional.dart';
import 'package:agendamento_clinico/ui/comum/estados_de_carga.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../apoio/acessibilidade.dart';
import '../apoio/falsos.dart';

const quixada = Cidade(id: 1, nome: 'Quixadá', uf: 'CE');
const quixeramobim = Cidade(id: 2, nome: 'Quixeramobim', uf: 'CE');
const fortaleza = Cidade(id: 3, nome: 'Fortaleza', uf: 'CE');
const unimed = Plano(id: 3, nome: 'Unimed');
const cardiologia = Especialidade(id: 2, nome: 'Cardiologia');

/// As clínicas do catálogo de demonstração da homologação.
const pontoDeQuixada = Coordenadas(-4.9708, -39.0153);
const pontoDeFortaleza = Coordenadas(-3.734, -38.529);

Profissional naClinica(int id, String nome, Cidade? cidade, Coordenadas? ponto) => Profissional(
      id: id,
      nome: nome,
      registroConselho: 'CRM-CE ${10000 + id}',
      valorFormatado: 'R\$ 200,00',
      especialidade: cardiologia,
      clinica: Clinica(
        nome: 'Clínica ${cidade?.nome ?? 'sem endereço'}',
        cidade: cidade,
        latitude: ponto?.latitude,
        longitude: ponto?.longitude,
      ),
    );

/// A ~0 km, ~40 km e ~148 km de Quixadá; e uma clínica sem coordenadas.
final emQuixada = naClinica(1, 'Ana Quixadá', quixada, pontoDeQuixada);
final emQuixeramobim = naClinica(2, 'Bruno Quixeramobim', quixeramobim, const Coordenadas(-5.2011, -39.295));
final emFortaleza = naClinica(3, 'Carla Fortaleza', fortaleza, pontoDeFortaleza);
final semCoordenadas = naClinica(4, 'Davi Sem Endereço', null, null);

void main() {
  BuscaViewModel montar(
    CatalogoFalso catalogo, {
    PreferenciasFalsas? preferencias,
    LocalizacaoFalsa? localizacao,
  }) {
    final vm = BuscaViewModel(catalogo, preferencias: preferencias, localizacao: localizacao);
    addTearDown(vm.dispose);
    return vm;
  }

  CatalogoFalso catalogo(List<Object?> paginas) => CatalogoFalso(
        especialidades: [
          [cardiologia],
        ],
        cidades: [
          [fortaleza, quixada, quixeramobim],
        ],
        planos: [
          [unimed],
        ],
        profissionais: paginas,
      );

  group('escolher "Perto de mim"', () {
    test('pede todas as páginas, sem cidade, e ordena do mais perto ao mais longe', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
        // A API manda em outra ordem, em duas páginas.
        paginaDe([emQuixeramobim, semCoordenadas], paginas: 2, total: 4),
        paginaDe([emFortaleza, emQuixada], pagina: 2, paginas: 2, total: 4),
      ]);
      final preferencias = PreferenciasFalsas(cidade: 3);
      final vm = montar(falso, preferencias: preferencias, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();
      expect(vm.cidade, fortaleza);

      expect(await vm.usarPertoDeMim(), ResultadoDoPertoDeMim.usado);
      await pumpEventQueue();

      expect(vm.pertoDeMim, isTrue);
      expect(vm.cidade, isNull);
      expect(falso.filtrosDosPedidos.skip(1), [
        (cidadeId: null, planoId: null),
        (cidadeId: null, planoId: null),
      ]);
      expect(falso.pedidosDeProfissionais.skip(1).map((p) => p.pagina), [1, 2]);
      expect(vm.profissionais, [emQuixada, emQuixeramobim, emFortaleza, semCoordenadas]);
      expect(vm.temMais, isFalse, reason: 'a lista vem inteira');
      expect(vm.distanciaAte(emQuixada), closeTo(0, 0.01));
      expect(vm.distanciaAte(emFortaleza), closeTo(147.7, 0.5));
      expect(vm.distanciaAte(semCoordenadas), isNull);
      // Guarda a escolha, e não a posição: a cidade sai.
      expect(preferencias.guardadasPerto, [true]);
      expect(preferencias.guardadas.last, isNull);
    });

    test('para nas 5 páginas', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
        for (var numero = 1; numero <= 5; numero++)
          paginaDe([naClinica(10 + numero, 'P$numero', quixada, pontoDeQuixada)], pagina: numero, paginas: 7),
      ]);
      final vm = montar(falso, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();

      await vm.usarPertoDeMim();
      await pumpEventQueue();

      expect(falso.pedidosDeProfissionais.skip(1).map((p) => p.pagina), [1, 2, 3, 4, 5]);
      expect(vm.profissionais, hasLength(5));
      expect(vm.temMais, isFalse);
    });

    test('quem não tem coordenadas fica no fim, na ordem da API', () async {
      final outroSem = naClinica(5, 'Eva Sem Endereço', null, null);
      final falso = catalogo([
        paginaDe([emFortaleza]),
        paginaDe([semCoordenadas, emFortaleza, outroSem, emQuixada]),
      ]);
      final vm = montar(falso, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();

      await vm.usarPertoDeMim();
      await pumpEventQueue();

      expect(vm.profissionais, [emQuixada, emFortaleza, semCoordenadas, outroSem]);
    });

    test('sem a posição, nada muda e devolve false', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
      ]);
      final preferencias = PreferenciasFalsas(cidade: 3);
      final vm = montar(falso, preferencias: preferencias, localizacao: LocalizacaoFalsa());
      await vm.carregar();

      expect(await vm.usarPertoDeMim(), ResultadoDoPertoDeMim.semPosicao);
      await pumpEventQueue();

      expect(vm.pertoDeMim, isFalse);
      expect(vm.localizando, isFalse);
      expect(vm.cidade, fortaleza);
      expect(falso.pedidosDeProfissionais, hasLength(1));
      expect(preferencias.guardadasPerto, isEmpty);
    });

    test('os outros filtros continuam valendo: o plano escolhido vai em todas as páginas', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
        paginaDe([emFortaleza]),
        paginaDe([emQuixada], paginas: 2),
        paginaDe([emFortaleza], pagina: 2, paginas: 2),
      ]);
      final vm = montar(falso, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();
      await vm.usarPertoDeMim();
      await pumpEventQueue();

      vm.escolherPlano(3);
      await pumpEventQueue();

      expect(vm.pertoDeMim, isTrue);
      expect(falso.filtrosDosPedidos.skip(2), [
        (cidadeId: null, planoId: 3),
        (cidadeId: null, planoId: 3),
      ]);
      expect(vm.profissionais, [emQuixada, emFortaleza]);
    });

    test('uma página do meio que falha faz a lista falhar: meia lista esconderia o mais perto', () async {
      const erro = ErroDaApi.semConexao();
      final falso = catalogo([
        paginaDe([emFortaleza]),
        paginaDe([emFortaleza], paginas: 2),
        erro,
      ]);
      final vm = montar(falso, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();

      await vm.usarPertoDeMim();
      await pumpEventQueue();

      expect(vm.estado, EstadoDaCarga.falhou);
      expect(vm.erro, erro);
    });

    test('sem o serviço de localização, a opção não é oferecida', () async {
      final vm = montar(catalogo([]));

      expect(vm.ofereceLocalizacao, isFalse);
      expect(await vm.usarPertoDeMim(), ResultadoDoPertoDeMim.semPosicao);
    });
  });

  group('sair de "Perto de mim"', () {
    Future<(BuscaViewModel, CatalogoFalso, PreferenciasFalsas)> jaPerto(List<Object?> depois) async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
        paginaDe([emFortaleza, emQuixada]),
        ...depois,
      ]);
      final preferencias = PreferenciasFalsas();
      final vm = montar(falso, preferencias: preferencias, localizacao: LocalizacaoFalsa(posicao: pontoDeQuixada));
      await vm.carregar();
      await vm.usarPertoDeMim();
      await pumpEventQueue();
      return (vm, falso, preferencias);
    }

    test('escolher uma cidade desliga, guarda, e volta à ordem da API sem distância', () async {
      final (vm, falso, preferencias) = await jaPerto([
        paginaDe([emFortaleza, emQuixada]),
      ]);

      vm.escolherCidade(3);
      await pumpEventQueue();

      expect(vm.pertoDeMim, isFalse);
      expect(vm.cidade, fortaleza);
      expect(preferencias.guardadasPerto, [true, false]);
      expect(falso.filtrosDosPedidos.last, (cidadeId: 3, planoId: null));
      expect(vm.profissionais, [emFortaleza, emQuixada]);
      expect(vm.distanciaAte(emQuixada), isNull);
    });

    test('escolher "Todas as cidades" também desliga e busca de novo', () async {
      final (vm, falso, preferencias) = await jaPerto([
        paginaDe([emFortaleza, emQuixada]),
      ]);

      vm.escolherCidade(null);
      await pumpEventQueue();

      expect(vm.pertoDeMim, isFalse);
      expect(preferencias.guardadasPerto, [true, false]);
      expect(falso.pedidosDeProfissionais, hasLength(3));
      expect(vm.profissionais, [emFortaleza, emQuixada]);
    });

    test('escolher uma cidade enquanto a posição demora: vale a cidade', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
        paginaDe([emFortaleza]),
      ]);
      final localizacao = LocalizacaoFalsa(posicao: pontoDeQuixada)..posicaoDemorada = Completer<void>();
      final preferencias = PreferenciasFalsas();
      final vm = montar(falso, preferencias: preferencias, localizacao: localizacao);
      await vm.carregar();

      final escolha = vm.usarPertoDeMim();
      expect(vm.localizando, isTrue);
      vm.escolherCidade(3);
      expect(vm.localizando, isFalse);
      localizacao.posicaoDemorada!.complete();

      expect(await escolha, ResultadoDoPertoDeMim.outraEscolha);
      await pumpEventQueue();
      expect(vm.pertoDeMim, isFalse);
      expect(vm.cidade, fortaleza);
      expect(preferencias.guardadasPerto, isNot(contains(true)));
      expect(falso.filtrosDosPedidos.last, (cidadeId: 3, planoId: null));
    });
  });

  group('abrir com "Perto de mim" guardado', () {
    test('com a permissão, a primeira lista já sai ordenada, sem perguntar nada', () async {
      final falso = catalogo([
        paginaDe([emFortaleza, emQuixada]),
      ]);
      final localizacao = LocalizacaoFalsa(posicao: pontoDeQuixada);
      final vm = montar(falso, preferencias: PreferenciasFalsas(perto: true), localizacao: localizacao);

      await vm.carregar();

      expect(vm.pertoDeMim, isTrue);
      expect(falso.filtrosDosPedidos, [(cidadeId: null, planoId: null)]);
      expect(vm.profissionais, [emQuixada, emFortaleza]);
      expect(localizacao.pedidos, 0);
      expect(vm.avisoDaLocalizacao, isNull);
    });

    test('sem a posição: todas as cidades, sem ordem, um aviso, e a escolha fica guardada', () async {
      final falso = catalogo([
        paginaDe([emFortaleza, emQuixada]),
      ]);
      final preferencias = PreferenciasFalsas(perto: true);
      final vm = montar(falso, preferencias: preferencias, localizacao: LocalizacaoFalsa());

      await vm.carregar();

      expect(vm.pertoDeMim, isFalse);
      expect(vm.profissionais, [emFortaleza, emQuixada]);
      expect(vm.avisoDaLocalizacao, 'Não foi possível saber onde você está agora. A busca mostra todas as cidades.');
      expect(preferencias.guardadasPerto, isEmpty);
      expect(preferencias.perto, isTrue);

      vm.avisoMostrado();
      expect(vm.avisoDaLocalizacao, isNull);
    });

    test('com a permissão retirada: desliga, guarda, avisa, e não pede a permissão', () async {
      final falso = catalogo([
        paginaDe([emFortaleza, emQuixada]),
      ]);
      final preferencias = PreferenciasFalsas(perto: true);
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.naoPedida, posicao: pontoDeQuixada);
      final vm = montar(falso, preferencias: preferencias, localizacao: localizacao);

      await vm.carregar();

      expect(vm.pertoDeMim, isFalse);
      expect(preferencias.guardadasPerto, [false]);
      expect(localizacao.pedidos, 0);
      expect(localizacao.posicoesPedidas, 0);
      expect(vm.avisoDaLocalizacao, 'A permissão de localização foi retirada. A busca voltou a mostrar todas as cidades.');
      expect(falso.filtrosDosPedidos, [(cidadeId: null, planoId: null)]);
    });

    test('com a localização do celular desligada: o aviso diz isso', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
      ]);
      final preferencias = PreferenciasFalsas(perto: true);
      final vm = montar(
        falso,
        preferencias: preferencias,
        localizacao: LocalizacaoFalsa(estado: PermissaoDaLocalizacao.servicoDesligado),
      );

      await vm.carregar();

      expect(preferencias.guardadasPerto, [false]);
      expect(
        vm.avisoDaLocalizacao,
        'A localização do celular está desligada. A busca voltou a mostrar todas as cidades.',
      );
    });

    test('sem a escolha guardada, a localização nem é consultada', () async {
      final falso = catalogo([
        paginaDe([emFortaleza]),
      ]);
      final localizacao = LocalizacaoFalsa(posicao: pontoDeQuixada);
      final vm = montar(falso, preferencias: PreferenciasFalsas(), localizacao: localizacao);

      await vm.carregar();

      expect(vm.pertoDeMim, isFalse);
      expect(localizacao.consultas + localizacao.posicoesPedidas + localizacao.pedidos, 0);
    });
  });

  group('nas telas', () {
    /// A Busca de verdade, com a localização falsa. A primeira lista vem em
    /// todas as cidades; a de "Perto de mim", depois, na ordem da API.
    Future<(BuscaViewModel, CatalogoFalso)> montarBusca(
      WidgetTester tester, {
      LocalizacaoFalsa? localizacao,
      bool comLocalizacao = true,
      PreferenciasFalsas? preferencias,
    }) async {
      tester.view
        ..physicalSize = const Size(411, 1200)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final falso = catalogo([
        paginaDe([emFortaleza, emQuixada]),
        paginaDe([emFortaleza, semCoordenadas, emQuixeramobim, emQuixada]),
      ]);
      final vm = BuscaViewModel(
        falso,
        preferencias: preferencias,
        localizacao: comLocalizacao ? (localizacao ?? LocalizacaoFalsa(posicao: pontoDeQuixada)) : null,
      );
      addTearDown(vm.dispose);
      unawaited(vm.carregar());
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: ChangeNotifierProvider.value(value: vm, child: BuscaScreen(aoAbrir: (_) {})),
      ));
      await tester.pumpAndSettle();
      return (vm, falso);
    }

    Finder naFolha(String texto) => find.descendant(of: find.byType(BottomSheet), matching: find.text(texto));

    Future<void> abrirFolha(WidgetTester tester) async {
      await tester.tap(find.byType(SeletorDaCidade));
      await tester.pumpAndSettle();
    }

    Future<void> tocarPertoDeMim(WidgetTester tester) async {
      await abrirFolha(tester);
      await tester.tap(naFolha('Perto de mim'));
      await tester.pumpAndSettle();
    }

    testWidgets('"Perto de mim" é a primeira opção da folha, com o ícone, antes de "Todas as cidades"', (
      tester,
    ) async {
      await montarBusca(tester);
      await abrirFolha(tester);

      final perto = tester.getTopLeft(naFolha('Perto de mim')).dy;
      final todas = tester.getTopLeft(naFolha('Todas as cidades')).dy;
      final quixadaNaFolha = tester.getTopLeft(naFolha('Quixadá, CE')).dy;
      expect(perto, lessThan(todas));
      expect(todas, lessThan(quixadaNaFolha));
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.near_me_outlined)),
        findsOneWidget,
      );
    });

    testWidgets('sem como saber a posição, a folha não oferece "Perto de mim"', (tester) async {
      await montarBusca(tester, comLocalizacao: false);
      await abrirFolha(tester);

      expect(naFolha('Perto de mim'), findsNothing);
    });

    testWidgets('a primeira vez: a explicação, "Continuar", o pedido do Android, e a lista do mais perto ao mais longe', (
      tester,
    ) async {
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.naoPedida, posicao: pontoDeQuixada);
      final preferencias = PreferenciasFalsas();
      final (vm, falso) = await montarBusca(tester, localizacao: localizacao, preferencias: preferencias);

      await tocarPertoDeMim(tester);
      expect(find.text(TextosDoPertoDeMim.explicacaoTitulo), findsOneWidget);
      expect(find.text(TextosDoPertoDeMim.explicacao), findsOneWidget);
      expect(localizacao.pedidos, 0, reason: 'o Android só pergunta depois da explicação');
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(localizacao.pedidos, 1);
      expect(vm.pertoDeMim, isTrue);
      expect(falso.filtrosDosPedidos.last, (cidadeId: null, planoId: null));
      expect(find.text('Perto de mim'), findsOneWidget);
      expect(find.bySemanticsLabel('Cidade: perto de mim. Trocar'), findsOneWidget);
      expect(find.text('4 profissionais, do mais perto ao mais longe'), findsOneWidget);
      // O card diz a cidade e a distância; a ordem é a da distância.
      expect(find.text('Quixadá, CE · a menos de 1\u00a0km'), findsOneWidget);
      expect(find.text('Quixeramobim, CE · a 40\u00a0km'), findsOneWidget);
      expect(find.text('Fortaleza, CE · a 148\u00a0km'), findsOneWidget);
      final nomes = [
        for (final card in tester.widgetList<CardDoProfissional>(find.byType(CardDoProfissional)))
          card.profissional.nome,
      ];
      expect(nomes, ['Ana Quixadá', 'Bruno Quixeramobim', 'Carla Fortaleza', 'Davi Sem Endereço']);
      expect(preferencias.guardadasPerto, [true]);
    });

    testWidgets('"Agora não" na explicação não pede nada, e nada muda', (tester) async {
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.naoPedida, posicao: pontoDeQuixada);
      final (vm, falso) = await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      expect(localizacao.pedidos, 0);
      expect(localizacao.posicoesPedidas, 0);
      expect(vm.pertoDeMim, isFalse);
      expect(falso.pedidosDeProfissionais, hasLength(1));
    });

    testWidgets('com a permissão já dada, vai direto, sem a explicação', (tester) async {
      final localizacao = LocalizacaoFalsa(posicao: pontoDeQuixada);
      final (vm, _) = await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);

      expect(find.text(TextosDoPertoDeMim.explicacaoTitulo), findsNothing);
      expect(localizacao.pedidos, 0);
      expect(vm.pertoDeMim, isTrue);
    });

    testWidgets('recusada no Android: o aviso, e a busca continua por cidade', (tester) async {
      final localizacao = LocalizacaoFalsa(
        estado: PermissaoDaLocalizacao.naoPedida,
        respostaAoPedido: PermissaoDaLocalizacao.negada,
        posicao: pontoDeQuixada,
      );
      final (vm, _) = await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      await tester.tap(find.text('Continuar'));
      await tester.pumpAndSettle();

      expect(find.text(TextosDoPertoDeMim.negada), findsOneWidget);
      expect(vm.pertoDeMim, isFalse);
      expect(localizacao.posicoesPedidas, 0);
    });

    testWidgets('bloqueada de vez: o diálogo leva às configurações do aplicativo', (tester) async {
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.negadaDeVez);
      await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      expect(find.text(TextosDoPertoDeMim.bloqueada), findsOneWidget);
      await tester.tap(find.text('Abrir configurações'));
      await tester.pumpAndSettle();

      expect(localizacao.configuracoesAbertas, 1);
      expect(localizacao.pedidos, 0);
    });

    testWidgets('a localização do celular desligada: o diálogo leva às configurações dela', (tester) async {
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.servicoDesligado);
      await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      expect(find.text(TextosDoPertoDeMim.desligada), findsOneWidget);
      await tester.tap(find.text('Abrir configurações da localização'));
      await tester.pumpAndSettle();

      expect(localizacao.configuracoesDaLocalizacaoAbertas, 1);
    });

    testWidgets('a posição não vem: o aviso, e nada muda', (tester) async {
      final (vm, _) = await montarBusca(tester, localizacao: LocalizacaoFalsa());

      await tocarPertoDeMim(tester);

      expect(find.text(TextosDoPertoDeMim.semPosicao), findsOneWidget);
      expect(vm.pertoDeMim, isFalse);
      expect(find.text('Todas as cidades'), findsOneWidget);
    });

    testWidgets('enquanto a posição demora, o seletor diz que está procurando', (tester) async {
      final localizacao = LocalizacaoFalsa(posicao: pontoDeQuixada)..posicaoDemorada = Completer<void>();
      await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      expect(find.text('Procurando você…'), findsOneWidget);
      expect(find.bySemanticsLabel('Cidade: procurando onde você está'), findsOneWidget);

      localizacao.posicaoDemorada!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Perto de mim'), findsOneWidget);
    });

    testWidgets('com "Perto de mim" valendo, a folha o marca, e não "Todas as cidades"', (tester) async {
      await montarBusca(tester);
      await tocarPertoDeMim(tester);
      await abrirFolha(tester);

      final marcados = find.descendant(of: find.byType(BottomSheet), matching: find.byIcon(Icons.check));
      expect(marcados, findsOneWidget);
      final perto = tester.getCenter(naFolha('Perto de mim')).dy;
      expect(tester.getCenter(marcados).dy, closeTo(perto, 30));
    });

    testWidgets('o card lê a cidade e a distância numa frase, em quilômetros', (tester) async {
      final semantica = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: temaDoApp(),
        home: Scaffold(
          body: CardDoProfissional(profissional: emQuixada, aoTocar: () {}, mostrarCidade: true, distancia: 2.34),
        ),
      ));

      expect(find.text('Quixadá, CE · a 2,3\u00a0km'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Quixadá, CE, a 2,3 quilômetros')), findsOneWidget);
      semantica.dispose();
    });

    testWidgets('a folha com "Perto de mim", nos quatro aparelhos', (tester) async {
      await montarBusca(tester);
      await abrirFolha(tester);

      for (final aparelho in aparelhos) {
        await usarAparelho(tester, aparelho);
        await conferirAcessibilidade(
          tester,
          lista: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
          motivo: aparelho.nome,
        );
      }
    });

    testWidgets('a explicação e o diálogo das configurações, nos quatro aparelhos', (tester) async {
      final localizacao = LocalizacaoFalsa(estado: PermissaoDaLocalizacao.naoPedida, posicao: pontoDeQuixada);
      await montarBusca(tester, localizacao: localizacao);

      await tocarPertoDeMim(tester);
      await conferirNosQuatroAparelhos(tester);
      await tester.tap(find.text('Agora não'));
      await tester.pumpAndSettle();

      localizacao.estado = PermissaoDaLocalizacao.negadaDeVez;
      await usarAparelho(tester, aparelhoEmPe);
      await tocarPertoDeMim(tester);
      expect(find.text(TextosDoPertoDeMim.bloqueada), findsOneWidget);
      await conferirNosQuatroAparelhos(tester);
    });

    testWidgets('a Busca ordenada, com as distâncias, nos quatro aparelhos', (tester) async {
      await montarBusca(tester);
      await tocarPertoDeMim(tester);

      await conferirNosQuatroAparelhos(tester);
    });
  });
}
