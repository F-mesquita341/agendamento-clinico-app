import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_catalogo.dart';
import '../../domain/models/data_civil.dart';
import '../../domain/models/erro_da_api.dart';
import '../../domain/models/horario.dart';
import '../../domain/models/profissional.dart';
import '../agendamento/etapa_do_agendamento.dart';
import '../agendamento/resumo_screen.dart';
import '../agendamento/resumo_view_model.dart';
import '../comum/atalhos_da_clinica.dart';
import '../comum/avatar.dart';
import '../comum/botoes.dart';
import '../comum/datas.dart';
import '../comum/espaco.dart';
import '../comum/estados_de_carga.dart';
import '../comum/retorno.dart';
import '../comum/rodape.dart';
import '../comum/textos.dart';
import 'horarios_view_model.dart';

/// A tela de um profissional. O view model nasce na rota, e não na tela: o
/// resumo da consulta volta para ela com o dia e o horário ainda escolhidos
/// (checklist, item 3.1).
Route<void> rotaDoProfissional(Profissional profissional, {DateTime Function() relogio = DateTime.now}) {
  return MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) =>
          HorariosViewModel(contexto.read<RepositorioDoCatalogo>(), profissional, agora: relogio)..carregar(),
      child: const ProfissionalScreen(),
    ),
  );
}

/// Profissional e horários, numa tela só: quem atende e onde, com o contato da
/// clínica (checklist, itens 2.9 e 10.3); quanto custa, antes de escolher o
/// horário (5.10); os dias e os horários livres (1.6 e 5.2); e, fixo no
/// rodapé, o que foi escolhido (6.1), com o "Continuar".
class ProfissionalScreen extends StatelessWidget {
  const ProfissionalScreen({super.key});

  /// Abre o resumo do horário escolhido. Sem horário, diz o que falta.
  static Future<void> _continuar(BuildContext context, HorariosViewModel vm) async {
    final horario = vm.horarioEscolhido;
    if (horario == null) {
      mostrarRetorno(context, TipoDeRetorno.aviso, 'Escolha um horário para continuar.');
      return;
    }
    final desfecho = await Navigator.of(context).push(
      rotaDoResumo(vm.profissional, horario, hoje: vm.hoje, relogio: vm.relogio),
    );
    if (desfecho is Conflito && context.mounted) await _explicarConflito(context, vm, horario, desfecho.erro);
  }

  /// O fallback do lock otimista (TCC, Seção 3.8.3; checklist, item 9.1): o
  /// horário sai da grade, a grade é recarregada, e só então a folha explica,
  /// com a mensagem da API e os horários livres mais próximos.
  static Future<void> _explicarConflito(
    BuildContext context,
    HorariosViewModel vm,
    Horario perdido,
    ErroDaApi erro,
  ) async {
    vm.perderHorario(perdido);
    await vm.atualizar();
    if (!context.mounted) return;

    final atualizou = vm.erroAoAtualizar == null;
    final escolhido = await showModalBottomSheet<Horario>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FolhaDoConflito(
        mensagem: erro.mensagem,
        falhaAoAtualizar: vm.erroAoAtualizar,
        sugestoes: atualizou ? vm.proximosLivres(aPartirDe: perdido.dia) : const [],
        hoje: vm.hoje,
      ),
    );
    if (escolhido == null || !context.mounted) return;
    vm.escolherDia(escolhido.dia);
    vm.escolherHorario(escolhido);
    // Como no modelo: escolher uma sugestão já leva ao resumo.
    await _continuar(context, vm);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<HorariosViewModel>();
    final dia = vm.diaEscolhido;

    return Scaffold(
      appBar: AppBar(title: const Text('Escolher horário'), bottom: etapaDoAgendamento(context, 1)),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: vm.atualizar,
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: Espaco.medio),
            children: [
              ComMargem(child: _Cabecalho(profissional: vm.profissional)),
              const SizedBox(height: Espaco.medio),
              ComMargem(child: _ClinicaEValor(profissional: vm.profissional)),
              const SizedBox(height: Espaco.grande),
              ...switch (vm.estado) {
                EstadoDaCarga.carregando => [IndicadorDeCarga(demorando: vm.demorando)],
                EstadoDaCarga.falhou => [
                    FalhaDeCarga(mensagem: vm.erro!.mensagem, tentarDeNovo: vm.carregar),
                  ],
                EstadoDaCarga.pronto => _grade(context, vm, dia),
              },
            ],
          ),
        ),
      ),
      // O resumo da escolha fica sempre fixo embaixo, mesmo deitado: é ele que
      // diz o que foi escolhido (checklist, itens 6.1 e 10.8). Na barra de
      // baixo da tela, um aviso fica acima dele, e não sobre o "Continuar".
      bottomNavigationBar: vm.estado == EstadoDaCarga.pronto && dia != null
          ? _Resumo(vm: vm, aoContinuar: () => _continuar(context, vm))
          : null,
    );
  }

  List<Widget> _grade(BuildContext context, HorariosViewModel vm, DataCivil? dia) {
    final tema = Theme.of(context);
    final apoio = tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: tema.colorScheme.onSurfaceVariant);
    final doDia = dia == null ? const <Horario>[] : vm.horariosDe(dia);
    final manha = [for (final horario in doDia) if (horario.deManha) horario];
    final tarde = [for (final horario in doDia) if (!horario.deManha) horario];

    return [
      // Com a grade na tela, uma espera longa — atualizar, ver mais dias — também
      // avisa.
      if (vm.demorando) ...[
        const ComMargem(child: Aviso(tipo: TipoDeRetorno.aviso, texto: Textos.servidorDemorando)),
        const SizedBox(height: Espaco.medio),
      ],
      if (vm.erroAoAtualizar case final erro?) ...[
        ComMargem(
          child: Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível atualizar. ${erro.mensagem}'),
        ),
        const SizedBox(height: Espaco.medio),
      ],
      ComMargem(
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: Espaco.pequeno,
          children: [
            Semantics(header: true, child: Text('Escolha o dia', style: tema.textTheme.titleMedium)),
            // O mês do dia escolhido: a faixa vai até 60 dias, e cruza meses.
            Text(comInicialMaiuscula(mesDoAno(dia ?? vm.hoje, hoje: vm.hoje)), style: apoio),
          ],
        ),
      ),
      const SizedBox(height: Espaco.pequeno),
      _FaixaDeDias(vm: vm),
      if (vm.erroAoVerMaisDias case final erro?) ...[
        const SizedBox(height: Espaco.medio),
        ComMargem(
          child: Aviso(tipo: TipoDeRetorno.erro, texto: 'Não foi possível ver mais dias. ${erro.mensagem}'),
        ),
      ],
      const SizedBox(height: Espaco.grande),
      if (dia == null)
        // Nenhum dia da grade tem horário. Com mais dias a caminho, a espera;
        // senão, o porquê e a saída.
        if (vm.vendoMaisDias)
          const IndicadorDeCarga(demorando: false)
        else
          EstadoVazio(
            icone: Icons.event_busy_outlined,
            titulo: 'Sem horários livres',
            texto: 'Este profissional não tem horários livres nos próximos ${vm.quantosDias} dias.',
            saida: vm.podeVerMaisDias ? (rotulo: 'Ver mais dias', aoTocar: vm.verMaisDias) : null,
          )
      else ...[
        ComMargem(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('Horários livres', style: tema.textTheme.titleMedium)),
              Text(diaPorInteiro(dia, hoje: vm.hoje), style: apoio),
            ],
          ),
        ),
        if (vm.horarioPerdido case final perdido?) ...[
          const SizedBox(height: Espaco.medio),
          ComMargem(
            child: Aviso(
              tipo: TipoDeRetorno.aviso,
              texto: 'O horário de ${diaCurto(perdido.dia, hoje: vm.hoje)} às ${perdido.hora} '
                  'não está mais livre. Escolha outro.',
            ),
          ),
        ],
        if (manha.isNotEmpty) _Turno(titulo: 'Manhã', icone: Icons.wb_sunny_outlined, horarios: manha, vm: vm),
        if (tarde.isNotEmpty) _Turno(titulo: 'Tarde', icone: Icons.wb_twilight_outlined, horarios: tarde, vm: vm),
      ],
    ];
  }
}

/// Quem atende: iniciais, nome, especialidade e o registro no conselho, como a
/// clínica o cadastrou — sem selo de "verificado", que o aplicativo não confere.
class _Cabecalho extends StatelessWidget {
  const _Cabecalho({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final apoio = TextStyle(color: tema.colorScheme.onSurfaceVariant);
    return Row(
      children: [
        AvatarDeIniciais(nome: profissional.nome, tamanho: 72),
        const SizedBox(width: Espaco.medio),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(profissional.nome, style: tema.textTheme.headlineSmall)),
              if (profissional.especialidade case final especialidade?) Text(especialidade.nome, style: apoio),
              Text(profissional.registroConselho, style: tema.textTheme.bodySmall!.merge(apoio)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Onde é a consulta, com os atalhos para chegar e para ligar, e quanto ela
/// custa. Cada atalho só existe se a clínica cadastrou o dado dele.
class _ClinicaEValor extends StatelessWidget {
  const _ClinicaEValor({required this.profissional});

  final Profissional profissional;

  @override
  Widget build(BuildContext context) {
    final clinica = profissional.clinica;
    return Card(
      child: Column(
        children: [
          if (clinica != null) ...[
            _Linha(
              icone: Icons.location_on_outlined,
              titulo: clinica.nome,
              textos: [?clinica.endereco, ?clinica.telefone],
            ),
            if (clinica.endereco != null || clinica.telefone != null) ...[
              const Divider(height: 1),
              AtalhosDaClinica(clinica: clinica),
            ],
            const Divider(height: 1),
          ],
          _Linha(
            icone: Icons.payments_outlined,
            titulo: '${semQuebra(profissional.valorFormatado)} por consulta',
            textos: const ['Pagamento antecipado, feito pelo aplicativo.'],
          ),
        ],
      ),
    );
  }
}

class _Linha extends StatelessWidget {
  const _Linha({required this.icone, required this.titulo, required this.textos});

  final IconData icone;
  final String titulo;
  final List<String> textos;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Espaco.medio),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, color: cores.primary),
          const SizedBox(width: Espaco.medio),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: tema.textTheme.titleSmall),
                for (final texto in textos)
                  Text(texto, style: tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: cores.onSurfaceVariant)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A faixa de dias, que rola para o lado: cada dia diz quantos horários livres
/// tem, e o que não tem nenhum fica desativado.
class _FaixaDeDias extends StatefulWidget {
  const _FaixaDeDias({required this.vm});

  final HorariosViewModel vm;

  @override
  State<_FaixaDeDias> createState() => _FaixaDeDiasState();
}

class _FaixaDeDiasState extends State<_FaixaDeDias> {
  final _rolagem = ScrollController();
  final _chaveDoEscolhido = GlobalKey();
  DataCivil? _ultimoMostrado;

  @override
  void dispose() {
    _rolagem.dispose();
    super.dispose();
  }

  /// Traz o dia escolhido para dentro da faixa, se ele está fora: o primeiro
  /// dia com horário pode estar adiante do que cabe na tela.
  void _mostrarOEscolhido() {
    final escolhido = _chaveDoEscolhido.currentContext?.findRenderObject();
    if (escolhido == null) return;
    for (final borda in const [
      ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ScrollPositionAlignmentPolicy.keepVisibleAtStart,
    ]) {
      _rolagem.position.ensureVisible(escolhido, alignmentPolicy: borda);
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = widget.vm;
    final largura = MediaQuery.textScalerOf(context).scale(76);
    if (vm.diaEscolhido != _ultimoMostrado) {
      _ultimoMostrado = vm.diaEscolhido;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _mostrarOEscolhido();
      });
    }

    return SingleChildScrollView(
      controller: _rolagem,
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Espaco.margem),
      // Todos os dias com a altura do mais alto.
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Espaco.pequeno,
          children: [
            for (final dia in vm.dias)
              SizedBox(
                key: dia == vm.diaEscolhido ? _chaveDoEscolhido : null,
                width: largura,
                child: _Dia(
                  dia: dia,
                  hoje: vm.hoje,
                  livres: vm.horariosDe(dia).length,
                  escolhido: dia == vm.diaEscolhido,
                  aoEscolher: () => vm.escolherDia(dia),
                ),
              ),
            if (vm.vendoMaisDias)
              SizedBox(
                width: largura,
                child: Center(child: Semantics(label: Textos.carregando, child: const CircularProgressIndicator())),
              )
            // Sem horário em dia nenhum, o aviso embaixo já oferece ver mais dias.
            else if (vm.podeVerMaisDias && vm.diaEscolhido != null)
              SizedBox(
                width: largura,
                child: OutlinedButton(
                  onPressed: vm.verMaisDias,
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.all(4),
                    textStyle: Theme.of(context).textTheme.labelMedium,
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [Icon(Icons.add), Text('Ver mais dias', textAlign: TextAlign.center)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Dia extends StatelessWidget {
  const _Dia({
    required this.dia,
    required this.hoje,
    required this.livres,
    required this.escolhido,
    required this.aoEscolher,
  });

  final DataCivil dia;
  final DataCivil hoje;
  final int livres;
  final bool escolhido;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final temHorario = livres > 0;
    final frente = escolhido
        ? cores.onPrimary
        : temHorario
            ? cores.onSurface
            : cores.onSurfaceVariant;
    final relativo = diaRelativo(dia, hoje: hoje);
    final quantos = switch (livres) {
      0 => 'sem horários',
      1 => '1 horário',
      _ => '$livres horários',
    };

    // Um botão só para o leitor de tela, que lê o dia inteiro e não as três
    // linhas soltas: "Amanhã, quinta-feira, 15/10, 3 horários".
    return Semantics(
      container: true,
      excludeSemantics: true,
      button: true,
      enabled: temHorario,
      selected: escolhido,
      label: '${diaPorInteiro(dia, hoje: hoje)}, $quantos',
      onTap: temHorario ? aoEscolher : null,
      child: Material(
        color: escolhido
            ? cores.primary
            : temHorario
                ? cores.surfaceContainerLowest
                : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: escolhido
                ? cores.primary
                : temHorario
                    ? cores.outline
                    : cores.outlineVariant,
            width: 1.5,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Dia sem horário não responde ao toque.
          onTap: temHorario ? aoEscolher : null,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 88),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: Espaco.pequeno),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // O escolhido leva o ícone, além da cor (checklist, item 8.7).
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        if (escolhido) Icon(Icons.check, size: 16, color: frente),
                        Text(
                          relativo ?? diaAbreviado(dia),
                          style: tema.textTheme.labelMedium!.copyWith(color: frente),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    diaEMesSemAno(dia),
                    style: tema.textTheme.titleMedium!.copyWith(fontSize: 20, color: frente),
                  ),
                  Text(
                    quantos,
                    textAlign: TextAlign.center,
                    style: tema.textTheme.labelSmall!.copyWith(color: frente),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Os horários de um turno. Separar manhã e tarde dispensa um filtro de turno
/// (checklist, item 7.5).
class _Turno extends StatelessWidget {
  const _Turno({required this.titulo, required this.icone, required this.horarios, required this.vm});

  final String titulo;
  final IconData icone;
  final List<Horario> horarios;
  final HorariosViewModel vm;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final escala = MediaQuery.textScalerOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Espaco.margem, Espaco.medio, Espaco.margem, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            spacing: Espaco.pequeno,
            children: [
              Icon(icone, size: 20, color: cores.onSurfaceVariant),
              Semantics(
                header: true,
                child: Text(
                  titulo,
                  style: tema.textTheme.titleSmall!.copyWith(fontSize: 15, color: cores.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: Espaco.pequeno),
          // Colunas de mesma largura, tantas quantas cabem: quatro num
          // aparelho largo, três num comum, menos com o texto ampliado.
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: escala.scale(110),
              mainAxisExtent: max(48, escala.scale(48)),
              crossAxisSpacing: Espaco.pequeno,
              mainAxisSpacing: Espaco.pequeno,
            ),
            itemCount: horarios.length,
            itemBuilder: (context, indice) {
              final horario = horarios[indice];
              return _BotaoDeHorario(
                horario: horario,
                escolhido: horario.id == vm.horarioEscolhido?.id,
                aoEscolher: () => vm.escolherHorario(horario),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _BotaoDeHorario extends StatelessWidget {
  const _BotaoDeHorario({required this.horario, required this.escolhido, required this.aoEscolher});

  final Horario horario;
  final bool escolhido;
  final VoidCallback aoEscolher;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final frente = escolhido ? cores.onPrimary : cores.onSurface;
    return Material(
      color: escolhido ? cores.primary : cores.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: escolhido ? cores.primary : cores.outline, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: MergeSemantics(
        child: Semantics(
          button: true,
          selected: escolhido,
          child: InkWell(
            onTap: aoEscolher,
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Espaco.pequeno),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 4,
                    children: [
                      // O escolhido leva o ícone, além da cor (checklist, item 1.6).
                      if (escolhido) Icon(Icons.check, size: 18, color: frente),
                      Text(
                        horario.hora,
                        style: tema.textTheme.labelLarge!.copyWith(
                          fontSize: 16,
                          color: frente,
                          // Dígitos de mesma largura: as colunas ficam alinhadas.
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// O resumo fixo no rodapé: o que foi escolhido, sempre à vista, sem precisar
/// rolar a tela de volta (checklist, itens 6.1 e 10.8), e o "Continuar".
class _Resumo extends StatelessWidget {
  const _Resumo({required this.vm, required this.aoContinuar});

  final HorariosViewModel vm;
  final VoidCallback aoContinuar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final horario = vm.horarioEscolhido;
    final (titulo, apoio) = horario == null
        ? ('Escolha um horário', 'Toque em um horário livre')
        : (
            '${comInicialMaiuscula(diaCurto(horario.dia, hoje: vm.hoje))} · ${horario.hora} · '
                '${horario.duracaoMinutos} min',
            '${vm.profissional.nome} · ${semQuebra(vm.profissional.valorFormatado)}',
          );

    // Com a fonte grande, o texto e o botão ficam um embaixo do outro, e o
    // texto não fica espremido numa coluna estreita. Para a grade não sumir
    // atrás do rodapé numa tela pequena, fica só a escolha: quem atende e o
    // valor estão no topo da tela, e voltam no resumo.
    final fonteGrande = MediaQuery.textScalerOf(context).scale(1) > 1.3;

    // liveRegion: o leitor de tela anuncia a escolha quando ela muda. O botão
    // fica fora, para não ser anunciado a cada troca.
    final escolha = Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(titulo, style: tema.textTheme.titleSmall!.copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
          if (!fonteGrande) Text(apoio, style: tema.textTheme.bodySmall!.copyWith(fontSize: 15, color: cores.onSurfaceVariant)),
        ],
      ),
    );

    // Sempre tocável, como no modelo: sem horário, o toque diz o que falta.
    return RodapeDeAcao(
      child: fonteGrande
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Espaco.medio,
              children: [escolha, BotaoPrincipal(rotulo: 'Continuar', aoTocar: aoContinuar)],
            )
          : Row(
              spacing: Espaco.medio,
              children: [
                Expanded(child: escolha),
                FilledButton(onPressed: aoContinuar, child: const Text('Continuar')),
              ],
            ),
    );
  }
}

/// "Esse horário não está mais livre": a mensagem da API, se a grade já foi
/// atualizada, e os horários livres mais próximos — tocar num deles leva
/// direto ao resumo, como no modelo. Devolve o horário sugerido escolhido.
class _FolhaDoConflito extends StatelessWidget {
  const _FolhaDoConflito({
    required this.mensagem,
    required this.falhaAoAtualizar,
    required this.sugestoes,
    required this.hoje,
  });

  final String mensagem;
  final ErroDaApi? falhaAoAtualizar;
  final List<Horario> sugestoes;
  final DataCivil hoje;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final texto = tema.textTheme.bodyLarge;
    final porLinha = MediaQuery.textScalerOf(context).scale(1) > 1.3 ? 1 : 2;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Espaco.grande, 0, Espaco.grande, Espaco.grande),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: Espaco.medio,
          children: [
            Icon(Icons.event_busy_outlined, size: 32, color: tema.colorScheme.primary),
            Semantics(
              header: true,
              child: Text(
                'Esse horário não está mais livre',
                style: tema.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            if (falhaAoAtualizar case final falha?) ...[
              Text(mensagem, style: texto),
              Aviso(
                tipo: TipoDeRetorno.erro,
                texto: 'Não foi possível atualizar a lista de horários. ${falha.mensagem}',
              ),
            ] else
              Text('$mensagem A lista de horários já foi atualizada.', style: texto),
            if (sugestoes.isNotEmpty) ...[
              Text('Horários livres mais próximos', style: tema.textTheme.titleSmall),
              LayoutBuilder(
                builder: (contexto, limites) {
                  final largura = (limites.maxWidth - Espaco.pequeno * (porLinha - 1)) / porLinha;
                  return Wrap(
                    spacing: Espaco.pequeno,
                    runSpacing: Espaco.pequeno,
                    children: [
                      for (final horario in sugestoes)
                        SizedBox(
                          width: largura,
                          child: _Sugestao(
                            horario: horario,
                            hoje: hoje,
                            aoTocar: () => Navigator.of(context).pop(horario),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
            BotaoPrincipal(rotulo: 'Ver todos os horários', aoTocar: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

/// Um horário sugerido depois do conflito: a hora, que é o que distingue um do
/// outro, e embaixo o dia. Em duas linhas de propósito — numa só, em meia
/// largura, a hora quebraria sozinha para a linha de baixo.
class _Sugestao extends StatelessWidget {
  const _Sugestao({required this.horario, required this.hoje, required this.aoTocar});

  final Horario horario;
  final DataCivil hoje;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(horizontal: Espaco.pequeno, vertical: Espaco.pequeno),
      ),
      onPressed: aoTocar,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            horario.hora,
            style: tema.textTheme.labelLarge!.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          Text(
            comInicialMaiuscula(diaCurto(horario.dia, hoje: hoje)),
            textAlign: TextAlign.center,
            style: tema.textTheme.bodySmall!.copyWith(fontSize: 14, color: tema.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
