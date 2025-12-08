import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart'; 

// --- Configuración de la API de OpenRouteService ---
const String openRouteServiceApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQ4NmFiZDViZDgwMzRiMDU5ODU2ZTM2YjM5NTMwNmZiIiwiaCI6Im11cm11cjY0In0='; 
const String baseUrlHost = 'api.openrouteservice.org'; // Host sin HTTPS
const String baseUrlPath = '/v2/directions/driving-car'; // Path de la API
// ----------------------------------------------------

class DirectionsService {

  Future<List<LatLng>> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [], 
  }) async {
    
    // 1. CONSTRUIR LA CADENA DE COORDENADAS: [lng,lat];[lng,lat];...
    // ORS requiere que las coordenadas estén en formato Longitud, Latitud.
    
    // A. Punto de Origen (Longitud, Latitud)
    String allCoordinates = '${origin.longitude},${origin.latitude}';
    
    // B. Puntos Intermedios (Calles)
    for (var p in waypoints) {
      allCoordinates += ';${p.longitude},${p.latitude}';
    }
    
    // C. Punto de Destino (Longitud, Latitud)
    allCoordinates += ';${destination.longitude},${destination.latitude}';
    
    // 2. CREAR LA URL USANDO URI.HTTPS
    // Dart se encargará de codificar los valores, manejando el signo negativo correctamente.
    final Uri url = Uri.https(
      baseUrlHost,
      baseUrlPath,
      {
        'api_key': openRouteServiceApiKey,
        // Usamos 'start' (el parámetro que ORS exige) y pasamos la cadena sin codificar.
        'start': allCoordinates, 
        'profile': 'driving-car',
        'format': 'json',
      }
    );

    debugPrint('URL de la solicitud ORS (Final): $url'); 

    try {
      // 3. Hacer la solicitud HTTP
      final response = await http.get(url);

      if (response.statusCode == 200) {
        
        final Map<String, dynamic> data = json.decode(response.body);

        // 4. Extraer y convertir los puntos de la ruta
        final List<dynamic> segments = data['features'][0]['geometry']['coordinates'];
        
        final List<LatLng> routePoints = [];

        for (final point in segments) {
          // ORS devuelve [Longitud, Latitud] -> convertimos a LatLng(Latitud, Longitud)
          routePoints.add(
            LatLng(point[1] as double, point[0] as double),
          );
        }
        
        return routePoints;

      } else {
        throw Exception(
          'Fallo al cargar direcciones. Código: ${response.statusCode}. Respuesta: ${response.body}'
        );
      }
    } catch (e) {
      debugPrint('Error en DirectionsService: $e');
      throw Exception('No se pudo obtener la ruta por calles: $e');
    }
  }
}