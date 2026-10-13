import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_paciente.dart';
import '../../domain/models/data_civil.dart';
import '../comum/avatar.dart';
import '../comum/botoes.dart';
import '../comum/confirmacao.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import '../cadastro/formulario_do_paciente_screen.dart';
import '../cadastro/formulario_do_paciente_view_model.dart';
import '../cadastro/mascaras.dart';
import '../sessao/sessao_view_model.dart';
import '../termo/termo_lido_screen.dart';

/// Os dados do paciente, o termo que ele aceitou, e a saída da conta.
class PerfilScreen extends StatelessWidget {
  const PerfilScreen({super.key, required this.lerArquivo});

  /// Para reler o termo: os arquivos do texto, por caminho.
  final Future<String> Function(String caminho) lerArquivo;

  Future<void> _editar(BuildContext context, SessaoViewModel sessao) async {
    final pacientes = context.read<RepositorioDoPaciente>();
    final atual = sessao.paciente!;
    await Navigator.of(context).push<void>(MaterialPageRoute(
      builder: (rota) => FormularioDoPacienteScreen(
        criarVm: () => FormularioDoPacienteViewModel.edicao(pacientes, atual: atual),
        email: atual.email,
        aoConcluir: (paciente) {
          sessao.perfilAtualizado(paciente);
          Navigator.of(rota).pop();
          // Confirmação visível de que deu certo (checklist, item 1.3).
          mostrarRetorno(context, TipoDeRetorno.sucesso, 'Dados salvos.');
        },
      ),
    ));
  }

  Future<void> _sair(BuildContext context, SessaoViewModel sessao) async {
    final confirmou = await confirmar(
      context,
      titulo: 'Sair da conta?',
      texto: 'Para entrar de novo, você vai precisar do seu e-mail e da sua senha.',
      acao: 'Sair da conta',
      destrutiva: true,
    );
    if (confirmou) await sessao.sair();
  }

  @override
  Widget build(BuildContext context) {
    final sessao = context.watch<SessaoViewModel>();
    final paciente = sessao.paciente;
    // Entre a saída e a troca de tela, não há perfil para mostrar.
    if (paciente == null) return const Scaffold();
    final tema = Theme.of(context);
    final aceitoEm = paciente.termoAceitoEm;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaco.margem),
          children: [
            Row(
              children: [
                AvatarDeIniciais(nome: paciente.nome, tamanho: 64),
                const SizedBox(width: Espaco.medio),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(paciente.nome, style: tema.textTheme.headlineSmall),
                      Text(
                        paciente.email,
                        style: tema.textTheme.bodyMedium!.copyWith(color: tema.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: Espaco.grande),
            _Grupo(
              children: [
                _Dado(
                  icone: Icons.phone_outlined,
                  rotulo: 'Telefone',
                  valor: paciente.telefone == null ? 'Não informado' : formatarTelefone(paciente.telefone!),
                ),
                _Dado(
                  icone: Icons.cake_outlined,
                  rotulo: 'Data de nascimento',
                  valor: paciente.dataNascimento?.paraTela() ?? 'Não informada',
                ),
                _Acao(icone: Icons.edit_outlined, rotulo: 'Editar dados', aoTocar: () => _editar(context, sessao)),
              ],
            ),
            const SizedBox(height: Espaco.medio),
            _Grupo(
              children: [
                _Dado(
                  icone: Icons.description_outlined,
                  rotulo: 'Termo de consentimento',
                  valor: aceitoEm == null
                      ? 'Versão ${paciente.versaoDoTermo}'
                      : 'Versão ${paciente.versaoDoTermo}, aceita em ${DataCivil.doInstante(aceitoEm).paraTela()}',
                ),
                _Acao(
                  icone: Icons.article_outlined,
                  rotulo: 'Ler o termo',
                  aoTocar: () => Navigator.of(context).push<void>(MaterialPageRoute(
                    builder: (_) => TermoLidoScreen(versao: paciente.versaoDoTermo, lerArquivo: lerArquivo),
                  )),
                ),
              ],
            ),
            const SizedBox(height: Espaco.grande),
            BotaoDestrutivo(rotulo: 'Sair da conta', aoTocar: () => _sair(context, sessao)),
          ],
        ),
      ),
    );
  }
}

/// Um cartão com linhas separadas por um fio: dados, e a ação sobre eles.
class _Grupo extends StatelessWidget {
  const _Grupo({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      // O realce do toque não passa dos cantos arredondados.
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, linha) in children.indexed) ...[
            if (i > 0) const Divider(height: 1),
            linha,
          ],
        ],
      ),
    );
  }
}

/// Um dado do cadastro: o que é, em letra menor, e o valor em destaque.
class _Dado extends StatelessWidget {
  const _Dado({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      leading: ExcludeSemantics(child: Icon(icone, color: tema.colorScheme.primary)),
      title: Text(rotulo, style: tema.textTheme.bodySmall!.copyWith(color: tema.colorScheme.onSurfaceVariant)),
      subtitle: Text(valor, style: tema.textTheme.titleSmall!.copyWith(color: tema.colorScheme.onSurface)),
    );
  }
}

/// Uma linha que leva a outra tela.
class _Acao extends StatelessWidget {
  const _Acao({required this.icone, required this.rotulo, required this.aoTocar});

  final IconData icone;
  final String rotulo;
  final VoidCallback aoTocar;

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    return ListTile(
      leading: ExcludeSemantics(child: Icon(icone, color: tema.colorScheme.primary)),
      title: Text(rotulo, style: tema.textTheme.titleSmall),
      trailing: const ExcludeSemantics(child: Icon(Icons.chevron_right)),
      onTap: aoTocar,
    );
  }
}
