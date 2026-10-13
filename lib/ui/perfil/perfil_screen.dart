import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/repositories/repositorio_do_paciente.dart';
import '../../domain/models/data_civil.dart';
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
    final estilos = Theme.of(context).textTheme;
    final aceitoEm = paciente.termoAceitoEm;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(Espaco.margem),
          children: [
            Text(paciente.nome, style: estilos.headlineSmall),
            const SizedBox(height: Espaco.medio),
            _Dado(icone: Icons.mail_outline, rotulo: 'E-mail', valor: paciente.email),
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
            _Dado(
              icone: Icons.description_outlined,
              rotulo: 'Termo de consentimento',
              valor: aceitoEm == null
                  ? 'Versão ${paciente.versaoDoTermo}'
                  : 'Versão ${paciente.versaoDoTermo}, aceita em ${DataCivil.doInstante(aceitoEm).paraTela()}',
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: BotaoDeTexto(
                rotulo: 'Ler o termo',
                aoTocar: () => Navigator.of(context).push<void>(MaterialPageRoute(
                  builder: (_) => TermoLidoScreen(versao: paciente.versaoDoTermo, lerArquivo: lerArquivo),
                )),
              ),
            ),
            const SizedBox(height: Espaco.grande),
            BotaoPrincipal(rotulo: 'Editar dados', aoTocar: () => _editar(context, sessao)),
            const SizedBox(height: Espaco.pequeno),
            BotaoSecundario(rotulo: 'Sair da conta', aoTocar: () => _sair(context, sessao)),
          ],
        ),
      ),
    );
  }
}

class _Dado extends StatelessWidget {
  const _Dado({required this.icone, required this.rotulo, required this.valor});

  final IconData icone;
  final String rotulo;
  final String valor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ExcludeSemantics(child: Icon(icone)),
      title: Text(rotulo),
      subtitle: Text(valor),
    );
  }
}
