import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart'; 

// --- Configuración de la API de OpenRouteService ---
const String openRouteServiceApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjQ4NmFiZDViZDgwMzRiMDU5ODU2ZTM2YjM5NTMwNmZiIiwiaCI6Im11cm11cjY0In0='; 
const String baseUrlHost = 'api.openrouteservice.org';
const String baseUrlPath = '/v2/directions/driving-car/geojson';
// ----------------------------------------------------

class DirectionsService {

  Future<List<LatLng>> getDirections({
    required LatLng origin,
    required LatLng destination,
    List<LatLng> waypoints = const [], 
  }) async {
    
    try {
      // 1. CONSTRUIR LA LISTA DE COORDENADAS EN FORMATO ORS
      // ORS requiere: [[lon1, lat1], [lon2, lat2], ...]
      final List<List<double>> coordinates = [];
      
      // Añadir origen
      coordinates.add([origin.longitude, origin.latitude]);
      
      // Añadir waypoints (puntos intermedios)
      for (final waypoint in waypoints) {
        coordinates.add([waypoint.longitude, waypoint.latitude]);
      }
      
      // Añadir destino
      coordinates.add([destination.longitude, destination.latitude]);
      
      // 2. CREAR EL CUERPO DE LA PETICIÓN (POST)
      final requestBody = jsonEncode({
        'coordinates': coordinates,
        'geometry': true,
        'geometry_format': 'geojson',
        'format': 'json',
      });

      debugPrint('📍 Coordenadas a enviar a ORS:');
      debugPrint('  Origen: [${origin.longitude}, ${origin.latitude}]');
      debugPrint('  Waypoints: ${waypoints.length} puntos');
      debugPrint('  Destino: [${destination.longitude}, ${destination.latitude}]');
      debugPrint('  Total coordenadas: ${coordinates.length}');

      // 3. CONSTRUIR LA URL Y HEADERS
      final Uri url = Uri.https(baseUrlHost, baseUrlPath);
      
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': openRouteServiceApiKey,
        'Accept': 'application/json, application/geo+json',
      };

      debugPrint('🌐 URL de solicitud ORS: $url');
      debugPrint('🔑 API Key: ${openRouteServiceApiKey.substring(0, 20)}...');

      // 4. HACER LA SOLICITUD HTTP POST (ORS usa POST para esta endpoint)
      final response = await http.post(
        url,
        headers: headers,
        body: requestBody,
      );

      debugPrint('📡 Código de respuesta: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        
        // Debug: imprimir estructura de respuesta
        debugPrint('✅ Respuesta exitosa de ORS');
        
        // 5. VERIFICAR QUE HAYA DATOS VÁLIDOS
        if (data['features'] == null || data['features'].isEmpty) {
          throw Exception('ORS no devolvió ninguna ruta');
        }
        
        final geometry = data['features'][0]['geometry'];
        
        if (geometry['type'] != 'LineString' || geometry['coordinates'] == null) {
          throw Exception('Formato de geometría inválido en respuesta ORS');
        }
        
        final List<dynamic> segments = geometry['coordinates'];
        debugPrint('🛣️ Puntos de ruta recibidos: ${segments.length}');

        // 6. CONVERTIR LOS PUNTOS A LatLng
        final List<LatLng> routePoints = [];
        
        for (final point in segments) {
          if (point is List && point.length >= 2) {
            // ORS devuelve [Longitud, Latitud] -> convertimos a LatLng(Latitud, Longitud)
            final lat = (point[1] as num).toDouble();
            final lng = (point[0] as num).toDouble();
            routePoints.add(LatLng(lat, lng));
          }
        }
        
        if (routePoints.isEmpty) {
          throw Exception('No se pudieron extraer puntos de ruta válidos');
        }
        
        debugPrint('✅ Ruta procesada exitosamente con ${routePoints.length} puntos');
        return routePoints;

      } else {
        debugPrint('❌ Error de ORS - Body: ${response.body}');
        
        // Intentar extraer mensaje de error específico
        try {
          final errorData = json.decode(response.body);
          final errorMsg = errorData['error']?['message'] ?? response.body;
          throw Exception('Error ORS (${response.statusCode}): $errorMsg');
        } catch (_) {
          throw Exception(
            'Fallo al cargar direcciones. Código: ${response.statusCode}. Respuesta: ${response.body}'
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error en DirectionsService: $e');
      throw Exception('No se pudo obtener la ruta por calles: $e');
    }
  }
}