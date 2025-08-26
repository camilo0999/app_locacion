// lib/screens/id_ruta_sreen.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import '../api/rutas_api.dart';

class IdRutaScreen extends StatefulWidget {
  final String rutaId;

  const IdRutaScreen({super.key, required this.rutaId});

  @override
  State<IdRutaScreen> createState() => _IdRutaScreenState();
}

class _IdRutaScreenState extends State<IdRutaScreen> {
  Map<String, dynamic>? rutaData;
  bool isLoading = true;
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadRutaDetails();
  }

  Future<void> _loadRutaDetails() async {
    try {
      if (widget.rutaId.isEmpty) {
        throw Exception('El ID de la ruta está vacío');
      }

      final token = await _storage.read(key: 'auth_token');

      if (token == null) {
        throw Exception('No se encontró el token de autenticación.');
      }

      final Map<String, dynamic> ruta = await RutasApi.getRuta(
        token,
        widget.rutaId,
      );

      setState(() {
        rutaData = ruta;
        isLoading = false;
        _setupMapData();
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error al cargar los detalles de la ruta: ${e.toString()}',
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _setupMapData() {
    if (rutaData == null) return;

    if (!rutaData!.containsKey('punto_partida') ||
        !rutaData!.containsKey('punto_final')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('La ruta no tiene puntos de partida y final definidos'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final puntoPartida = rutaData!['punto_partida'];
    final puntoFinal = rutaData!['punto_final'];

    final LatLng inicio = LatLng(
      (puntoPartida['_latitude'] as num).toDouble(),
      (puntoPartida['_longitude'] as num).toDouble(),
    );

    final LatLng fin = LatLng(
      (puntoFinal['_latitude'] as num).toDouble(),
      (puntoFinal['_longitude'] as num).toDouble(),
    );

    setState(() {
      _markers.clear();
      _polylines.clear();

      _markers.add(
        Marker(
          markerId: const MarkerId('inicio'),
          position: inicio,
          infoWindow: const InfoWindow(title: 'Inicio de la ruta'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
        ),
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('fin'),
          position: fin,
          infoWindow: const InfoWindow(title: 'Fin de la ruta'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );

      _polylines.add(
        Polyline(
          polylineId: const PolylineId('ruta'),
          points: [inicio, fin],
          color: Colors.blue,
          width: 5,
        ),
      );
    });

    // Si el mapa ya está creado, ajustar la cámara
    if (_mapController != null) {
      final bounds = _getBounds([inicio, fin]);
      _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 50));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/home'),
        ),
        title: Text(
          rutaData?['nombre'] ?? 'Detalles de la Ruta',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await _storage.delete(key: 'auth_token');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Sesión cerrada'),
                    backgroundColor: Colors.teal,
                  ),
                );
                // ignore: use_build_context_synchronously
                context.go('/');
              }
            },
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: isLoading
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.teal[700]!),
              ),
            )
          : rutaData == null
          ? const Center(child: Text('No se encontró la ruta'))
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          rutaData!['nombre'] ?? 'Sin nombre',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          rutaData!['descripcion'] ?? 'Sin descripción',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                  Container(
                    height: 400,
                    padding: const EdgeInsets.all(16.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(15),
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _markers.isNotEmpty
                              ? _markers.first.position
                              : const LatLng(0, 0),
                          zoom: 15,
                        ),
                        onMapCreated: (controller) {
                          _mapController = controller;
                          _setupMapData();
                        },
                        markers: _markers,
                        polylines: _polylines,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          // Aquí irá la lógica para ver la ubicación del camión
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cargando ubicación del camión...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(Icons.local_shipping),
                        label: const Text(
                          'Ver al camión',
                          style: TextStyle(fontSize: 16),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.teal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.grey)),
        ),
      ],
    );
  }

  String _formatFecha(dynamic fechaData) {
    if (fechaData is Map<String, dynamic> &&
        fechaData.containsKey('_seconds')) {
      final seconds = fechaData['_seconds'] as int;
      final nanoseconds = fechaData['_nanoseconds'] as int? ?? 0;
      final fecha = DateTime.fromMillisecondsSinceEpoch(
        seconds * 1000,
      ).add(Duration(microseconds: nanoseconds ~/ 1000));
      return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
    }
    return 'Fecha no disponible';
  }

  LatLngBounds _getBounds(List<LatLng> points) {
    double? minLat, maxLat, minLng, maxLng;

    for (final point in points) {
      if (minLat == null || point.latitude < minLat) minLat = point.latitude;
      if (maxLat == null || point.latitude > maxLat) maxLat = point.latitude;
      if (minLng == null || point.longitude < minLng) minLng = point.longitude;
      if (maxLng == null || point.longitude > maxLng) maxLng = point.longitude;
    }

    return LatLngBounds(
      southwest: LatLng(minLat!, minLng!),
      northeast: LatLng(maxLat!, maxLng!),
    );
  }
}
