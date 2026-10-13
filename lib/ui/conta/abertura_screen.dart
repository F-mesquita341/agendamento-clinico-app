import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/tema.dart';
import '../comum/botoes.dart';
import '../comum/espaco.dart';
import '../comum/marca.dart';
import 'criar_conta_screen.dart';
import 'entrar_screen.dart';

/// A primeira tela de quem está sem sessão: a marca, o que o aplicativo faz, e
/// os dois caminhos — criar a conta ou entrar.
///
/// Não há aceite aqui ("ao continuar, você concorda…"): o termo de
/// consentimento tem tela própria, com a caixa desmarcada (checklist, item
/// 10.4). E só há e-mail e senha: sem entrada por rede social.
class AberturaScreen extends StatelessWidget {
  const AberturaScreen({super.key});

  Future<void> _criarConta(NavigatorState navegador) async {
    // Quem, lá dentro, escolhe entrar — "Já tenho conta", "Entrar com este
    // e-mail" — volta com o e-mail. Voltar pelo sistema não devolve nada.
    final email = await navegador.push<String>(MaterialPageRoute(builder: (_) => const CriarContaScreen()));
    if (email != null) _entrar(navegador, email);
  }

  void _entrar(NavigatorState navegador, [String email = '']) {
    navegador.push<void>(MaterialPageRoute(builder: (_) => EntrarScreen(emailInicial: email)));
  }

  @override
  Widget build(BuildContext context) {
    final tema = Theme.of(context);
    final cores = tema.colorScheme;
    final navegador = Navigator.of(context);
    // Fundo escuro: os ícones da barra de status do Android ficam claros.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: cores.primary,
        body: SafeArea(
          bottom: false,
          // Ocupa a tela inteira quando cabe; quando não cabe — texto
          // ampliado, aparelho deitado —, rola, e a arte cede o lugar.
          child: LayoutBuilder(
            builder: (context, limites) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: limites.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(Espaco.grande, Espaco.maior, Espaco.grande, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Marca(tamanho: 60),
                            const SizedBox(height: Espaco.medio),
                            Text(
                              'Sua consulta marcada pelo celular, sem fila e sem ligação.',
                              style: tema.textTheme.headlineMedium!.copyWith(color: cores.onPrimary),
                            ),
                            const SizedBox(height: Espaco.medio),
                            Text(
                              'Escolha o profissional e o horário, faça o pagamento antecipado e receba um lembrete um dia antes.',
                              style: tema.textTheme.bodyLarge!.copyWith(color: cores.primaryContainer),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: _Arte(principal: cores.primary)),
                      Container(
                        decoration: BoxDecoration(
                          color: cores.surfaceContainerLowest,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                        ),
                        padding: EdgeInsets.fromLTRB(
                          Espaco.grande,
                          Espaco.grande,
                          Espaco.grande,
                          Espaco.grande + MediaQuery.paddingOf(context).bottom,
                        ),
                        child: Column(
                          children: [
                            BotaoPrincipal(rotulo: 'Criar conta', aoTocar: () => _criarConta(navegador)),
                            const SizedBox(height: Espaco.pequeno),
                            BotaoSecundario(rotulo: 'Já tenho conta', aoTocar: () => _entrar(navegador)),
                          ],
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

/// A paisagem da abertura: o sol em âmbar e três morros em tons da cor
/// principal. É só decoração — fora da leitura de tela — e ocupa o espaço que
/// sobrar: sem altura, não desenha nada.
class _Arte extends StatelessWidget {
  const _Arte({required this.principal});

  final Color principal;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: ClipRect(child: CustomPaint(painter: _Paisagem(principal), size: Size.infinite)),
    );
  }
}

class _Paisagem extends CustomPainter {
  const _Paisagem(this.principal);

  final Color principal;

  @override
  void paint(Canvas canvas, Size size) {
    final (l, a) = (size.width, size.height);
    if (a < 96) return;
    Paint tom(double escuro) => Paint()..color = Color.lerp(principal, Colors.black, escuro)!;

    canvas.drawCircle(Offset(l - 133, a - 133), 75, Paint()..color = ambarDaMarca);
    canvas.drawOval(Rect.fromCenter(center: Offset(85, a), width: 250, height: 320), tom(0.29));
    canvas.drawOval(Rect.fromCenter(center: Offset(l - 75, a + 20), width: 210, height: 240), tom(0.16));
    canvas.drawOval(Rect.fromCenter(center: Offset(210, a + 22), width: 120, height: 140), tom(0.43));
  }

  @override
  bool shouldRepaint(_Paisagem anterior) => anterior.principal != principal;
}
