// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:app_locacion/api/rutas_api.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Map<String, dynamic>>>? _futureRutas;
  final _storage = const FlutterSecureStorage();
  String? _userRol;
  String? _token;
  String? _userId;

  @override
  void initState() {
    super.initState();
    _initializeFutureRutas();
  }

  Future<void> _initializeFutureRutas() async {
    try {
      final token = await _storage.read(key: 'auth_token');
      final rol = await _storage.read(key: 'user_rol');
      final id = await _storage.read(key: 'user_id');

      if (token == null) {
        if (mounted) {
          context.go('/');
        }
        return;
      }

      if (mounted) {
        setState(() {
          _userRol = rol;
          _token = token;
          _userId = id;
          _futureRutas = _fetchRutas(token, rol, id);
        });
      }
    } catch (e) {
      print('Error al inicializar rutas: $e');
      if (mounted) {
        context.go('/');
      }
    }
  }

  Future<List<Map<String, dynamic>>> _fetchRutas(
    String token,
    String? rol,
    String? id,
  ) async {
    try {
      if (rol == 'conductor') {
        if (id == null) {
          throw Exception('ID de usuario no disponible');
        }
        final List<Map<String, dynamic>> rutasAsignadas =
            await RutasApi.listRutasAsignadas(token, id);

        // Map the conductor's data to match the structure of regular routes
        final List<Map<String, dynamic>> transformedRutas = rutasAsignadas.map((
          rutaAsignada,
        ) {
          return {
            'id': rutaAsignada['rutaId'], // Use 'rutaId' for navigation
            'nombre':
                'Ruta Asignada - ${rutaAsignada['dia_semana'] ?? 'Día Desconocido'}',
            'descripcion':
                'Asignada para el día ${rutaAsignada['dia_semana'] ?? 'sin especificar'}',
          };
        }).toList();

        return transformedRutas;
      } else {
        final rutas = await RutasApi.listRutas(token);
        return rutas;
      }
    } catch (e) {
      print('Error al obtener rutas: $e');
      rethrow;
    }
  }

  Future<void> _refreshRutas() async {
    if (_token != null && _userRol != null) {
      setState(() {
        _futureRutas = _fetchRutas(_token!, _userRol, _userId);
      });
    }
  }

  Future<void> _logout() async {
    try {
      await _storage.deleteAll();

      // Verificar que el token se eliminó correctamente
      final token = await _storage.read(key: 'auth_token');
      if (token != null) {
        throw Exception('No se pudo eliminar el token');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sesión cerrada exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cerrar sesión: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    String appBarTitle = _userRol == 'conductor'
        ? 'Mis Rutas Asignadas'
        : 'Rutas Disponibles';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          appBarTitle,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.teal[700],
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.teal[700]),
            onPressed: _logout,
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _futureRutas,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.teal[700]!,
                    ),
                    strokeWidth: 2.5,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Cargando rutas...',
                    style: TextStyle(color: Colors.grey[600], fontSize: 16),
                  ),
                ],
              ),
            );
          } else if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      'Error al cargar las rutas',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Por favor, intenta nuevamente',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _refreshRutas,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      child: const Text(
                        'Reintentar',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            final emptyMessage = _userRol == 'conductor'
                ? 'No tienes rutas asignadas en este momento.'
                : 'No hay rutas disponibles';
            final emptySubtitle = _userRol == 'conductor'
                ? 'Contacta al administrador para más información.'
                : 'Vuelve más tarde para descubrir nuevas rutas';

            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    size: 72,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    emptyMessage,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    emptySubtitle,
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshRutas,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal[700],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Actualizar',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            );
          } else {
            return RefreshIndicator(
              onRefresh: _refreshRutas,
              color: Colors.teal[700],
              child: ListView.builder(
                padding: const EdgeInsets.all(16.0),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final route = snapshot.data![index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16.0),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16.0),
                        onTap: () {
                          final rutaId = route['id']?.toString();
                          if (rutaId != null && rutaId.isNotEmpty) {
                            context.go('/rutaDetails/$rutaId');
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Error: ID de ruta no encontrado',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.teal[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.location_on,
                                  color: Colors.teal[700],
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      route['nombre'] ?? 'Ruta Desconocida',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 16,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      route['descripcion'] ?? 'Sin descripción',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                                color: Colors.grey[400],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          }
        },
      ),
    );
  }
}
