// lib/states/ruta_map_state.dart

import 'package:app_locacion/services/directions_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../api/rutas_api.dart';

class RutaMapState extends ChangeNotifier {
  final String rutaId;
  final Function(String, {bool isError}) onShowMessage;

  RutaMapState({required this.rutaId, required this.onShowMessage});

  // Estado
  Map<String, dynamic>? _rutaData;
  bool _isLoading = true;
  bool _isMapLoading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
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
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  List<LatLng> get routePoints => _routePoints;
  LatLng get initialPosition => _initialPosition;

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
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _isMapLoading = false;
      _rutaData = null;
      onShowMessage('Error al cargar la ruta: ${e.toString()}', isError: true);
      notifyListeners();
    }
  }

  // Se llama cuando el mapa se crea
  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setupMapData();
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

    if (!_rutaData!.containsKey('punto_partida') ||
        !_rutaData!.containsKey('punto_final')) {
      onShowMessage('La ruta no tiene puntos de partida y final definidos.');
      _isMapLoading = false;
      _routePoints = [];
      _markers.clear();
      _polylines.clear();
      notifyListeners();
      return;
    }

    final puntoPartida = _rutaData!['punto_partida'];
    final puntoFinal = _rutaData!['punto_final'];

    final LatLng inicio = LatLng(
      (puntoPartida['_latitude'] as num).toDouble(),
      (puntoPartida['_longitude'] as num).toDouble(),
    );
    final LatLng fin = LatLng(
      (puntoFinal['_latitude'] as num).toDouble(),
      (puntoFinal['_longitude'] as num).toDouble(),
    );

    await _getRouteData(inicio, fin);
  }

  // Obtiene la ruta y configura el mapa
  Future<void> _getRouteData(LatLng inicio, LatLng fin) async {
    try {
      final routePoints = await DirectionsService().getDirections(
        origin: inicio,
        destination: fin,
      );

      _routePoints = routePoints;

      _markers.clear();
      _polylines.clear();

      _markers.add(
        Marker(
          markerId: const MarkerId('inicio'),
          position: inicio,
          infoWindow: const InfoWindow(
            title: 'Inicio',
            snippet: 'Punto de partida de la ruta',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('fin'),
          position: fin,
          infoWindow: const InfoWindow(
            title: 'Destino',
            snippet: 'Punto final de la ruta',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      if (routePoints.isNotEmpty) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('ruta'),
            points: routePoints,
            color: Colors.blue.shade600,
            width: 5,
            geodesic: true,
          ),
        );
      }

      _isMapLoading = false;
      notifyListeners();
      fitMapToRoute();
    } catch (e) {
      _showFallbackRoute(inicio, fin);
      onShowMessage(
        'Error al obtener la ruta por calles: ${e.toString()}.\nMostrando ruta directa.',
      );
      _isMapLoading = false;
      notifyListeners();
    }
  }

  // Fallback en caso de error
  void _showFallbackRoute(LatLng inicio, LatLng fin) {
    _markers.clear();
    _polylines.clear();

    _markers.add(
      Marker(
        markerId: const MarkerId('inicio'),
        position: inicio,
        infoWindow: const InfoWindow(title: 'Inicio'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('fin'),
        position: fin,
        infoWindow: const InfoWindow(title: 'Destino'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('ruta_directa'),
        points: [inicio, fin],
        color: Colors.orange.shade600,
        width: 5,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );

    _routePoints = [inicio, fin];
  }

  // Ajusta la cámara
  Future<void> fitMapToRoute() async {
    if (_mapController == null || _routePoints.isEmpty) return;

    final bounds = _calculateBounds(_routePoints);
    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      onShowMessage('Error al ajustar la cámara del mapa.', isError: true);
    }
  }

  Future<void> refreshRoute() async {
    await setupMapData();
  }

  LatLngBounds _calculateBounds(List<LatLng> points) {
    if (points.isEmpty) {
      return LatLngBounds(
        southwest: const LatLng(6.1, -75.7),
        northeast: const LatLng(6.4, -75.4),
      );
    }

    double minLat = points[0].latitude;
    double maxLat = points[0].latitude;
    double minLng = points[0].longitude;
    double maxLng = points[0].longitude;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    return LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
  }
}
