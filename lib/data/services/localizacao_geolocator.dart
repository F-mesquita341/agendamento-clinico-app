import 'dart:async';
import 'dart:developer' as developer;

import 'package:geolocator/geolocator.dart';

import '../../domain/models/coordenadas.dart';
import 'servico_de_localizacao.dart';

/// A localização do Android, pelo `geolocator`. É o único arquivo que importa
/// o pacote.
///
/// Só a localização aproximada: o manifesto declara apenas a permissão dela,
/// e o Android entrega a posição já borrada, a cerca de 2 km. A posição não
/// sai deste aparelho.
class LocalizacaoGeolocator implements ServicoDeLocalizacao {
  /// Quanto esperar pela posição antes de desistir.
  static const tempoLimite = Duration(seconds: 10);

  /// Até que idade a última posição conhecida ainda serve: para ordenar
  /// clínicas de cidades diferentes, uma posição de minutos atrás basta.
  static const idadeMaxima = Duration(minutes: 10);

  @override
  Future<PermissaoDaLocalizacao> permissao() async => _traduzir(await Geolocator.checkPermission());

  @override
  Future<PermissaoDaLocalizacao> pedirPermissao() async {
    final depois = await Geolocator.requestPermission();
    // Recusada logo depois de pedir: a pessoa disse não agora, e pode mudar de
    // ideia da próxima vez. Antes de pedir, "denied" é só "ainda não pedida".
    if (depois == LocationPermission.denied) return PermissaoDaLocalizacao.negada;
    return _traduzir(depois);
  }

  Future<PermissaoDaLocalizacao> _traduzir(LocationPermission permissao) async {
    switch (permissao) {
      case LocationPermission.denied:
      case LocationPermission.unableToDetermine:
        return PermissaoDaLocalizacao.naoPedida;
      case LocationPermission.deniedForever:
        return PermissaoDaLocalizacao.negadaDeVez;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return await Geolocator.isLocationServiceEnabled()
            ? PermissaoDaLocalizacao.concedida
            : PermissaoDaLocalizacao.servicoDesligado;
    }
  }

  @override
  Future<Coordenadas?> posicaoAproximada() async {
    // A falha aqui não é defeito do aplicativo — o aparelho sem sinal, a
    // localização desligada no meio do caminho —: fica no log, e a tela diz
    // que não deu para saber onde a pessoa está.
    //
    // O LocationManager do próprio Android, e não o provedor do Google Play:
    // antes de dar a posição, o do Google Play confere as configurações do
    // aparelho e, com a "precisão da localização" do Google desligada, abre um
    // diálogo pedindo para ligá-la — recusado, não dá a posição, mesmo com a
    // permissão concedida (portão do "Perto de mim", 05/11). Para a posição
    // aproximada, o LocationManager basta, sem pedir nada além da permissão.
    //
    // A qualidade pedida é a alta, numa leitura só: a baixa depende do
    // provedor de rede, que no Android é a mesma "precisão" do Google e pode
    // estar desligada. Com só a permissão aproximada, o Android borra a posição
    // de qualquer jeito.
    try {
      final ultima = await Geolocator.getLastKnownPosition(forceAndroidLocationManager: true);
      if (ultima != null && DateTime.now().difference(ultima.timestamp) <= idadeMaxima) {
        return Coordenadas(ultima.latitude, ultima.longitude);
      }
      final atual = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          forceLocationManager: true,
          accuracy: LocationAccuracy.high,
          timeLimit: tempoLimite,
        ),
      );
      return Coordenadas(atual.latitude, atual.longitude);
    } on TimeoutException {
      developer.log('A posição não veio em ${tempoLimite.inSeconds} s.', name: 'localizacao');
      return null;
    } catch (erro) {
      developer.log('Não deu para saber a posição: $erro', name: 'localizacao');
      return null;
    }
  }

  @override
  Future<bool> abrirConfiguracoes() => Geolocator.openAppSettings();

  @override
  Future<bool> abrirConfiguracoesDaLocalizacao() => Geolocator.openLocationSettings();
}
