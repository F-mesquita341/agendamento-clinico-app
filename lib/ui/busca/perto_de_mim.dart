import 'package:flutter/material.dart';

import '../../data/services/servico_de_localizacao.dart';
import '../comum/confirmacao.dart';
import '../comum/retorno.dart';
import 'busca_view_model.dart';

/// Os textos de "Perto de mim", num lugar só: a tela, os testes e o "Como
/// funciona" dizem a mesma coisa.
abstract final class TextosDoPertoDeMim {
  static const explicacaoTitulo = 'Usar a sua localização?';
  static const explicacao = 'O Marcaí usa a sua localização aproximada só para mostrar os profissionais mais '
      'perto. Ela fica no seu celular: não é enviada nem guardada.';
  static const negada = 'Sem a permissão, a busca continua por cidade.';
  static const bloqueadaTitulo = 'A localização está bloqueada';
  static const bloqueada =
      'A localização está bloqueada para o Marcaí. Para usar Perto de mim, permita nas configurações do celular.';
  static const desligadaTitulo = 'A localização está desligada';
  static const desligada = 'A localização do celular está desligada. Para usar Perto de mim, ligue a localização.';
  static const semPosicao = 'Não foi possível saber onde você está agora. Tente de novo em instantes.';
}

/// A pessoa tocou em "Perto de mim". Antes do diálogo do Android, o aplicativo
/// explica para que quer a localização; recusada, diz o que fazer; bloqueada
/// ou desligada, leva às configurações. Só com a permissão dada pede a posição.
Future<void> escolherPertoDeMim(BuildContext context, BuscaViewModel vm) async {
  final servico = vm.localizacao;
  if (servico == null) return;
  var permissao = await servico.permissao();
  if (!context.mounted) return;

  if (permissao == PermissaoDaLocalizacao.naoPedida) {
    final segue = await confirmar(
      context,
      titulo: TextosDoPertoDeMim.explicacaoTitulo,
      texto: TextosDoPertoDeMim.explicacao,
      acao: 'Continuar',
      desistir: 'Agora não',
    );
    if (!segue || !context.mounted) return;
    permissao = await servico.pedirPermissao();
    if (!context.mounted) return;
  }

  switch (permissao) {
    case PermissaoDaLocalizacao.concedida:
      final resultado = await vm.usarPertoDeMim();
      if (resultado == ResultadoDoPertoDeMim.semPosicao && context.mounted) {
        mostrarRetorno(context, TipoDeRetorno.aviso, TextosDoPertoDeMim.semPosicao);
      }
    case PermissaoDaLocalizacao.naoPedida:
    case PermissaoDaLocalizacao.negada:
      mostrarRetorno(context, TipoDeRetorno.aviso, TextosDoPertoDeMim.negada);
    case PermissaoDaLocalizacao.negadaDeVez:
      final abrir = await confirmar(
        context,
        titulo: TextosDoPertoDeMim.bloqueadaTitulo,
        texto: TextosDoPertoDeMim.bloqueada,
        acao: 'Abrir configurações',
        desistir: 'Agora não',
      );
      if (abrir) await servico.abrirConfiguracoes();
    case PermissaoDaLocalizacao.servicoDesligado:
      final abrir = await confirmar(
        context,
        titulo: TextosDoPertoDeMim.desligadaTitulo,
        texto: TextosDoPertoDeMim.desligada,
        acao: 'Abrir configurações da localização',
        desistir: 'Agora não',
      );
      if (abrir) await servico.abrirConfiguracoesDaLocalizacao();
  }
}
