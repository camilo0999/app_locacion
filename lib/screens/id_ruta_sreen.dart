// lib/screens/id_ruta_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// NUEVAS IMPORTACIONES
import 'package:flutter_map/flutter_map.dart'; 
import 'package:latlong2/latlong.dart';
// FIN NUEVAS IMPORTACIONES

import '../states/ruta_map_state.dart';

class IdRutaScreen extends StatefulWidget {
  final String rutaId;

  const IdRutaScreen({super.key, required this.rutaId});

  @override
  State<IdRutaScreen> createState() => _IdRutaScreenState();
}

class _IdRutaScreenState extends State<IdRutaScreen> {
  final _storage = const FlutterSecureStorage();
  late final RutaMapState _rutaMapState;

  @override
  void initState() {
    super.initState();
    _rutaMapState = RutaMapState(
      rutaId: widget.rutaId,
      onShowMessage: (message, {isError = false}) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: isError ? Colors.red : Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
          ),
        );
      },
    );
    _rutaMapState.loadRutaDetails();
  }

  @override
  void dispose() {
    _rutaMapState.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RutaMapState>.value(
      value: _rutaMapState,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded),
            onPressed: () => context.go('/home'),
          ),
          title: Consumer<RutaMapState>(
            builder: (context, state, child) {
              return Text(
                state.rutaData?['nombre'] ?? 'Detalles de la Ruta',
                style: const TextStyle(fontWeight: FontWeight.w600),
              );
            },
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.teal[700],
          actions: [
            Consumer<RutaMapState>(
              builder: (context, state, child) {
                if (!state.isLoading && !state.isMapLoading) {
                  return IconButton(
                    icon: const Icon(Icons.refresh_rounded),
                    onPressed: state.refreshRoute,
                    tooltip: 'Actualizar ruta',
                  );
                }
                return const SizedBox();
              },
            ),
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              onPressed: () async {
                await _storage.delete(key: 'auth_token');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Sesión cerrada'),
                      backgroundColor: Colors.teal,
                    ),
                  );
                  context.go('/');
                }
              },
              tooltip: 'Cerrar sesión',
            ),
          ],
        ),
        body: Consumer<RutaMapState>(
          builder: (context, state, child) {
            if (state.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.teal[700]!,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Cargando información de la ruta...',
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            if (state.rutaData == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline_rounded,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'No se encontró la ruta',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => context.go('/home'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Volver al inicio'),
                    ),
                  ],
                ),
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.route_rounded,
                              color: Colors.teal[700],
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                state.rutaData!['nombre'] ?? 'Sin nombre',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[900],
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (state.rutaData!['descripcion'] != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.rutaData!['descripcion'],
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              height: 1.5,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    height: 450,
                    margin: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                     
                    ),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: FlutterMap(
                            // Usamos el controlador del State
                            mapController: state.mapController, 
                            options: MapOptions(
                              // Usamos el LatLng de latlong2
                              initialCenter: state.initialPosition,
                              initialZoom: state.isMapLoading ? 10.0 : 14.0,
                            ),
                            children: [
                              // 1. Capa de Tiles (OpenStreetMap) - El mapa base
                              TileLayer(
                                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app_locacion', 
                              ),
                              // 2. Capa de Polilíneas
                              PolylineLayer(
                                polylines: state.polylines, 
                              ),
                              // 3. Capa de Marcadores
                              MarkerLayer(
                                markers: state.markers, 
                              ),
                            ],
                          ),
                        ),
                        if (state.isMapLoading)
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                    strokeWidth: 3,
                                  ),
                                  SizedBox(height: 20),
                                  Text(
                                    'Trazando ruta por las calles...',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (!state.isMapLoading && state.routePoints.isNotEmpty)
                          Positioned(
                            right: 16,
                            bottom: 16,
                            child: FloatingActionButton.small(
                              onPressed: state.fitMapToRoute,
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.teal[700],
                              child: const Icon(
                                Icons.center_focus_strong_rounded,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Row(
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16),
                                  Text('Localizando camión...'),
                                ],
                              ),
                              backgroundColor: Colors.teal[700],
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.local_shipping_rounded,
                          size: 28,
                        ),
                        label: const Text(
                          'Ver ubicación del camión',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal[700],
                          foregroundColor: Colors.white,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}