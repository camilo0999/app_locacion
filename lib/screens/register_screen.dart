// lib/screens/register_screen.dart
import 'package:app_locacion/api/auth_api.dart';
import 'package:app_locacion/widgets/custom_input.dart';
import 'package:app_locacion/widgets/custom_button.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _docTypeController = TextEditingController();
  final TextEditingController _docNumberController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final Map<String, dynamic> userData = {
        'email': _emailController.text,
        'password': _passwordController.text,
        'nombre': _nameController.text,
        'apellidos': _lastNameController.text,
        'tipo_documento': _docTypeController.text,
        'numero_documento': _docNumberController.text,
        'ciudad': _cityController.text,
        'comuna': _neighborhoodController.text,
        'rol': 'persona',
      };

      try {
        final Map<String, dynamic> response = await AuthApi.register(userData);
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message']),
            backgroundColor: response['success'] ? Colors.green : Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        if (response['success']) {
          // ignore: use_build_context_synchronously
          Navigator.pop(context);
        }
      } catch (e) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Error al registrar. Por favor, inténtalo de nuevo.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Registro'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Text(
                'Crea tu cuenta',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: Colors.grey[800],
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Completa el formulario para unirte a nosotros',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 48),
              Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    CustomInput(
                      controller: _nameController,
                      labelText: 'Nombre',
                      hintText: 'Ingresa tu nombre',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu nombre';
                        }
                        return null;
                      },
                      suffixIcon: _nameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _nameController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _lastNameController,
                      labelText: 'Apellidos',
                      hintText: 'Ingresa tus apellidos',
                      icon: Icons.person_outline,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tus apellidos';
                        }
                        return null;
                      },
                      suffixIcon: _lastNameController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _lastNameController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _emailController,
                      labelText: 'Correo Electrónico',
                      hintText: 'ejemplo@correo.com',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu correo';
                        }
                        if (!value.contains('@')) {
                          return 'Por favor, ingresa un correo válido';
                        }
                        return null;
                      },
                      suffixIcon: _emailController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _emailController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _passwordController,
                      labelText: 'Contraseña',
                      hintText: 'Ingresa tu contraseña',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: Colors.grey[500],
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                      validator: (value) {
                        if (value == null ||
                            value.isEmpty ||
                            value.length < 6) {
                          return 'La contraseña debe tener al menos 6 caracteres';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _docTypeController,
                      labelText: 'Tipo de Documento',
                      hintText: 'Ej: Cédula de Ciudadanía',
                      icon: Icons.assignment_ind_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el tipo de documento';
                        }
                        return null;
                      },
                      suffixIcon: _docTypeController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _docTypeController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _docNumberController,
                      labelText: 'Número de Documento',
                      hintText: 'Ingresa el número de documento',
                      icon: Icons.credit_card_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa el número de documento';
                        }
                        return null;
                      },
                      suffixIcon: _docNumberController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _docNumberController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _cityController,
                      labelText: 'Ciudad',
                      hintText: 'Ej: Medellín',
                      icon: Icons.location_city_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu ciudad';
                        }
                        return null;
                      },
                      suffixIcon: _cityController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _cityController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 20),
                    CustomInput(
                      controller: _neighborhoodController,
                      labelText: 'Comuna',
                      hintText: 'Ej: Comuna 13',
                      icon: Icons.location_on_outlined,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Por favor, ingresa tu comuna';
                        }
                        return null;
                      },
                      suffixIcon: _neighborhoodController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _neighborhoodController.clear();
                              },
                            )
                          : null,
                    ),
                    const SizedBox(height: 40),
                    _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.teal[700]!,
                              ),
                            ),
                          )
                        : CustomButton(
                            text: 'Registrarse',
                            onPressed: _register,
                            backgroundColor: Colors.teal[700],
                            foregroundColor: Colors.white,
                            elevation: 2,
                          ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        context.go('/login');
                      },
                      child: Text(
                        '¿Ya tienes una cuenta? Inicia sesión aquí',
                        style: TextStyle(
                          color: Colors.teal[700],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
