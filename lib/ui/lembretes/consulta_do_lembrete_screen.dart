import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_de_consultas.dart';
import '../../domain/models/erro_da_api.dart';
import '../comum/defeitos.dart';
import '../comum/estados_de_carga.dart';
import '../consultas/detalhes_da_consulta_screen.dart';
import '../consultas/situacao_da_consulta.dart';
import '../shell/abas_do_shell.dart';

/// A consulta de um lembrete tocado (checklist, item 7.2). O lembrete só traz
/// o id: a consulta é lida da API — com o status de agora, que pode ter mudado
/// desde o envio —, e os detalhes tomam o lugar desta tela.
Route<void> rotaDoLembrete(int consultaId, {DateTime Function() relogio = DateTime.now}) {
  return MaterialPageRoute<void>(
    builder: (_) => ChangeNotifierProvider(
      create: (contexto) => ConsultaDoLembreteViewModel(consultaId, consultas: contexto.read<RepositorioDeConsultas>())
        ..carregar(),
      child: ConsultaDoLembreteScreen(relogio: relogio),
    ),
  );
}

/// A leitura da consulta lembrada.
class ConsultaDoLembreteViewModel extends ChangeNotifier {
  ConsultaDoLembreteViewModel(
    this.consultaId, {
    required RepositorioDeConsultas consultas,
    this.esperaAteAvisar = const Duration(seconds: 4),
  }) : _consultas = consultas;

  final int consultaId;
  final RepositorioDeConsultas _consultas;
  final Duration esperaAteAvisar;

  ConsultaNaLista? _item;
  ErroDaApi? _erro;
  bool _naoEncontrada = false;
  late final _aviso = AvisoDeDemora(espera: esperaAteAvisar, aoMudar: _notificar);
  bool _descartado = false;

  /// A consulta, pronta para os detalhes.
  ConsultaNaLista? get item => _item;

  /// A consulta não é desta conta: o lembrete veio para outra que usou este
  /// aparelho, ou ela não existe mais.
  bool get naoEncontrada => _naoEncontrada;
  ErroDaApi? get erro => _erro;
  bool get demorando => _aviso.demorando;

  Future<void> carregar() async {
    _erro = null;
    _naoEncontrada = false;
    _aviso.iniciar();
    _notificar();
    try {
      final consulta = await _consultas.consulta(consultaId);
      _item = naLista(consulta);
      // Sem o horário ou o profissional, a API respondeu fora do contrato.
      if (_item == null) _erro = const ErroDaApi.respostaInesperada(200);
    } on ErroDaApi catch (erro) {
      // 404 sem ação: não é desta conta. A tela não diz nada da consulta.
      if (erro.status == 404 && erro.acao == AcaoSugerida.nenhuma) {
        _naoEncontrada = true;
      } else {
        _erro = erro;
      }
    } catch (erro, pilha) {
      relatarDefeito(erro, pilha, 'ao abrir a consulta do lembrete');
      _erro = const ErroDaApi.falhaNoAplicativo();
    } finally {
      _aviso.parar();
      _notificar();
    }
  }

  void _notificar() {
    if (!_descartado) notifyListeners();
  }

  @override
  void dispose() {
    _descartado = true;
    _aviso.parar();
    super.dispose();
  }
}

class ConsultaDoLembreteScreen extends StatefulWidget {
  const ConsultaDoLembreteScreen({super.key, required this.relogio});

  final DateTime Function() relogio;

  @override
  State<ConsultaDoLembreteScreen> createState() => _ConsultaDoLembreteScreenState();
}

class _ConsultaDoLembreteScreenState extends State<ConsultaDoLembreteScreen> {
  late final ConsultaDoLembreteViewModel _vm;
  bool _trocou = false;

  @override
  void initState() {
    super.initState();
    _vm = context.read<ConsultaDoLembreteViewModel>()..addListener(_aoMudar);
  }

  @override
  void dispose() {
    _vm.removeListener(_aoMudar);
    super.dispose();
  }

  /// Com a consulta lida, os detalhes tomam o lugar desta tela: voltar deles
  /// leva ao Início.
  void _aoMudar() {
    final item = _vm.item;
    if (item == null || _trocou || !mounted) return;
    _trocou = true;
    unawaited(Navigator.of(context).pushReplacement(rotaDosDetalhes(item, relogio: widget.relogio)));
  }

  void _verMinhasConsultas() {
    context.read<AbasDoShell>().mostrar(AbaDoShell.consultas);
    Navigator.of(context).popUntil((rota) => rota.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ConsultaDoLembreteViewModel>();
    final erro = vm.erro;
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta')),
      body: SafeArea(
        child: vm.naoEncontrada
            ? SingleChildScrollView(
                child: EstadoVazio(
                  icone: Icons.event_busy_outlined,
                  titulo: 'Não encontramos esta consulta nesta conta.',
                  texto: 'O lembrete pode ser de outra conta que já usou este aparelho.',
                  saida: (rotulo: 'Ver minhas consultas', aoTocar: _verMinhasConsultas),
                ),
              )
            : erro != null
                ? FalhaDeCarga(mensagem: erro.mensagem, tentarDeNovo: vm.carregar)
                : IndicadorDeCarga(demorando: vm.demorando),
      ),
    );
  }
}
