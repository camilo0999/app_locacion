import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:app_locacion/screens/login_screen.dart';
import 'package:app_locacion/screens/register_screen.dart';
import 'package:app_locacion/screens/home_screen.dart';
import 'package:app_locacion/screens/id_ruta_sreen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MyApp());
}

final GoRouter _router = GoRouter(
  initialLocation: '/',
  redirect: (context, state) async {
    // Obtener el token almacenado
    final token = await const FlutterSecureStorage().read(key: 'auth_token');
    final isLoginRoute = state.matchedLocation == '/';
    final isRegisterRoute = state.matchedLocation == '/register';

    // Si no hay token y no estamos en login o registro, redirigir a login
    if (token == null && !isLoginRoute && !isRegisterRoute) {
      return '/';
    }

    // Si hay token y estamos en login, redirigir a home
    if (token != null && isLoginRoute) {
      return '/home';
    }

    return null;
  },
  routes: [
    GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
    GoRoute(
      path: '/rutaDetails/:rutaId',
      builder: (context, state) {
        final rutaId = state.pathParameters['rutaId']!;
        return FutureBuilder<String?>(
          future: const FlutterSecureStorage().read(key: 'auth_token'),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!snapshot.hasData || snapshot.data == null) {
              return const Scaffold(
                body: Center(
                  child: Text('No se encontró el token de autenticación'),
                ),
              );
            }

            return IdRutaScreen(rutaId: rutaId);
          },
        );
      },
    ),
  ],
);

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
      title: 'App de Gestión de Residuos',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Inter',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.teal,
        ),
      ),
    );
  }
}
