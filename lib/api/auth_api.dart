// lib/api/auth_api.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthApi {
  // Base URL for the authentication API
  static const String baseUrl = 'https://server-location-1r1p.onrender.com/api';

  /// Handles the user login request.
  /// Sends a POST request with email and password to the server.
  /// Returns a map indicating success or failure, along with a message and token.
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    try {
      final url = Uri.parse('$baseUrl/login');
      final requestBody = jsonEncode({'email': email, 'password': password});

      final response = await http
          .post(
            url,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Accept': 'application/json',
            },
            body: requestBody,
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('La solicitud tardó demasiado');
            },
          );

      final decodedResponse = jsonDecode(response.body);

      if (response.statusCode == 200) {
        if (decodedResponse['token'] == null) {
          return {
            'success': false,
            'message': 'No se recibió el token de autenticación',
          };
        }

        return {
          'success': true,
          'message': decodedResponse['message'] ?? 'Inicio de sesión exitoso',
          'token': decodedResponse['token'],
          'user': decodedResponse['user'],
        };
      } else {
        return {
          'success': false,
          'message':
              decodedResponse['error'] ??
              'Error del servidor: ${response.statusCode}',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error de conexión: ${e.toString()}',
      };
    }
  }

  /// Handles the user registration request.
  /// Sends a POST request with user data to the server.
  /// Returns a map indicating success or failure, along with a message.
  static Future<Map<String, dynamic>> register(
    Map<String, dynamic> userData,
  ) async {
    final url = Uri.parse('$baseUrl/register');
    final response = await http.post(
      url,
      headers: <String, String>{
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode(userData),
    );

    if (response.statusCode == 201) {
      // User created successfully
      final responseBody = jsonDecode(response.body);
      return {'success': true, 'message': responseBody['message']};
    } else {
      // Registration failed
      final errorBody = jsonDecode(response.body);
      return {
        'success': false,
        'message': errorBody['error'] ?? 'Error desconocido',
      };
    }
  }
}
