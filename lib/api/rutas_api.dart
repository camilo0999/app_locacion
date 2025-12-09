// lib/api/rutas_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

/// A static class to handle all API calls related to trash collection routes.
class RutasApi {
  // Base URL for the routes API.
  static const String baseUrl = 'https://server-location-1r1p.onrender.com/api';

  /// Fetches a list of all available trash collection routes from the API.
  ///
  /// This method requires a user authentication token to be provided.
  /// It makes a GET request to the '/rutas' endpoint with the token in the
  /// Authorization header and returns a list of maps, where each map
  /// represents a route.
  ///
  /// Throws an [Exception] if the API call fails or if the token is invalid.
  static Future<List<Map<String, dynamic>>> listRutas(String authToken) async {
    final url = Uri.parse('$baseUrl/rutas');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        // Decode the JSON response and cast it to a List of Maps.
        final List<dynamic> jsonList = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(jsonList);
      } else {
        // If the server returns an error, throw an exception.
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['error'] ?? 'Error desconocido al listar rutas',
        );
      }
    } catch (e) {
      // Handle network errors or other exceptions.
      throw Exception('Error de red: no se pudo conectar con el servidor.');
    }
  }

  /// Obtiene los detalles de una ruta específica por su ID.
  ///
  /// Este método requiere un token de autenticación y el ID de la ruta.
  /// Hace una petición GET al endpoint '/rutas/:id' con el token en el
  /// header de Authorization y retorna un Map con los detalles de la ruta.
  ///
  /// Parámetros:
  /// - [authToken]: Token de autenticación del usuario
  /// - [rutaId]: ID de la ruta que se quiere obtener
  ///
  /// Retorna un [Map<String, dynamic>] con los detalles de la ruta.
  /// Lanza una [Exception] si la petición falla o si el token es inválido.
  static Future<Map<String, dynamic>> getRuta(
    String authToken,
    String rutaId,
  ) async {
    final url = Uri.parse('$baseUrl/rutas/$rutaId');

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
      );

      if (response.statusCode == 200) {
        // Decodifica la respuesta JSON
        final Map<String, dynamic> ruta = jsonDecode(response.body);
        return ruta;
      } else if (response.statusCode == 404) {
        throw Exception('La ruta especificada no fue encontrada');
      } else {
        // Si el servidor retorna un error, lanza una excepción
        final errorBody = jsonDecode(response.body);
        throw Exception(
          errorBody['error'] ?? 'Error desconocido al obtener la ruta',
        );
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de red: no se pudo conectar con el servidor');
    }
  }

  /// Actualiza la ubicación actual de un camión durante la transmisión.
  ///
  /// Este método envía la ubicación actual del conductor al servidor
  /// para registrar su posición en tiempo real.
  ///
  /// Parámetros:
  /// - [authToken]: Token de autenticación del usuario
  /// - [rutaId]: ID de la ruta para la que se actualiza la ubicación
  /// - [latitude]: Latitud de la ubicación actual
  /// - [longitude]: Longitud de la ubicación actual
  ///
  /// Retorna un [Map<String, dynamic>] con la respuesta del servidor.
  /// Lanza una [Exception] si la petición falla.
  static Future<Map<String, dynamic>> actualizarUbicacion(
    String authToken,
    String rutaId,
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse('$baseUrl/rutas/$rutaId/ubicacion');

    try {
      final body = jsonEncode({
        'ubicacion_actual': {
          'lat': latitude,
          'lng': longitude,
        }
      });

      // DEBUG: Mostrar lo que se está enviando
      print('════════════════════════════════════');
      print('🔍 DEBUG: Actualizar Ubicación');
      print('════════════════════════════════════');
      print('URL: $url');
      print('RutaId: $rutaId');
      print('Latitude: $latitude (tipo: ${latitude.runtimeType})');
      print('Longitude: $longitude (tipo: ${longitude.runtimeType})');
      print('Token: ${authToken.substring(0, 20)}...');
      print('Body JSON enviado:');
      print(body);
      print('════════════════════════════════════');

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');
      print('════════════════════════════════════');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Decodifica la respuesta JSON
        final Map<String, dynamic> resultado = jsonDecode(response.body);
        return resultado;
      } else if (response.statusCode == 401) {
        throw Exception('Autenticación inválida. Token expirado o no válido.');
      } else if (response.statusCode == 404) {
        throw Exception('Ruta no encontrada.');
      } else if (response.statusCode == 400) {
        // Error 400: mostrar el mensaje del servidor
        try {
          final errorBody = jsonDecode(response.body);
          final mensaje = errorBody['message'] ?? 'Error de validación';
          throw Exception('Error 400: $mensaje');
        } catch (e) {
          throw Exception(e.toString());
        }
      } else {
        // Si el servidor retorna otro error, lanza una excepción
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
            errorBody['message'] ?? 'Error desconocido al actualizar ubicación',
          );
        } catch (e) {
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de red: no se pudo conectar con el servidor');
    }
  }

  /// Cambia el estado de una ruta.
  ///
  /// Este método cambia el estado de una ruta (e.g., 'pendiente' a 'en_curso').
  ///
  /// Parámetros:
  /// - [authToken]: Token de autenticación del usuario
  /// - [rutaId]: ID de la ruta cuyo estado se cambiará
  /// - [nuevoEstado]: El nuevo estado de la ruta (e.g., 'en_curso')
  ///
  /// Retorna un [Map<String, dynamic>] con la respuesta del servidor.
  /// Lanza una [Exception] si la petición falla.
  static Future<Map<String, dynamic>> cambiarEstadoRuta(
    String authToken,
    String rutaId,
    String nuevoEstado,
  ) async {
    final url = Uri.parse('$baseUrl/rutas/$rutaId/estado');

    try {
      final body = jsonEncode({
        'estado': nuevoEstado,
      });

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      );

      print('════════════════════════════════════');
      print('🔍 DEBUG: Cambiar Estado Ruta');
      print('════════════════════════════════════');
      print('URL: $url');
      print('RutaId: $rutaId');
      print('Nuevo Estado: $nuevoEstado');
      print('Response Status: ${response.statusCode}');
      print('Response Body: ${response.body}');
      print('════════════════════════════════════');

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Decodifica la respuesta JSON
        final Map<String, dynamic> resultado = jsonDecode(response.body);
        return resultado;
      } else if (response.statusCode == 401) {
        throw Exception('Autenticación inválida. Token expirado o no válido.');
      } else if (response.statusCode == 404) {
        throw Exception('Ruta no encontrada.');
      } else if (response.statusCode == 400) {
        try {
          final errorBody = jsonDecode(response.body);
          final mensaje = errorBody['message'] ?? 'Error de validación';
          throw Exception('Error 400: $mensaje');
        } catch (e) {
          throw Exception(e.toString());
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
            errorBody['message'] ?? 'Error desconocido al cambiar estado',
          );
        } catch (e) {
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Error de red: no se pudo conectar con el servidor');
    }
  }

  /// Obtiene la última ubicación registrada de una ruta.
  ///
  /// Parámetros:
  /// - [authToken]: Token de autenticación
  /// - [rutaId]: ID de la ruta
  ///
  /// Retorna un [Map<String, dynamic>] con estructura:
  /// {
  ///   "ubicacion_actual": {
  ///     "lat": double,
  ///     "lng": double
  ///   }
  /// }
  static Future<Map<String, dynamic>> obtenerUltimaUbicacion(
    String authToken,
    String rutaId,
  ) async {
    final url = Uri.parse('$baseUrl/rutas/$rutaId/ultima-ubicacion');

    try {
      print('════════════════════════════════════');
      print('🔍 DEBUG: Obtener Última Ubicación');
      print('URL: $url');
      print('════════════════════════════════════');

      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');
      print('════════════════════════════════════');

      if (response.statusCode == 200) {
        final Map<String, dynamic> resultado = jsonDecode(response.body);
        return resultado;
      } else if (response.statusCode == 401) {
        throw Exception('Autenticación inválida. Token expirado o no válido.');
      } else if (response.statusCode == 404) {
        throw Exception('No se encontró ubicación para esta ruta.');
      } else {
        throw Exception('Error ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de red: no se pudo conectar con el servidor');
    }
  }

  /// Inicia la transmisión para una ruta utilizando el endpoint `/iniciar`.
  ///
  /// Parámetros:
  /// - [authToken]: Token de autenticación
  /// - [rutaId]: ID de la ruta a iniciar
  /// - [latitude]: Latitud de la ubicación inicial
  /// - [longitude]: Longitud de la ubicación inicial
  static Future<Map<String, dynamic>> iniciarTransmision(
    String authToken,
    String rutaId,
    double latitude,
    double longitude,
  ) async {
    final url = Uri.parse('$baseUrl/rutas/$rutaId/iniciar');

    try {
      print('════════════════════════════════════');
      print('🔍 DEBUG: Iniciar Transmisión');
      print('URL: $url');
      print('RutaId: $rutaId');
      print('Token: ${authToken.substring(0, authToken.length > 20 ? 20 : authToken.length)}...');
      print('════════════════════════════════════');

      final body = jsonEncode({
        'ubicacion_actual': {
          'lat': latitude,
          'lng': longitude,
        }
      });

      print('Body JSON enviado (iniciar):');
      print(body);

      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $authToken',
        },
        body: body,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📡 Response Body: ${response.body}');
      print('════════════════════════════════════');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> resultado = jsonDecode(response.body);
        return resultado;
      } else if (response.statusCode == 401) {
        throw Exception('Autenticación inválida. Token expirado o no válido.');
      } else if (response.statusCode == 404) {
        throw Exception('Ruta no encontrada.');
      } else if (response.statusCode == 400) {
        try {
          final errorBody = jsonDecode(response.body);
          final mensaje = errorBody['message'] ?? 'Error de validación';
          throw Exception('Error 400: $mensaje');
        } catch (e) {
          throw Exception(e.toString());
        }
      } else {
        try {
          final errorBody = jsonDecode(response.body);
          throw Exception(
            errorBody['message'] ?? 'Error desconocido al iniciar transmisión',
          );
        } catch (e) {
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      }
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Error de red: no se pudo conectar con el servidor');
    }
  }
}
