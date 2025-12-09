// lib/states/ruta_map_state.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:app_locacion/services/directions_service.dart'; 
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Importaciones de Flutter Map y LatLng
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart'; 

import '../api/rutas_api.dart';

class RutaMapState extends ChangeNotifier {
  final String rutaId;
  final Function(String, {bool isError}) onShowMessage;

  RutaMapState({required this.rutaId, required this.onShowMessage});

  // Estado
  Map<String, dynamic>? _rutaData;
  bool _isLoading = true;
  bool _isMapLoading = true;
  
  final MapController _mapController = MapController(); 
  
  final List<Marker> _markers = [];
  
  final List<Polyline> _polylines = [];
  
  final _storage = const FlutterSecureStorage();
  
  List<LatLng> _routePoints = []; 
  
  LatLng _initialPosition = const LatLng(
    6.2476,
    -75.5658,
  ); // Posición por defecto: Medellín

  // Getters
  Map<String, dynamic>? get rutaData => _rutaData;
  bool get isLoading => _isLoading;
  bool get isMapLoading => _isMapLoading;
  List<Marker> get markers => _markers; 
  List<Polyline> get polylines => _polylines; 
  List<LatLng> get routePoints => _routePoints;
  LatLng get initialPosition => _initialPosition;
  MapController get mapController => _mapController;

  /// Retorna lista de calles procesadas con nombre y coordinadas.
  /// Estructura: List<{'nombre': String, 'lat': double, 'lng': double}>
  List<Map<String, dynamic>> get calles {
    if (_rutaData == null || !_rutaData!.containsKey('calles')) {
      return [];
    }

    final List<dynamic> callesData = _rutaData!['calles'] ?? [];
    return callesData.map((calle) {
      return {
        'nombre': calle['nombre'] ?? 'Calle sin nombre',
        'lat': (calle['lat'] as num?)?.toDouble() ?? 0.0,
        'lng': (calle['lng'] as num?)?.toDouble() ?? 0.0,
      };
    }).toList();
  } 
  
  // Carga los detalles de la ruta desde la API
  Future<void> loadRutaDetails() async {
    _isLoading = true;
    _isMapLoading = true;
    notifyListeners();

    try {
      if (rutaId.isEmpty) {
        throw Exception('El ID de la ruta está vacío');
      }

      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      final Map<String, dynamic> ruta = await RutasApi.getRuta(token, rutaId);
      _rutaData = ruta;

      if (ruta.containsKey('punto_partida')) {
        final puntoPartida = ruta['punto_partida'];
        _initialPosition = LatLng(
          (puntoPartida['_latitude'] as num).toDouble(),
          (puntoPartida['_longitude'] as num).toDouble(),
        );
      }

      _isLoading = false;
      // Llamamos a setupMapData justo después de cargar los datos
      await setupMapData();
      
      // Cargar la última ubicación del camión automáticamente
      try {
        await obtenerUltimaUbicacion();
      } catch (e) {
        print('⚠️ Advertencia: No se pudo cargar la última ubicación: $e');
        // No interrumpimos el flujo si falla la última ubicación
      }
      
    } catch (e) {
      _isLoading = false;
      _isMapLoading = false;
      _rutaData = null;
      onShowMessage('Error al cargar la ruta: ${e.toString()}', isError: true);
      notifyListeners();
    }
  }


  // Prepara los marcadores y la polilínea para el mapa
  Future<void> setupMapData() async {
    if (_rutaData == null) {
      _isMapLoading = false;
      notifyListeners();
      return;
    }

    _isMapLoading = true;
    notifyListeners();
    
    _markers.clear();
    _polylines.clear();
    _routePoints.clear();

    if (!_rutaData!.containsKey('punto_partida') ||
        !_rutaData!.containsKey('punto_final')) {
      onShowMessage('La ruta no tiene puntos de partida y final definidos.');
      _isMapLoading = false;
      notifyListeners();
      return;
    }

    final puntoPartida = _rutaData!['punto_partida'];
    final puntoFinal = _rutaData!['punto_final'];
    
    // Extracción de puntos intermedios desde 'calles'
    final List<dynamic> callesData = _rutaData!['calles'] ?? [];
    final List<LatLng> waypoints = callesData.map((calle) {
      return LatLng(
        (calle['lat'] as num).toDouble(),
        (calle['lng'] as num).toDouble(),
      );
    }).toList();


    final LatLng inicio = LatLng(
      (puntoPartida['_latitude'] as num).toDouble(),
      (puntoPartida['_longitude'] as num).toDouble(),
    );
    final LatLng fin = LatLng(
      (puntoFinal['_latitude'] as num).toDouble(),
      (puntoFinal['_longitude'] as num).toDouble(),
    );
    
    // Llamada con puntos intermedios
    await _getRouteData(inicio, fin, waypoints: waypoints);
  }

  // Obtiene la ruta y configura el mapa 
  Future<void> _getRouteData(LatLng inicio, LatLng fin, {List<LatLng> waypoints = const []}) async {
    try {
      // 1. Limpieza inicial
      _markers.clear();
      _polylines.clear();
      
      // 2. Obtener la ruta del servicio (usando waypoints)
      final List<LatLng> routePoints = await DirectionsService().getDirections(
        origin: inicio,
        destination: fin,
        waypoints: waypoints, 
      );

      _routePoints = routePoints;
      
      // 3. Añadir marcadores
      // Inicio
      _markers.add(
        Marker(
          point: inicio,
          width: 80.0,
          height: 80.0,
          alignment: Alignment.topCenter,
          child: const Icon(Icons.location_on, color: Colors.green, size: 40.0,),
        ),
      );

      // Fin
      _markers.add(
        Marker(
          point: fin,
          width: 80.0,
          height: 80.0,
          alignment: Alignment.topCenter,
          child: const Icon(Icons.location_on, color: Colors.red, size: 40.0,),
        ),
      );
      
      // Intermedios (numerados)
      _addIntermediateMarkers(waypoints); 

      // 4. Añadir polilínea
      if (routePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            points: routePoints,
            color: Colors.blue.shade600,
            strokeWidth: 5,
          ),
        );
      }

      _isMapLoading = false;
      notifyListeners();
      fitMapToRoute();
      
    } catch (e) {
      _showFallbackRoute(inicio, fin, waypoints: waypoints); 
      onShowMessage(
        'Error al obtener la ruta por calles: ${e.toString()}.\nMostrando ruta directa.',
      );
      _isMapLoading = false;
      notifyListeners();
    }
  }

  // FUNCIÓN: Para añadir marcadores a los puntos intermedios
  void _addIntermediateMarkers(List<LatLng> waypoints) {
    for (int i = 0; i < waypoints.length; i++) {
        _markers.add(
            Marker(
                point: waypoints[i],
                width: 40.0, 
                height: 40.0,
                alignment: Alignment.topCenter,
                child: Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.blue.shade600, width: 2),
                  ),
                  child: Text(
                    (i + 1).toString(),
                    style: TextStyle(
                      color: Colors.blue.shade600, 
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
                  ),
                ),
            ),
        );
    }
  }

  // Fallback en caso de error (Versión única y correcta)
  void _showFallbackRoute(LatLng inicio, LatLng fin, {List<LatLng> waypoints = const []}) {
    _markers.clear();
    _polylines.clear();
    
    // Marcadores de Inicio y Fin (Fallback color)
    _markers.add(Marker(point: inicio, width: 80.0, height: 80.0, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: Colors.orange, size: 40.0,)));
    _markers.add(Marker(point: fin, width: 80.0, height: 80.0, alignment: Alignment.topCenter, child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 40.0,)));
    
    // Marcadores intermedios (numerados)
    _addIntermediateMarkers(waypoints); 
    
    // Polilínea directa (une todos los puntos en orden: inicio -> waypoints[1] -> ... -> fin)
    final List<LatLng> allPoints = [inicio, ...waypoints, fin];

    _polylines.add(
      Polyline(
        points: allPoints, 
        color: Colors.orange.shade600,
        strokeWidth: 5,
      ),
    );

    _routePoints = allPoints;
  }

  // Ajusta la cámara
  Future<void> fitMapToRoute() async {
    if (_routePoints.isEmpty) return;

    // Implementación del MapController de Flutter Map
  }

  Future<void> refreshRoute() async {
    try {
      _isMapLoading = true;
      notifyListeners();

      await setupMapData();
      await obtenerUltimaUbicacion();

      _isMapLoading = false;
      notifyListeners();
    } catch (e) {
      _isMapLoading = false;
      notifyListeners();
      onShowMessage(
        'Error al actualizar la ruta: ${e.toString()}',
        isError: true,
      );
    }
  }

  /// Inicia la ruta cambiando su estado a 'en_curso'
  Future<void> iniciarRuta() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      if (_rutaData == null) {
        throw Exception('Los datos de la ruta no están disponibles.');
      }

      // Extraer punto_partida y enviar al endpoint /iniciar para comenzar la transmisión
      if (!_rutaData!.containsKey('punto_partida')) {
        throw Exception('No se encontró el punto de partida de la ruta.');
      }

      final puntoPartida = _rutaData!['punto_partida'];
      final latitude = (puntoPartida['_latitude'] as num).toDouble();
      final longitude = (puntoPartida['_longitude'] as num).toDouble();

      final resultado = await RutasApi.iniciarTransmision(token, rutaId, latitude, longitude);

      // Si el servidor aceptó la operación, actualizar estado local si viene en la respuesta
      try {
        if (resultado.containsKey('estado')) {
          _rutaData!['estado'] = resultado['estado'];
        } else {
          _rutaData!['estado'] = 'en_curso';
        }
      } catch (_) {
        // ignorar si no se puede actualizar localmente
      }
      notifyListeners();

      onShowMessage(
        resultado['message'] ?? 'Ruta iniciada correctamente',
        isError: false,
      );
    } catch (e) {
      onShowMessage(
        'Error al iniciar la ruta: ${e.toString()}',
        isError: true,
      );
    }
  }

  /// Actualiza la ubicación del conductor durante la transmisión
  /// Envía la ubicación al servidor para registrar la posición del camión.
  /// Si se pasan [latitude] y [longitude], se usan; si no, se usa `punto_partida` de la ruta.
  Future<void> iniciarTransmision({double? latitude, double? longitude}) async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      double latFinal;
      double lngFinal;

      if (latitude != null && longitude != null) {
        latFinal = latitude;
        lngFinal = longitude;
        print('🔁 Actualizando ubicación usando coordenadas pasadas: ($latFinal, $lngFinal)');
      } else {
        if (_rutaData == null || !_rutaData!.containsKey('punto_partida')) {
          throw Exception('No se encontró el punto de partida de la ruta.');
        }

        final puntoPartida = _rutaData!['punto_partida'];
        latFinal = (puntoPartida['_latitude'] as num).toDouble();
        lngFinal = (puntoPartida['_longitude'] as num).toDouble();

        print('🔁 Actualizando ubicación usando punto_partida: ($latFinal, $lngFinal)');
      }

      final resultado = await RutasApi.actualizarUbicacion(token, rutaId, latFinal, lngFinal);

      onShowMessage(
        resultado['message'] ?? 'Ubicación actualizada correctamente',
        isError: false,
      );
    } catch (e) {
      onShowMessage(
        'Error al actualizar ubicación: ${e.toString()}',
        isError: true,
      );
    }
  }

  /// Finaliza la transmisión de la ruta
  /// Envía las coordenadas del punto final al servidor
  Future<void> finalizarTransmision() async {
    try {
      if (rutaId.isEmpty) {
        throw Exception('No hay ID de ruta disponible');
      }

      // Usar las coordenadas del punto_final de la ruta
      final puntoFinal = _rutaData?['punto_final'];
      if (puntoFinal == null) {
        throw Exception('No se encontró punto final de la ruta');
      }

      final lat = (puntoFinal['_latitude'] as num).toDouble();
      final lng = (puntoFinal['_longitude'] as num).toDouble();

      print('📍 Coordenadas del punto final: ($lat, $lng)');

      // Construir el cuerpo de la petición
      final requestBody = {
        'ubicacion_actual': {
          'lat': lat,
          'lng': lng,
        }
      };

      print('📦 Request body: ${jsonEncode(requestBody)}');

      // Obtener token
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No hay token de autenticación');
      }

      print('🔐 Token obtenido: ${token.substring(0, 20)}...');
      print('🌐 Enviando petición a: https://server-location-1r1p.onrender.com/api/rutas/$rutaId/finalizar');

      // Hacer la petición PUT
      final response = await http.put(
        Uri.parse('https://server-location-1r1p.onrender.com/api/rutas/$rutaId/finalizar'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        
        // Actualizar estado local
        _rutaData?['estado'] = 'finalizada';
        notifyListeners();
        
        onShowMessage(
          responseData['message'] ?? 'Transmisión finalizada exitosamente',
          isError: false,
        );
        
        print('✅ Transmisión finalizada exitosamente');
      } else if (response.statusCode == 404) {
        throw Exception('La ruta no fue encontrada en el servidor');
      } else if (response.statusCode == 400) {
        throw Exception('La ruta ya está finalizada o no puede ser finalizada');
      } else {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['message'] ?? 'Error al finalizar transmisión');
      }
    } catch (e) {
      print('❌ Error en finalizarTransmision: ${e.toString()}');
      onShowMessage('Error: ${e.toString()}', isError: true);
      rethrow;
    }
  }

  /// Método para obtener el estado actual de la ruta desde el servidor
  Future<void> refreshRutaStatus() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) throw Exception('No hay token de autenticación');

      final response = await http.get(
        Uri.parse('https://server-location-1r1p.onrender.com/api/rutas/$rutaId'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          _rutaData = data['data'];
          notifyListeners();
          print('🔄 Estado de la ruta actualizado: ${_rutaData?['estado']}');
        }
      }
    } catch (e) {
      print('⚠️ Error al refrescar estado: $e');
    }
  }

  /// Obtiene la última ubicación registrada del camión desde el servidor
  /// y agrega un marcador en el mapa con el icono de camión
  Future<void> obtenerUltimaUbicacion() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      print('════════════════════════════════════');
      print('📍 Obteniendo última ubicación del camión...');
      print('════════════════════════════════════');

      final resultado = await RutasApi.obtenerUltimaUbicacion(token, rutaId);

      // El backend puede devolver la ubicación bajo diferentes claves.
      // Aceptamos tanto `ubicacion_actual` como `ubicacion`.
      Map<String, dynamic>? ubicacion;
      if (resultado.containsKey('ubicacion_actual')) {
        ubicacion = (resultado['ubicacion_actual'] as Map).cast<String, dynamic>();
      } else if (resultado.containsKey('ubicacion')) {
        ubicacion = (resultado['ubicacion'] as Map).cast<String, dynamic>();
      }

      if (ubicacion != null && ubicacion.containsKey('lat') && ubicacion.containsKey('lng')) {
        final lat = (ubicacion['lat'] as num).toDouble();
        final lng = (ubicacion['lng'] as num).toDouble();

        print('📍 Ubicación obtenida - Lat: $lat, Lng: $lng');

        // Crear o actualizar marcador del camión con icono personalizado
        _markers.removeWhere((m) => m.key == const ValueKey('truck_marker'));

        final marker = Marker(
          key: const ValueKey('truck_marker'),
          point: LatLng(lat, lng),
          width: 100,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Círculo de fondo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.blue.shade700,
                    width: 2,
                  ),
                ),
              ),
              // Círculo interior con icono
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.5),
                      spreadRadius: 3,
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_shipping,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        );

        _markers.add(marker);

        print('✅ Marcador del camión agregado al mapa');
        print('   📍 Posición: ($lat, $lng)');
        print('   📊 Total marcadores en el mapa: ${_markers.length}');

        notifyListeners();
      } else {
        print('⚠️ No se encontró ubicación (lat/lng) en la respuesta del servidor');
        // Mostrar contenido completo para debugging si viene en otra estructura
        print('Respuesta completa: $resultado');
      }
    } catch (e) {
      print('❌ Error al obtener última ubicación: ${e.toString()}');
      onShowMessage(
        'Error al obtener ubicación del camión: ${e.toString()}',
        isError: true,
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}