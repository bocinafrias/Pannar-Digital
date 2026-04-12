import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  List<UserModel> _users = [];
  bool _loading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _loading = true;
      _errorMsg = null;
    });
    try {
      final users = await context.read<AuthService>().getUsers();
      // Admins primero, luego psicólogos; cada grupo en orden alfabético
      users.sort((a, b) {
        if (a.role != b.role) return a.role == UserRole.admin ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      if (!mounted) return;
      setState(() => _users = users);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMsg = 'Error al cargar usuarios: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(UserModel user, UserRole newRole) async {
    final currentUser = context.read<AuthService>().currentUserModel;

    if (user.id == currentUser?.id) {
      _showSnack('No puedes cambiar tu propio rol', error: true);
      return;
    }

    final label = newRole == UserRole.admin ? 'Administrador' : 'Psicólogo';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cambiar rol'),
        content: Text('¿Cambiar el rol de ${user.name} a $label?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1E3A5F)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await context.read<AuthService>().updateUserRole(user.id, newRole);
      _showSnack('Rol actualizado correctamente');
      await _loadUsers();
    } catch (e) {
      _showSnack('Error al actualizar rol: $e', error: true);
    }
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
    final userName = authService.currentUserModel?.name ?? 'Usuario';
    final currentUserId = authService.currentUserModel?.id;

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
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Encabezado
                          Row(
                            children: [
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Gestión de usuarios',
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E3A5F),
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Los cambios de rol se aplican en el próximo inicio de sesión del usuario.',
                                      style: TextStyle(
                                          fontSize: 13, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton.filled(
                                style: IconButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E3A5F)),
                                tooltip: 'Actualizar lista',
                                onPressed: _loading ? null : _loadUsers,
                                icon: _loading
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white),
                                      )
                                    : const Icon(Icons.refresh,
                                        color: Colors.white),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Contenido principal
                          Expanded(
                            child: _loading
                                ? const Center(
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF1E3A5F)))
                                : _errorMsg != null
                                    ? _buildError()
                                    : _users.isEmpty
                                        ? _buildEmpty()
                                        : _buildList(currentUserId),
                          ),
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

  // ── Vistas de estado ──────────────────────────────────────────────────────

  Widget _buildError() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 12),
            Text(_errorMsg!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A5F)),
              onPressed: _loadUsers,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );

  Widget _buildEmpty() => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey),
            SizedBox(height: 12),
            Text('No hay usuarios registrados',
                style: TextStyle(fontSize: 16, color: Colors.grey)),
          ],
        ),
      );

  // ── Lista de usuarios ─────────────────────────────────────────────────────

  Widget _buildList(String? currentUserId) {
    final admins = _users.where((u) => u.role == UserRole.admin).toList();
    final psy = _users.where((u) => u.role == UserRole.psychologist).toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (admins.isNotEmpty) ...[
            _sectionLabel('Administradores', admins.length),
            const SizedBox(height: 8),
            _card(admins, currentUserId),
            const SizedBox(height: 20),
          ],
          if (psy.isNotEmpty) ...[
            _sectionLabel('Psicólogos', psy.length),
            const SizedBox(height: 8),
            _card(psy, currentUserId),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(String label, int count) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 4),
        child: Row(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: Colors.grey[500],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E3A5F).withOpacity(.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A5F),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _card(List<UserModel> users, String? currentUserId) => Container(
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
            for (int i = 0; i < users.length; i++) ...[
              _userTile(users[i], currentUserId),
              if (i < users.length - 1)
                const Divider(height: 1, indent: 72, endIndent: 16),
            ],
          ],
        ),
      );

  Widget _userTile(UserModel user, String? currentUserId) {
    final isMe = user.id == currentUserId;
    final isAdmin = user.role == UserRole.admin;

    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor:
            isAdmin ? const Color(0xFF1E3A5F) : const Color(0xFF4A90A4),
        child: Text(
          user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              user.name,
              style: const TextStyle(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 8),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('Tú',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.green)),
            ),
          ],
        ],
      ),
      subtitle: Text(user.email,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: isMe
          ? _roleBadge(user.role) // No puede cambiar su propio rol
          : PopupMenuButton<UserRole>(
              tooltip: 'Cambiar rol',
              offset: const Offset(0, 40),
              onSelected: (r) {
                if (r != user.role) _changeRole(user, r);
              },
              itemBuilder: (_) => [
                _roleItem(UserRole.admin, 'Administrador',
                    Icons.admin_panel_settings_outlined,
                    user.role == UserRole.admin),
                _roleItem(UserRole.psychologist, 'Psicólogo',
                    Icons.psychology_outlined,
                    user.role == UserRole.psychologist),
              ],
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _roleBadge(user.role),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: Colors.grey),
                ],
              ),
            ),
    );
  }

  Widget _roleBadge(UserRole role) {
    final isAdmin = role == UserRole.admin;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAdmin
            ? const Color(0xFFFFF3CD)
            : const Color(0xFFE8F0FE),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isAdmin ? 'Administrador' : 'Psicólogo',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isAdmin
              ? const Color(0xFF856404)
              : const Color(0xFF1E3A5F),
        ),
      ),
    );
  }

  PopupMenuItem<UserRole> _roleItem(
          UserRole role, String label, IconData icon, bool selected) =>
      PopupMenuItem<UserRole>(
        value: role,
        child: Row(
          children: [
            Icon(icon,
                size: 18,
                color: selected ? const Color(0xFF1E3A5F) : Colors.grey),
            const SizedBox(width: 10),
            Text(label,
                style: TextStyle(
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color:
                      selected ? const Color(0xFF1E3A5F) : Colors.black87,
                )),
            if (selected) ...[
              const Spacer(),
              const Icon(Icons.check, size: 16, color: Color(0xFF1E3A5F)),
            ],
          ],
        ),
      );
}
