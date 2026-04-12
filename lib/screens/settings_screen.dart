import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../services/auth_service.dart';
import '../services/local_auth_service.dart';
import '../services/sync_service.dart';
import '../services/appointment_notification_service.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _localAuth = LocalAuthService();
  final _syncService = SyncService();

  bool _hasPin = false;
  bool _notificationsEnabled = true;
  DateTime? _lastSync;
  bool _isOnline = false;
  bool _isSyncing = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPin = await _localAuth.hasPinConfigured();
    final lastSync = await _localAuth.getLastSync();
    final isOnline = await _syncService.hasConnection();

    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _lastSync = lastSync;
      _isOnline = isOnline;
      _loading = false;
    });
  }

  // ── PIN ───────────────────────────────────────────────────────────────────

  Future<void> _showSetPinDialog() async {
    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinInputDialog(
        title: 'Configurar PIN offline',
        subtitle: 'Establece un PIN de 4 dígitos para acceder sin internet.',
        confirm: true,
      ),
    );
    if (pin == null) return;
    await _localAuth.setPin(pin);
    setState(() => _hasPin = true);
    _showSnack('PIN configurado correctamente');
  }

  Future<void> _showChangePinDialog() async {
    final currentOk = await _verifyCurrentPin();
    if (currentOk != true) return;

    final pin = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _PinInputDialog(
        title: 'Nuevo PIN',
        subtitle: 'Ingresa el nuevo PIN de 4 dígitos.',
        confirm: true,
      ),
    );
    if (pin == null) return;
    await _localAuth.setPin(pin);
    _showSnack('PIN actualizado correctamente');
  }

  Future<void> _showRemovePinDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar PIN'),
        content: const Text(
          'Sin PIN, cualquiera con acceso a esta PC podrá entrar en modo offline. ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final currentOk = await _verifyCurrentPin();
    if (currentOk != true) return;

    await _localAuth.removePin();
    setState(() => _hasPin = false);
    _showSnack('PIN eliminado');
  }

  Future<bool?> _verifyCurrentPin() => showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _PinVerifyDialog(
          title: 'Ingresa tu PIN actual',
          localAuth: _localAuth,
        ),
      );

  // ── Notificaciones ────────────────────────────────────────────────────────

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', value);
    setState(() => _notificationsEnabled = value);

    if (!value) {
      AppointmentNotificationService().stop();
    } else {
      final user = context.read<AuthService>().currentUserModel;
      if (user != null) AppointmentNotificationService().start(user);
    }
  }

  // ── Sincronización ────────────────────────────────────────────────────────

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);
    try {
      await _syncService.syncData();
      await _localAuth.updateLastSync();
      final lastSync = await _localAuth.getLastSync();
      if (!mounted) return;
      setState(() => _lastSync = lastSync);
      _showSnack('Sincronización completada');
    } catch (e) {
      _showSnack(
        'Error al sincronizar: ${e.toString().replaceFirst('Exception: ', '')}',
        error: true,
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Cerrar sesión ─────────────────────────────────────────────────────────

  Future<void> _confirmSignOut() async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text(
          '¿Deseas mantener los datos offline para el próximo inicio de sesión?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'keep'),
            child: const Text('Cerrar y mantener datos'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            onPressed: () => Navigator.pop(ctx, 'clear'),
            child: const Text('Cerrar sesión completa'),
          ),
        ],
      ),
    );

    if (result == null || !mounted) return;
    AppointmentNotificationService().stop();
    await context
        .read<AuthService>()
        .signOut(clearLocalSession: result == 'clear');
    if (mounted) context.go('/login');
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red[700] : const Color(0xFF1E3A5F),
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.currentUserModel;
    final userName = user?.name ?? 'Usuario';
    final isAdmin = user?.role == UserRole.admin;

    return Scaffold(
      body: Row(
        children: [
          const Sidebar(),
          Expanded(
            child: Container(
              color: const Color(0xFFF5F7FA),
              child: Column(
                children: [
                  TopBar(userName: userName),
                  Expanded(
                    child: _loading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1E3A5F),
                            ),
                          )
                        : SingleChildScrollView(
                            padding: const EdgeInsets.all(28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Encabezado
                                const Text(
                                  'Configuración',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E3A5F),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Personaliza tu experiencia en PANNAR Digital',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 28),

                                if (user != null) _buildAccountSection(user),
                                const SizedBox(height: 20),
                                _buildPinSection(),
                                const SizedBox(height: 20),
                                _buildNotificationsSection(),
                                const SizedBox(height: 20),
                                _buildSyncSection(),
                                if (isAdmin) ...[
                                  const SizedBox(height: 20),
                                  _buildAdminSection(),
                                ],
                                const SizedBox(height: 20),
                                _buildAboutSection(),
                                const SizedBox(height: 20),
                                _buildSessionSection(),
                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Constructores de sección ──────────────────────────────────────────────

  Widget _sectionLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.4,
            color: Colors.grey[500],
          ),
        ),
      );

  Widget _card(List<Widget> children) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, indent: 16, endIndent: 16),
            ],
          ],
        ),
      );

  // Mi cuenta
  Widget _buildAccountSection(UserModel user) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Mi cuenta'),
          _card([
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF1E3A5F),
                    child: Text(
                      user.name.isNotEmpty
                          ? user.name[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: user.role == UserRole.admin
                                ? const Color(0xFFFFF3CD)
                                : const Color(0xFFE8F0FE),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role == UserRole.admin
                                ? 'Administrador'
                                : 'Psicólogo',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: user.role == UserRole.admin
                                  ? const Color(0xFF856404)
                                  : const Color(0xFF1E3A5F),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      );

  // Acceso offline (PIN)
  Widget _buildPinSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Acceso offline'),
          _card([
            if (!_hasPin)
              ListTile(
                leading: const Icon(
                  Icons.pin_outlined,
                  color: Color(0xFF1E3A5F),
                ),
                title: const Text('Configurar PIN offline'),
                subtitle:
                    const Text('Accede sin internet usando un PIN de 4 dígitos'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showSetPinDialog,
              )
            else ...[
              ListTile(
                leading: const Icon(
                  Icons.pin_outlined,
                  color: Color(0xFF1E3A5F),
                ),
                title: const Text('Cambiar PIN'),
                subtitle: const Text('Actualiza tu PIN de acceso offline'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showChangePinDialog,
              ),
              ListTile(
                leading: const Icon(
                  Icons.no_encryption_outlined,
                  color: Colors.red,
                ),
                title: const Text(
                  'Eliminar PIN',
                  style: TextStyle(color: Colors.red),
                ),
                subtitle: const Text('Desactiva el acceso offline con PIN'),
                trailing:
                    const Icon(Icons.chevron_right, color: Colors.red),
                onTap: _showRemovePinDialog,
              ),
            ],
          ]),
        ],
      );

  // Notificaciones
  Widget _buildNotificationsSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Notificaciones'),
          _card([
            SwitchListTile(
              secondary: const Icon(
                Icons.notifications_outlined,
                color: Color(0xFF1E3A5F),
              ),
              title: const Text('Notificaciones de citas'),
              subtitle: const Text(
                'Avisos de Windows al iniciar sesión y cada hora',
              ),
              value: _notificationsEnabled,
              activeColor: const Color(0xFF1E3A5F),
              onChanged: _toggleNotifications,
            ),
          ]),
        ],
      );

  // Sincronización
  Widget _buildSyncSection() {
    final lastSyncText = _lastSync == null
        ? 'Nunca sincronizado'
        : 'Última vez: ${DateFormat("d 'de' MMMM, HH:mm", 'es').format(_lastSync!)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Sincronización'),
        _card([
          ListTile(
            leading: const Icon(
              Icons.wifi_outlined,
              color: Color(0xFF1E3A5F),
            ),
            title: const Text('Estado de conexión'),
            trailing: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isOnline
                    ? const Color(0xFFE6F4EA)
                    : const Color(0xFFFCE8E6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: _isOnline ? Colors.green[700] : Colors.red[700],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isOnline ? 'En línea' : 'Sin conexión',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color:
                          _isOnline ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ListTile(
            leading: const Icon(
              Icons.cloud_sync_outlined,
              color: Color(0xFF1E3A5F),
            ),
            title: const Text('Sincronizar datos'),
            subtitle: Text(lastSyncText),
            trailing: _isSyncing
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF1E3A5F),
                    ),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A5F),
                    ),
                    onPressed: _isOnline ? _syncNow : null,
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text('Sincronizar ahora'),
                  ),
          ),
        ]),
      ],
    );
  }

  // Administración (solo admin)
  Widget _buildAdminSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Administración'),
          _card([
            ListTile(
              leading: const Icon(
                Icons.manage_accounts_outlined,
                color: Color(0xFF1E3A5F),
              ),
              title: const Text('Gestión de usuarios'),
              subtitle: const Text(
                  'Administra psicólogos y roles del sistema'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/users'),
            ),
          ]),
        ],
      );

  // Acerca de
  Widget _buildAboutSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Acerca de'),
          _card([
            ListTile(
              leading: const Icon(
                Icons.apps_outlined,
                color: Color(0xFF1E3A5F),
              ),
              title: const Text('PANNAR Digital'),
              subtitle: const Text('Versión 1.0.0'),
            ),
            ListTile(
              leading: const Icon(
                Icons.business_outlined,
                color: Color(0xFF1E3A5F),
              ),
              title: const Text('Institución'),
              subtitle:
                  const Text('DIF Jalpa de Méndez — Área PANNAR'),
            ),
          ]),
        ],
      );

  // Sesión
  Widget _buildSessionSection() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel('Sesión'),
          _card([
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text(
                'Cerrar sesión',
                style: TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: const Text('Salir de la cuenta actual'),
              onTap: _confirmSignOut,
            ),
          ]),
        ],
      );
}

// ─────────────────────────── Diálogo: ingresar PIN ────────────────────────────

class _PinInputDialog extends StatefulWidget {
  final String title;
  final String subtitle;
  final bool confirm;

  const _PinInputDialog({
    required this.title,
    required this.subtitle,
    this.confirm = false,
  });

  @override
  State<_PinInputDialog> createState() => _PinInputDialogState();
}

class _PinInputDialogState extends State<_PinInputDialog> {
  final _pin1Controller = TextEditingController();
  final _pin2Controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pin1Controller.dispose();
    _pin2Controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final pin = _pin1Controller.text.trim();
    if (pin.length != 4) {
      setState(() => _error = 'El PIN debe tener exactamente 4 dígitos');
      return;
    }
    if (widget.confirm && pin != _pin2Controller.text.trim()) {
      setState(() => _error = 'Los PINs no coinciden');
      return;
    }
    Navigator.pop(context, pin);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _pin1Controller,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'PIN (4 dígitos)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pin2Controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                decoration: const InputDecoration(
                  labelText: 'Confirmar PIN',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() => _error = null),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            onPressed: _confirm,
            child: const Text('Guardar'),
          ),
        ],
      );
}

// ─────────────────────────── Diálogo: verificar PIN ──────────────────────────

class _PinVerifyDialog extends StatefulWidget {
  final String title;
  final LocalAuthService localAuth;

  const _PinVerifyDialog({
    required this.title,
    required this.localAuth,
  });

  @override
  State<_PinVerifyDialog> createState() => _PinVerifyDialogState();
}

class _PinVerifyDialogState extends State<_PinVerifyDialog> {
  final _controller = TextEditingController();
  String? _error;
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final ok =
        await widget.localAuth.authenticateWithPin(_controller.text.trim());
    if (!mounted) return;
    setState(() => _loading = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'PIN incorrecto');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              obscureText: true,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              decoration: const InputDecoration(
                labelText: 'PIN',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() => _error = null),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red, fontSize: 13),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A5F),
            ),
            onPressed: _loading ? null : _verify,
            child: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Verificar'),
          ),
        ],
      );
}
