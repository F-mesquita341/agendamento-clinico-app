import 'dart:math' as math;

/// Um ponto na Terra, em graus: a clínica, ou onde a pessoa está.
///
/// A posição da pessoa só existe no aparelho ("Perto de mim", versão 2): ela
/// não é enviada à API nem guardada.
class Coordenadas {
  const Coordenadas(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  bool operator ==(Object other) =>
      other is Coordenadas && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => 'Coordenadas($latitude, $longitude)';
}

/// O raio médio da Terra, em quilômetros.
const raioDaTerraEmKm = 6371.0;

/// A distância em linha reta entre dois pontos, em quilômetros, pela fórmula
/// de haversine. Para ordenar clínicas de uma região, a linha reta basta: não
/// é o caminho de carro, e o card não diz que é.
double distanciaEmKm(Coordenadas a, Coordenadas b) {
  double radianos(double graus) => graus * math.pi / 180;
  final dLat = radianos(b.latitude - a.latitude);
  final dLon = radianos(b.longitude - a.longitude);
  final h = math.pow(math.sin(dLat / 2), 2) +
      math.cos(radianos(a.latitude)) * math.cos(radianos(b.latitude)) * math.pow(math.sin(dLon / 2), 2);
  return 2 * raioDaTerraEmKm * math.asin(math.min(1, math.sqrt(h)));
}
