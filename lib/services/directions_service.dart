// lib/services/directions_service.dart

import 'package:google_directions_api/google_directions_api.dart' as gda;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:async'; // Necesitas importar 'dart:async' para usar Future y Completer

class DirectionsService {
  Future<List<LatLng>> getDirections({
    required LatLng origin,
    required LatLng destination,
  }) async {
    final Completer<List<LatLng>> completer = Completer();

    final request = gda.DirectionsRequest(
      origin: '${origin.latitude},${origin.longitude}',
      destination: '${destination.latitude},${destination.longitude}',
      travelMode: gda.TravelMode.driving,
    );

    // Crea una instancia del servicio de direcciones
    final service = gda.DirectionsService();

    service.route(request, (
      gda.DirectionsResult? result,
      gda.DirectionsStatus? status,
    ) {
      if (status == gda.DirectionsStatus.ok && result != null) {
        final points = <LatLng>[];

        completer.complete(points);
      } else {
        completer.completeError('Error obteniendo direcciones: $status');
      }
    });

    return completer.future;
  }
}
