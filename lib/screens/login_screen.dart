import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/auth_service.dart';
import '../services/local_auth_service.dart';

// Clase para pintar el logo de Google
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Colores oficiales de Google
    const blue = Color(0xFF4285F4);
    const green = Color(0xFF34A853);
    const yellow = Color(0xFFFBBC05);
    const red = Color(0xFFEA4335);

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Parte azul (superior izquierda)
    paint.color = blue;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.57, // -90 grados en radianes
      1.57, // 90 grados
      true,
      paint,
    );

    // Parte verde (inferior izquierda)
    paint.color = green;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0, // 0 grados
      1.57, // 90 grados
      true,
      paint,
    );

    // Parte amarilla (inferior derecha)
    paint.color = yellow;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      1.57, // 90 grados
      1.57, // 90 grados
      true,
      paint,
    );

    // Parte roja (superior derecha)
    paint.color = red;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      3.14, // 180 grados
      1.57, // 90 grados
      true,
      paint,
    );

    // Círculo blanco central para crear el efecto "G"
    paint.color = Colors.white;
    canvas.drawCircle(center, radius * 0.6, paint);

    // Línea blanca horizontal (parte de la "G")
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.35, size.height * 0.5, size.width * 0.3,
          size.height * 0.15),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isOfflineMode = false;
  bool _hasLocalSession = false;
  bool _hasPin = false;
  final _pinController = TextEditingController();
  final List<TextEditingController> _pinControllers = [];
  final List<FocusNode> _pinFocusNodes = [];
  final _localAuth = LocalAuthService();
  final _connectivity = Connectivity();

  @override
  void initState() {
    super.initState();
    // Inicializar controladores y nodos de foco para los campos PIN
    // Usar controladores separados para evitar duplicación
    for (int i = 0; i < 6; i++) {
      _pinControllers.add(TextEditingController());
      _pinFocusNodes.add(FocusNode());
    }

    // Verificar estado del AuthService primero
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeLoginScreen();
    });
  }

  Future<void> _initializeLoginScreen() async {
    // Verificar si hay un usuario autenticado - si hay, redirigir al dashboard
    final authService = context.read<AuthService>();
    if (authService.isAuthenticated && authService.currentUserModel != null) {
      if (mounted) {
        context.go('/dashboard');
        return;
      }
    }

    // Si no hay usuario autenticado, verificar conexión y sesión local
    await _checkConnectionAndSession();
  }

  Future<void> _checkConnectionAndSession() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    final hasConnection = connectivityResult != ConnectivityResult.none;
    final hasSession = await _localAuth.hasLocalSession();
    final hasPinConfigured = await _localAuth.hasPinConfigured();

    if (!mounted) return;
    setState(() {
      _isOfflineMode = !hasConnection;
      _hasLocalSession = hasSession;
      _hasPin = hasPinConfigured;
    });

    // Solo mostrar PIN automáticamente si NO hay conexión (modo offline con sesión guardada)
    // Si hay conexión, dejar que el usuario inicie sesión con Google primero
    if (!hasConnection) {
      // Si hay sesión local con PIN configurado y NO hay conexión, solicitar PIN
      if (hasSession && hasPinConfigured && mounted) {
        // Esperar un momento para que la UI se renderice completamente
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          _showPinInput();
        }
        return;
      }

      // Si hay sesión local y no hay conexión y NO hay PIN, intentar auto-login
      if (hasSession && !hasPinConfigured) {
        _signInOffline();
      }
    }
    // Si hay conexión, no mostrar PIN automáticamente - dejar que el usuario elija iniciar con Google
  }

  Future<void> _signInWithGoogle() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();

      // Primero intentar autenticación con Google
      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // Preguntar si desea configurar PIN
        final configurePin = await _showPinConfigurationDialog();
        if (configurePin == true && mounted) {
          await _configurePin();
        }

        // Redirigir al dashboard inmediatamente - el usuario ya está autenticado
        // signInWithGoogle ya establece currentUserModel antes de retornar
        if (mounted && authService.currentUserModel != null) {
          context.go('/dashboard');
        } else if (mounted) {
          // Si por alguna razón no está cargado, esperar un momento
          await Future.delayed(const Duration(milliseconds: 200));
          if (mounted && authService.currentUserModel != null) {
            context.go('/dashboard');
          }
        }
      }
    } catch (e) {
      // El error puede ser de Supabase (recursión infinita en políticas)
      // pero el usuario local debería estar creado, así que intentar continuar
      if (mounted) {
        final authService = context.read<AuthService>();
        // Verificar si el usuario se cargó localmente a pesar del error
        if (authService.currentUserModel != null) {
          // El usuario está disponible localmente, continuar al dashboard
          context.go('/dashboard');
        } else {
          // Solo mostrar error si realmente no hay usuario
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Error al iniciar sesión: ${e.toString().contains("infinite recursion") ? "Error de configuración del servidor. Usando sesión local." : e}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signInOffline({String? pin}) async {
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      // Verificar primero que haya sesión local disponible
      final hasSession = await _localAuth.hasLocalSession();
      if (!hasSession) {
        setState(() => _isLoading = false);
        setState(() {
          _hasLocalSession = false;
          _hasPin = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No hay sesión guardada. Por favor inicia sesión con Google.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      final authService = context.read<AuthService>();
      final user = await authService.signInOffline(pin: pin);

      if (user != null && mounted) {
        // Esperar un momento para asegurar que el estado se actualice
        await Future.delayed(const Duration(milliseconds: 100));

        // Verificar que el usuario esté realmente cargado en el AuthService
        if (authService.currentUserModel != null) {
          // Navegar al dashboard
          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          // Si no está cargado, forzar recarga
          await authService.reloadCurrentUser();
          if (mounted && authService.currentUserModel != null) {
            context.go('/dashboard');
          } else {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Error al cargar usuario. Por favor inicia sesión con Google.'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 4),
                ),
              );
            }
          }
        }
      } else if (mounted) {
        setState(() => _isLoading = false);
        // Limpiar estado de sesión local si no hay usuario
        setState(() {
          _hasLocalSession = false;
          _hasPin = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No hay sesión guardada. Por favor inicia sesión con Google.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Limpiar estado de sesión local si hay error
      final hasSession = await _localAuth.hasLocalSession();
      if (!mounted) return;
      if (!hasSession) {
        setState(() {
          _hasLocalSession = false;
          _hasPin = false;
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool?> _showPinConfigurationDialog() async {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Configurar PIN'),
        content: const Text(
            '¿Deseas configurar un PIN para acceso rápido sin conexión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ahora no'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, configurar'),
          ),
        ],
      ),
    );
  }

  Future<bool> _configurePin() async {
    if (!mounted) return false;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const _PinDialog(isSetup: true),
    );

    if (result != null && result['action'] == 'save') {
      final pin = result['pin'] as String?;
      if (pin != null && pin.isNotEmpty && mounted) {
        try {
          final authService = context.read<AuthService>();
          await authService.setPin(pin);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN configurado exitosamente'),
                duration: Duration(seconds: 2),
              ),
            );
            return true;
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error al configurar PIN: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    }
    return false;
  }

  Future<void> _showPinInput({bool showForgotPin = true}) async {
    // Primero mostrar el diálogo para ingresar el PIN
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _PinInputDialog(showForgotPin: showForgotPin),
    );

    if (result != null) {
      if (result['action'] == 'forgot_pin') {
        // El usuario quiere restablecer el PIN
        await _resetPinWithGoogleAuth();
        return;
      }

      final action = result['action'] as String?;
      final pin = result['pin'] as String?;

      if (action == 'login' && pin != null && pin.isNotEmpty) {
        // Actualizar el controlador para mostrar los puntos
        if (mounted) {
          setState(() {
            _pinController.text = pin;
            _isLoading = true;
          });
        }

        final isValid = await _localAuth.authenticateWithPin(pin);

        if (!isValid) {
          if (mounted) {
            setState(() {
              _isLoading = false;
              _pinController.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('PIN incorrecto'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // PIN correcto, ahora cargar el usuario usando signInOffline
        // Este método carga el usuario local guardado correctamente
        await _signInOffline(pin: pin);
      }
    }
  }

  Future<void> _resetPinWithGoogleAuth() async {
    if (!mounted) return;

    // Mostrar diálogo de confirmación
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restablecer PIN'),
        content: const Text(
          'Para restablecer tu PIN, necesitas autenticarte con Google primero para verificar tu identidad.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
              foregroundColor: Colors.white,
            ),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final authService = context.read<AuthService>();

      // Autenticarse con Google
      final user = await authService.signInWithGoogle();

      if (!mounted) return;

      if (user != null) {
        // Ahora permitir configurar un nuevo PIN
        final result = await showDialog<Map<String, dynamic>>(
          context: context,
          builder: (context) => const _PinDialog(isSetup: true),
        );

        if (result != null && result['action'] == 'save') {
          final newPin = result['pin'] as String?;
          if (newPin != null && newPin.isNotEmpty && mounted) {
            try {
              await authService.setPin(newPin);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN restablecido exitosamente'),
                    backgroundColor: Colors.green,
                    duration: Duration(seconds: 2),
                  ),
                );
              }

              // Actualizar el estado
              setState(() {
                _hasPin = true;
              });

              // Redirigir al dashboard
              if (mounted && authService.currentUserModel != null) {
                context.go('/dashboard');
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error al restablecer PIN: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } else if (mounted && authService.currentUserModel != null) {
            // Si canceló la configuración de PIN, ir al dashboard de todas formas
            context.go('/dashboard');
          }
        } else if (mounted && authService.currentUserModel != null) {
          // Si canceló la configuración de PIN, ir al dashboard de todas formas
          context.go('/dashboard');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al autenticarse: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPannarLogo() {
    // Logo completo con símbolo y texto - fondo azul, cuadrados y texto blancos
    // Usando Colors.blue que es el mismo color del botón "Agendar Cita"
    const blueColor = Colors.blue; // Mismo color del botón "Agendar Cita"

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: blueColor, // Fondo azul como el botón "Agendar Cita"
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Símbolo: cuadrícula 2x2 con cuadrados blancos sobre fondo azul
          SizedBox(
            width: 48,
            height: 48,
            child: GridView.count(
              crossAxisCount: 2,
              padding: EdgeInsets.zero,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                // Superior izquierda - blanco
                Container(color: Colors.white),
                // Superior derecha - transparente (fondo azul)
                Container(color: Colors.transparent),
                // Inferior izquierda - transparente (fondo azul)
                Container(color: Colors.transparent),
                // Inferior derecha - blanco
                Container(color: Colors.white),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Texto "PANNAR Digital" en blanco
          const Text(
            'PANNAR Digital',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo completo
                  Center(
                    child: _buildPannarLogo(),
                  ),
                  const SizedBox(height: 32),
                  // Subtítulo
                  const Text(
                    'Inicia sesión para continuar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 32),

                  if (_isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    // Botón de Google - siempre visible si no hay sesión offline sin PIN
                    if (!(_isOfflineMode && _hasLocalSession && !_hasPin))
                      _buildGoogleButton(),

                    // Separador y sección PIN - solo si hay PIN configurado
                    if (_hasPin) ...[
                      const SizedBox(height: 24),
                      _buildSeparator(),
                      const SizedBox(height: 24),
                      _buildPinSection(),
                    ] else if (_isOfflineMode &&
                        _hasLocalSession &&
                        !_hasPin) ...[
                      // Modo offline con sesión pero sin PIN
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => _signInOffline(),
                        icon: const Icon(Icons.login),
                        label: const Text('Acceder sin conexión'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Primera autenticación requiere conexión',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return OutlinedButton(
      onPressed: _signInWithGoogle,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        side: BorderSide(color: Colors.grey.shade300),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo de Google - usando SVG embebido
          SizedBox(
            width: 20,
            height: 20,
            child: CustomPaint(
              painter: _GoogleLogoPainter(),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'Continuar con Google',
            style: TextStyle(fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.grey.shade300)),
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.grey.shade300,
          ),
        ),
        Expanded(child: Divider(color: Colors.grey.shade300)),
      ],
    );
  }

  Widget _buildPinSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ingresa tu PIN',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _buildPinInput(),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () => _handlePinLogin(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue, // Mismo azul del botón "Agendar Cita"
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Iniciar Sesión',
            style: TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => _resetPinWithGoogleAuth(),
          child: const Text(
            '¿Olvidaste tu PIN?',
            style: TextStyle(
              color: Color(0xFF1E3A5F),
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPinInput() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(6, (index) {
        return SizedBox(
          width: 48,
          height: 48,
          child: TextField(
            controller: _pinControllers[index],
            focusNode: _pinFocusNodes[index],
            textAlign: TextAlign.center,
            obscureText: true,
            maxLength: 1,
            keyboardType: TextInputType.number,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            decoration: InputDecoration(
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                  color: Color(0xFF1E3A5F),
                  width: 2,
                ),
              ),
            ),
            onChanged: (value) {
              // Construir el PIN completo desde todos los controladores individuales
              String fullPin = '';
              for (int i = 0; i < 6; i++) {
                final controller = _pinControllers[i];
                if (controller.text.isNotEmpty && controller.text.length == 1) {
                  fullPin += controller.text;
                }
              }

              // Actualizar el controlador principal con el PIN completo
              _pinController.text = fullPin;

              // Mover al siguiente campo si hay texto
              if (value.isNotEmpty && index < 5) {
                _pinFocusNodes[index + 1].requestFocus();
              }
              // Si se borra, mover al campo anterior
              if (value.isEmpty && index > 0) {
                _pinFocusNodes[index - 1].requestFocus();
              }

              // Si se alcanzan 6 dígitos, validar automáticamente
              if (fullPin.length == 6) {
                // Quitar el foco para ocultar el teclado
                _pinFocusNodes[index].unfocus();
                // Validar el PIN después de un pequeño delay
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (mounted) {
                    _handlePinLogin();
                  }
                });
              }
            },
          ),
        );
      }),
    );
  }

  Future<void> _handlePinLogin() async {
    final pin = _pinController.text;

    if (pin.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingresa un PIN de 6 dígitos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() => _isLoading = true);
    }

    final isValid = await _localAuth.authenticateWithPin(pin);

    if (!isValid) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Limpiar todos los controladores de PIN
          _pinController.clear();
          for (var controller in _pinControllers) {
            controller.clear();
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PIN incorrecto'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // PIN correcto, cargar el usuario
    await _signInOffline(pin: pin);
  }

  @override
  void dispose() {
    _pinController.dispose();
    for (var controller in _pinControllers) {
      controller.dispose();
    }
    for (var node in _pinFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}

class _PinInputDialog extends StatefulWidget {
  final bool showForgotPin;

  const _PinInputDialog({this.showForgotPin = false});

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _pinController = TextEditingController();
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _pinController.dispose();
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ingresa tu PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (index) {
              return SizedBox(
                width: 40,
                height: 40,
                child: TextField(
                  controller: index == 0 ? _pinController : null,
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  obscureText: true,
                  maxLength: 1,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontSize: 20),
                  decoration: InputDecoration(
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onChanged: (value) {
                    if (value.isNotEmpty && index < 5) {
                      _focusNodes[index + 1].requestFocus();
                    }
                    if (value.isEmpty && index > 0) {
                      _focusNodes[index - 1].requestFocus();
                    }
                  },
                ),
              );
            }),
          ),
          if (widget.showForgotPin) ...[
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.pop(context, {'action': 'forgot_pin'});
              },
              child: const Text(
                '¿Olvidaste tu PIN?',
                style: TextStyle(color: Color(0xFF1E3A5F)),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final pin = _pinController.text;
            if (pin.length == 6) {
              Navigator.pop(context, {'action': 'login', 'pin': pin});
            }
          },
          child: const Text('Ingresar'),
        ),
      ],
    );
  }
}

class _PinDialog extends StatefulWidget {
  final bool isSetup;

  const _PinDialog({
    required this.isSetup,
  });

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isSetup ? 'Configurar PIN' : 'Ingresa tu PIN'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _pinController,
            obscureText: _obscurePin,
            keyboardType: TextInputType.number,
            maxLength: 6,
            decoration: InputDecoration(
              labelText: widget.isSetup ? 'PIN (6 dígitos)' : 'PIN',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon:
                    Icon(_obscurePin ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePin = !_obscurePin),
              ),
            ),
          ),
          if (widget.isSetup) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPinController,
              obscureText: _obscureConfirm,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: InputDecoration(
                labelText: 'Confirmar PIN',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureConfirm
                      ? Icons.visibility
                      : Icons.visibility_off),
                  onPressed: () =>
                      setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: () {
            final pin = _pinController.text;
            if (widget.isSetup) {
              final confirmPin = _confirmPinController.text;
              if (pin.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('El PIN debe tener exactamente 6 dígitos')),
                );
                return;
              }
              if (pin != confirmPin) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Los PINs no coinciden')),
                );
                return;
              }
              if (pin.isNotEmpty) {
                Navigator.pop(context, {'action': 'save', 'pin': pin});
              }
            } else {
              if (pin.isNotEmpty) {
                Navigator.pop(context, {'action': 'login', 'pin': pin});
              }
            }
          },
          child: Text(widget.isSetup ? 'Guardar' : 'Ingresar'),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }
}
