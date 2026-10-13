import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../domain/models/dados_do_paciente.dart';
import '../../domain/models/paciente.dart';
import '../comum/botoes.dart';
import '../comum/confirmacao.dart';
import '../comum/espaco.dart';
import '../comum/retorno.dart';
import 'formulario_do_paciente_view_model.dart';
import 'mascaras.dart';
import 'validacoes_do_paciente.dart';

/// Os dados do paciente: completar o cadastro, depois do termo, ou editá-los,
/// no perfil. Um formulário só, para os dois terem as mesmas regras.
class FormularioDoPacienteScreen extends StatefulWidget {
  const FormularioDoPacienteScreen({
    super.key,
    required this.criarVm,
    required this.email,
    required this.aoConcluir,
    this.aoTermoMudar,
  });

  /// Cria o view model — uma vez só, quando a tela abre. A tela é dona dele e
  /// o descarta ao sair. Uma fábrica, e não o objeto pronto: se a rota
  /// reconstruir o widget, um view model novo trocaria de dono no meio de um
  /// envio, perdendo a trava e o erro na tela.
  final FormularioDoPacienteViewModel Function() criarVm;

  /// O e-mail da conta, mostrado só para leitura: não se edita aqui.
  final String email;

  /// O perfil foi gravado.
  final void Function(Paciente paciente) aoConcluir;

  /// Cadastro: a versão do termo mudou entre a leitura e o envio.
  final VoidCallback? aoTermoMudar;

  @override
  State<FormularioDoPacienteScreen> createState() => _FormularioDoPacienteScreenState();
}

class _FormularioDoPacienteScreenState extends State<FormularioDoPacienteScreen> {
  final _formulario = GlobalKey<FormState>();
  late final FormularioDoPacienteViewModel _vm;
  late final TextEditingController _nome;
  late final TextEditingController _telefone;
  late final TextEditingController _data;
  late final List<String> _iniciais;
  late final Listenable _mudancas;
  final _focos = {for (final campo in CampoDoPaciente.values) campo: FocusNode()};

  @override
  void initState() {
    super.initState();
    _vm = widget.criarVm();
    final atual = _vm.atual;
    _nome = TextEditingController(text: atual?.nome ?? '');
    _telefone = TextEditingController(text: formatarTelefone(atual?.telefone ?? ''));
    _data = TextEditingController(text: atual?.dataNascimento?.paraTela() ?? '');
    _iniciais = [_nome.text, _telefone.text, _data.text];
    _mudancas = Listenable.merge([_vm, _nome, _telefone, _data]);
  }

  bool get _haAlteracoes => [_nome.text, _telefone.text, _data.text].indexed.any((par) => par.$2 != _iniciais[par.$1]);

  @override
  void dispose() {
    _vm.dispose();
    for (final controlador in [_nome, _telefone, _data]) {
      controlador.dispose();
    }
    for (final foco in _focos.values) {
      foco.dispose();
    }
    super.dispose();
  }

  String? _validar(CampoDoPaciente campo, String texto) => switch (campo) {
        CampoDoPaciente.nome => validarNome(texto),
        CampoDoPaciente.telefone => validarTelefone(texto),
        CampoDoPaciente.dataNascimento => validarDataDeNascimento(texto),
      };

  TextEditingController _controlador(CampoDoPaciente campo) => switch (campo) {
        CampoDoPaciente.nome => _nome,
        CampoDoPaciente.telefone => _telefone,
        CampoDoPaciente.dataNascimento => _data,
      };

  /// Foco no primeiro campo com problema — o da validação ou o da API — e a
  /// tela rola até ele (checklist, item 9.7).
  void _focarNoPrimeiroErro() {
    for (final campo in CampoDoPaciente.values) {
      if (_vm.erroDo(campo) != null || _validar(campo, _controlador(campo).text) != null) {
        _focos[campo]!.requestFocus();
        return;
      }
    }
  }

  Future<void> _enviar() async {
    if (!_formulario.currentState!.validate()) {
      _focarNoPrimeiroErro();
      return;
    }
    final telefone = digitos(_telefone.text);
    final paciente = await _vm.enviar(DadosDoPaciente(
      nome: normalizarNome(_nome.text),
      telefone: telefone.isEmpty ? null : telefone,
      dataNascimento: lerDataDeNascimento(_data.text),
    ));
    if (!mounted) return;
    if (paciente != null) {
      widget.aoConcluir(paciente);
    } else if (_vm.termoMudou) {
      widget.aoTermoMudar?.call();
    } else {
      _focarNoPrimeiroErro();
    }
  }

  Widget _campo(
    CampoDoPaciente campo, {
    required String rotulo,
    String? dica,
    required TextInputType teclado,
    required Iterable<String> preenchimento,
    TextInputFormatter? mascara,
    TextCapitalization maiusculas = TextCapitalization.none,
    bool ultimo = false,
  }) {
    return TextFormField(
      controller: _controlador(campo),
      focusNode: _focos[campo],
      decoration: InputDecoration(labelText: rotulo, hintText: dica, border: const OutlineInputBorder()),
      keyboardType: teclado,
      autofillHints: preenchimento,
      textCapitalization: maiusculas,
      inputFormatters: [?mascara],
      textInputAction: ultimo ? TextInputAction.done : TextInputAction.next,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (texto) => _validar(campo, texto ?? ''),
      forceErrorText: _vm.erroDo(campo),
      onChanged: (_) => _vm.campoMudou(campo),
      onFieldSubmitted: ultimo ? (_) => _enviar() : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _mudancas,
      builder: (context, _) => ProtecaoDeAlteracoes(
        haAlteracoes: _haAlteracoes && !_vm.enviando,
        child: Scaffold(
          appBar: AppBar(title: Text(_vm.cadastro ? 'Completar cadastro' : 'Editar dados')),
          body: SafeArea(
            child: AutofillGroup(
              child: Form(
                key: _formulario,
                child: ListView(
                  padding: const EdgeInsets.all(Espaco.margem),
                  children: [
                    if (_vm.cadastro) ...[
                      Text(
                        'Falta pouco. Com estes dados, a clínica sabe quem você é e como falar com você.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: Espaco.grande),
                    ],
                    // Só leitura, e com cara de leitura: um campo desabilitado ficaria
                    // com o texto a 38% de opacidade, abaixo do contraste mínimo.
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.mail_outline),
                      title: const Text('E-mail da conta'),
                      subtitle: Text(widget.email),
                    ),
                    const SizedBox(height: Espaco.medio),
                    _campo(
                      CampoDoPaciente.nome,
                      rotulo: 'Nome completo',
                      teclado: TextInputType.name,
                      preenchimento: const [AutofillHints.name],
                      maiusculas: TextCapitalization.words,
                    ),
                    const SizedBox(height: Espaco.medio),
                    _campo(
                      CampoDoPaciente.telefone,
                      rotulo: 'Telefone com DDD (opcional)',
                      dica: '(88) 99999-0000',
                      teclado: TextInputType.phone,
                      preenchimento: const [AutofillHints.telephoneNumber],
                      mascara: const Mascara.telefone(),
                    ),
                    const SizedBox(height: Espaco.medio),
                    _campo(
                      CampoDoPaciente.dataNascimento,
                      rotulo: 'Data de nascimento (opcional)',
                      dica: 'dd/mm/aaaa',
                      teclado: TextInputType.datetime,
                      preenchimento: const [AutofillHints.birthday],
                      mascara: const Mascara.data(),
                      ultimo: true,
                    ),
                    const SizedBox(height: Espaco.grande),
                    if (_vm.erroGeral case final erro?) ...[
                      Aviso(tipo: TipoDeRetorno.erro, texto: erro),
                      const SizedBox(height: Espaco.medio),
                    ],
                    BotaoPrincipal(
                      rotulo: _vm.cadastro ? 'Concluir cadastro' : 'Salvar alterações',
                      aoTocar: _enviar,
                      enviando: _vm.enviando,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
