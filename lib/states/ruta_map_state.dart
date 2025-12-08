// lib/states/ruta_map_state.dart

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

    final bounds = LatLngBounds.fromPoints(_routePoints);
    
    // Implementación del MapController de Flutter Map
   
  }

  Future<void> refreshRoute() async {
    await setupMapData();
  }

  @override
  void dispose() {
    super.dispose();
  }
}