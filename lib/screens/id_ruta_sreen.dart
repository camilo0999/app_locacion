// lib/screens/id_ruta_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

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
  String? _userRole;
  Map<String, dynamic>? _calleSeleccionada;
  int? _calleSeleccionadaIndex;
  bool _mapaCargado = false; // Nueva variable para controlar estado del mapa

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
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        final role = await _storage.read(key: 'user_role');
        print('DEBUG: Rol leído desde storage: $role');

        setState(() {
          _userRole = role;
        });
      }
    } catch (e) {
      print('Error al cargar el rol del usuario: $e');
    }
  }

  bool get _isConductor => _userRole == 'conductor';

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
            // Verificar si el mapa se ha terminado de cargar
            if (!state.isMapLoading && !_mapaCargado) {
              // El mapa se terminó de cargar, ahora podemos buscar ubicación si la ruta está en curso
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  setState(() {
                    _mapaCargado = true;
                  });
                  
                  // Si la ruta está en curso, buscar ubicación automáticamente
                  if (state.rutaData?['estado'] == 'en_curso') {
                    _buscarUbicacionCamionAutomaticamente(state);
                  }
                }
              });
            }

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

            final bool rutaEnCurso = state.rutaData?['estado'] == 'en_curso';

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
                        // Estado de la ruta
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(state.rutaData!['estado']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getEstadoText(state.rutaData!['estado']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        // Indicador de si se puede obtener ubicación
                        if (!rutaEnCurso) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: Colors.orange[700],
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'La ubicación del camión solo está disponible cuando la ruta está en curso',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: 13,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            ],
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
                            mapController: state.mapController,
                            options: MapOptions(
                              initialCenter: state.initialPosition,
                              initialZoom: state.isMapLoading ? 10.0 : 14.0,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                userAgentPackageName: 'com.example.app_locacion',
                              ),
                              PolylineLayer(
                                polylines: state.polylines,
                              ),
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
                    child: Column(
                      children: [
                        // Selector de Calles (para todos los usuarios)
                        Consumer<RutaMapState>(
                          builder: (context, state, child) {
                            final calles = state.calles;
                            if (calles.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                              ),
                              child: DropdownButton<int>(
                                isExpanded: true,
                                underline: const SizedBox(),
                                hint: Text(
                                  'Selecciona una calle',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                                value: _calleSeleccionadaIndex,
                                items: List.generate(calles.length, (index) {
                                  final calle = calles[index];
                                  return DropdownMenuItem<int>(
                                    value: index,
                                    child: Text(
                                      calle['nombre'] ?? 'Calle sin nombre',
                                      style: const TextStyle(color: Colors.black87),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (index) {
                                  if (index != null &&
                                      index >= 0 &&
                                      index < calles.length) {
                                    final calle = calles[index];
                                    setState(() {
                                      _calleSeleccionadaIndex = index;
                                      _calleSeleccionada = calle;
                                    });
                                    print(
                                        'DEBUG: Calle seleccionada: ${calle['nombre']} (${calle['lat']}, ${calle['lng']})');
                                  }
                                },
                              ),
                            );
                          },
                        ),
                        // Botón para ver última ubicación del camión - SOLO si ruta en curso
                        if (rutaEnCurso)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => _buscarUbicacionCamionManual(state),
                              icon: const Icon(
                                Icons.local_shipping_rounded,
                                size: 26,
                              ),
                              label: const Text(
                                'Ver Ubicación del Camión',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple[700],
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          )
                        else
                          // Mensaje informativo cuando la ruta no está en curso
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(12),
                              
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: Colors.orange[700],
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'La ubicación del camión solo está disponible cuando la ruta está en curso',
                                    style: TextStyle(
                                      color: Colors.orange[800],
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 16),
                        // Botones solo para conductores
                        if (_isConductor) ...[
                          // Botón Iniciar Ruta - Solo visible si estado != 'en_curso' y != 'finalizada'
                          if (state.rutaData?['estado'] != 'en_curso' &&
                              state.rutaData?['estado'] != 'finalizada')
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  try {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Row(
                                          children: [
                                            SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<Color>(
                                                  Colors.white,
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 16),
                                            Text('Iniciando ruta...'),
                                          ],
                                        ),
                                        backgroundColor: Colors.green[700],
                                        behavior: SnackBarBehavior.floating,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );

                                    await state.iniciarRuta();
                                  } catch (e) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Error: ${e.toString()}'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 28,
                                ),
                                label: const Text(
                                  'Iniciar Ruta',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          
                          // Botón Actualizar Ubicación - Solo visible si estado == 'en_curso'
                          if (state.rutaData?['estado'] == 'en_curso')
                            Column(
                              children: [
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: ElevatedButton.icon(
                                    onPressed: () async {
                                      try {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Row(
                                              children: [
                                                SizedBox(
                                                  width: 20,
                                                  height: 20,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                            Color>(
                                                      Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Text('Actualizando ubicación...'),
                                              ],
                                            ),
                                            backgroundColor: Colors.blue[700],
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );

                                        double? selLat;
                                        double? selLng;
                                        if (_calleSeleccionada != null) {
                                          try {
                                            selLat = (_calleSeleccionada!['lat']
                                                    as num)
                                                .toDouble();
                                            selLng = (_calleSeleccionada!['lng']
                                                    as num)
                                                .toDouble();
                                          } catch (_) {
                                            selLat = null;
                                            selLng = null;
                                          }
                                        }

                                        if (selLat != null && selLng != null) {
                                          print(
                                              'DEBUG: Enviando coords de la calle seleccionada: ($selLat, $selLng)');
                                          await state.iniciarTransmision(
                                              latitude: selLat,
                                              longitude: selLng);
                                        } else {
                                          print(
                                              'DEBUG: No hay calle seleccionada, se enviará punto_partida');
                                          await state.iniciarTransmision();
                                        }
                                      } catch (e) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    icon: const Icon(
                                      Icons.location_on_rounded,
                                      size: 28,
                                    ),
                                    label: const Text(
                                      'Actualizar Ubicación',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue[700],
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),

                          // Botón Finalizar Transmisión - Solo visible si estado == 'en_curso'
                          if (state.rutaData?['estado'] == 'en_curso')
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  // Mostrar diálogo de confirmación
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Finalizar Transmisión'),
                                      content: const Text(
                                          '¿Estás seguro de que deseas finalizar la transmisión de ubicación? Esta acción no se puede deshacer.'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(false),
                                          child: const Text('Cancelar'),
                                        ),
                                        ElevatedButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red[700],
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Finalizar'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    try {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: const Row(
                                            children: [
                                              SizedBox(
                                                width: 20,
                                                height: 20,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(
                                                    Colors.white,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 16),
                                              Text('Finalizando transmisión...'),
                                            ],
                                          ),
                                          backgroundColor: Colors.red[700],
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          duration: const Duration(seconds: 2),
                                        ),
                                      );

                                      await state.finalizarTransmision();

                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Row(
                                              children: [
                                                Icon(Icons.check_circle,
                                                    color: Colors.white),
                                                SizedBox(width: 12),
                                                Text(
                                                    'Transmisión finalizada exitosamente'),
                                              ],
                                            ),
                                        
                                            behavior: SnackBarBehavior.floating,
                                            duration: Duration(seconds: 3),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(context)
                                            .clearSnackBars();
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content:
                                                Text('Error: ${e.toString()}'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                icon: const Icon(
                                  Icons.stop_rounded,
                                  size: 28,
                                ),
                                label: const Text(
                                  'Finalizar Transmisión',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red[700],
                                  foregroundColor: Colors.white,
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
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

  // Método para buscar ubicación automáticamente (después de cargar el mapa)
  Future<void> _buscarUbicacionCamionAutomaticamente(RutaMapState state) async {
    try {
      print('🔄 Buscando ubicación del camión automáticamente (mapa cargado)...');
      await state.obtenerUltimaUbicacion();
    } catch (e) {
      print('⚠️ Error al buscar ubicación automáticamente: $e');
      // No mostrar error al usuario en búsqueda automática
    }
  }

  // Método para buscar ubicación manualmente (cuando el usuario presiona el botón)
  Future<void> _buscarUbicacionCamionManual(RutaMapState state) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Colors.white,
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text('Localizando camión...'),
            ],
          ),
          backgroundColor: Colors.purple[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      await state.obtenerUltimaUbicacion();

      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Ubicación del camión cargada en el mapa'),
              ],
            ),
            backgroundColor: Colors.purple[700],
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Métodos auxiliares para mostrar el estado
  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return Colors.orange;
      case 'en_curso':
        return Colors.green;
      case 'finalizada':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _getEstadoText(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'PENDIENTE';
      case 'en_curso':
        return 'EN CURSO';
      case 'finalizada':
        return 'FINALIZADA';
      default:
        return estado.toUpperCase();
    }
  }
}