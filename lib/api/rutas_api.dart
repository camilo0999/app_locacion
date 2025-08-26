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
}
