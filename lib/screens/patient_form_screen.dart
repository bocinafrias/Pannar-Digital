import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../models/patient_model.dart';
import '../services/database_service.dart';
import '../widgets/sidebar.dart';
import '../widgets/top_bar.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../data/tabasco_communities.dart';

class PatientFormScreen extends StatefulWidget {
  final String? patientId;

  const PatientFormScreen({super.key, this.patientId});

  @override
  State<PatientFormScreen> createState() => _PatientFormScreenState();
}

class _PatientFormScreenState extends State<PatientFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _db = DatabaseService();

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();

  // Community autocomplete
  final _communityController = TextEditingController();

  DateTime? _dateOfBirth;
  String? _selectedGender;
  bool _isLoading = false;
  bool _isEditing = false;
  DateTime? _originalCreatedAt;

  @override
  void initState() {
    super.initState();
    _isEditing = widget.patientId != null;
    // Cargar después del primer frame para evitar bloqueos
    if (_isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _loadPatient();
        }
      });
    }
  }

  Future<void> _loadPatient() async {
    if (widget.patientId == null || !mounted) return;

    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      // Usar un pequeño delay para permitir que la UI se renderice
      await Future.delayed(const Duration(milliseconds: 50));

      if (!mounted) return;

      final patient = await _db.getPatientById(widget.patientId!);

      if (!mounted) return;

      if (patient != null) {
        _nameController.text = patient.name;
        _emailController.text = patient.email ?? '';
        _phoneController.text = patient.phone ?? '';
        _addressController.text = patient.address ?? '';
        // Comunidad: cargar el valor guardado en el controlador del autocomplete.
        _communityController.text = patient.address ?? '';
        _dateOfBirth = patient.dateOfBirth;
        _selectedGender = patient.gender;
        _originalCreatedAt = patient.createdAt;
      } else {
        // Si no se encuentra el paciente, regresar
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Paciente no encontrado'),
              backgroundColor: Colors.orange,
            ),
          );
          Future.delayed(const Duration(milliseconds: 300), () {
            if (mounted) context.pop();
          });
        }
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cargar paciente: $e'),
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

  Future<void> _selectDateOfBirth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ??
          DateTime.now().subtract(const Duration(days: 365 * 30)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      locale: const Locale('es', 'ES'),
    );
    if (picked != null) {
      setState(() => _dateOfBirth = picked);
    }
  }

  Future<void> _savePatient() async {
    if (!_formKey.currentState!.validate()) return;

    // Prevenir múltiples clics
    if (_isLoading) return;

    setState(() => _isLoading = true);
    try {
      // Validar duplicados (solo para nuevos pacientes)
      if (!_isEditing) {
        final existingPatients = await _db.getPatients();
        final duplicate = existingPatients.any((p) =>
            p.name.toLowerCase().trim() ==
                _nameController.text.toLowerCase().trim() &&
            (p.email?.toLowerCase().trim() ==
                    _emailController.text.toLowerCase().trim() ||
                (_emailController.text.isEmpty && p.email == null)));

        if (duplicate) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.white),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Ya existe un paciente con el mismo nombre y correo',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          setState(() => _isLoading = false);
          return;
        }
      }
      if (!mounted) return;
      final authService = context.read<AuthService>();
      final currentUserId = authService.currentUser?.id ?? '';

      // Si es edición, mantener el psychologistId original; si es nuevo, usar el actual
      String? psychologistId;
      if (_isEditing && widget.patientId != null) {
        final existingPatient = await _db.getPatientById(widget.patientId!);
        psychologistId = existingPatient?.psychologistId ?? currentUserId;
      } else {
        psychologistId = currentUserId; // Nuevo paciente: guardar quién lo creó
      }

      final patient = PatientModel(
        id: widget.patientId ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text,
        email: _emailController.text.isEmpty ? null : _emailController.text,
        phone: _phoneController.text.isEmpty ? null : _phoneController.text,
        address: _communityController.text.isEmpty
            ? null
            : _communityController.text,
        dateOfBirth: _dateOfBirth,
        gender: _selectedGender,
        psychologistId: psychologistId,
        createdAt: _isEditing
            ? (_originalCreatedAt ?? DateTime.now())
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertPatient(patient);

      if (!mounted) return;

      // Mostrar diálogo de éxito en el centro
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 64,
                ),
                const SizedBox(height: 16),
                Text(
                  _isEditing
                      ? 'Paciente actualizado exitosamente'
                      : 'Paciente registrado exitosamente',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              Center(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Cerrar diálogo
                    if (mounted) {
                      // context.go reemplaza el stack, no hace falta pop previo
                      context.go('/patients');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A5F),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Aceptar'),
                ),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usar watch para obtener el nombre del usuario
    final authService = Provider.of<AuthService>(context, listen: false);
    final userName = authService.currentUserModel?.name ?? 'Usuario';

    // Mostrar loading solo si estamos editando y aún cargando
    if (_isLoading && _isEditing && _nameController.text.isEmpty) {
      return const Scaffold(
        body: Row(
          children: [
            Sidebar(),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text('Cargando información del paciente...'),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          const Sidebar(),
          // Main Content
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                children: [
                  // Top Bar
                  TopBar(userName: userName),
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditing ? 'Editar Paciente' : 'Nuevo Paciente',
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A5F),
                              ),
                            ),
                            const SizedBox(height: 24),
                            TextFormField(
                              controller: _nameController,
                              decoration: const InputDecoration(
                                labelText: 'Nombre completo *',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Ingresa el nombre';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Correo electrónico',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                // Campo opcional: vacío es válido.
                                if (value == null || value.trim().isEmpty) {
                                  return null;
                                }
                                final emailRegex = RegExp(
                                    r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Correo electrónico inválido';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              decoration: const InputDecoration(
                                labelText: 'Teléfono (10 dígitos)',
                                border: OutlineInputBorder(),
                              ),
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              validator: (value) {
                                // Campo opcional: vacío es válido.
                                if (value == null || value.isEmpty) {
                                  return null;
                                }
                                if (value.length != 10) {
                                  return 'El teléfono debe tener 10 dígitos';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            ListTile(
                              title: const Text('Fecha de nacimiento'),
                              subtitle: Text(
                                _dateOfBirth != null
                                    ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}'
                                    : 'No seleccionada',
                              ),
                              trailing: const Icon(Icons.calendar_today),
                              onTap: _selectDateOfBirth,
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              initialValue: _selectedGender,
                              decoration: const InputDecoration(
                                labelText: 'Género',
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(
                                    value: 'M', child: Text('Masculino')),
                                DropdownMenuItem(
                                    value: 'F', child: Text('Femenino')),
                                DropdownMenuItem(
                                    value: 'O', child: Text('Otro')),
                              ],
                              onChanged: (value) {
                                setState(() => _selectedGender = value);
                              },
                            ),
                            const SizedBox(height: 16),
                            // ── Comunidad / Colonia ───────────────────────
                            _CommunityAutocomplete(
                              controller: _communityController,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _isLoading ? null : _savePatient,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: const Color(0xFF1E3A5F),
                                  foregroundColor: Colors.white,
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Text(
                                        _isEditing
                                            ? 'Actualizar Paciente'
                                            : 'Registrar Paciente',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),
                          ],
                        ),
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

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _communityController.dispose();
    super.dispose();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Widget de autocompletado de comunidades
// ─────────────────────────────────────────────────────────────────────────────

class _CommunityAutocomplete extends StatefulWidget {
  final TextEditingController controller;

  const _CommunityAutocomplete({
    required this.controller,
  });

  @override
  State<_CommunityAutocomplete> createState() => _CommunityAutocompleteState();
}

class _CommunityAutocompleteState extends State<_CommunityAutocomplete> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Autocomplete<CommunityEntry>(
      initialValue: TextEditingValue(text: widget.controller.text),
      displayStringForOption: (entry) => entry.displayName,
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          // Sin texto: mostrar todas las de Jalpa de Méndez primero
          return tabascoCommunitiesData
              .where((e) => e.municipality == 'Jalpa de Méndez')
              .followedBy(
                tabascoCommunitiesData
                    .where((e) => e.municipality != 'Jalpa de Méndez'),
              );
        }
        final query = textEditingValue.text.toLowerCase();
        // Primero las que coincidan de Jalpa de Méndez, luego el resto
        final jalpa = tabascoCommunitiesData
            .where((e) =>
                e.municipality == 'Jalpa de Méndez' &&
                e.displayName.toLowerCase().contains(query))
            .toList();
        final rest = tabascoCommunitiesData
            .where((e) =>
                e.municipality != 'Jalpa de Méndez' &&
                e.displayName.toLowerCase().contains(query))
            .toList();
        return [...jalpa, ...rest];
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final entry = options.elementAt(index);
                  final isJalpa = entry.municipality == 'Jalpa de Méndez';
                  return InkWell(
                    onTap: () => onSelected(entry),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      child: Row(
                        children: [
                          Icon(
                            isJalpa
                                ? Icons.location_on
                                : Icons.location_on_outlined,
                            size: 16,
                            color:
                                isJalpa ? const Color(0xFF1E3A5F) : Colors.grey,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.name,
                                  style: TextStyle(
                                    fontWeight: isJalpa
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isJalpa
                                        ? const Color(0xFF1E3A5F)
                                        : Colors.black87,
                                  ),
                                ),
                                Text(
                                  '${entry.type} · ${entry.municipality}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
      onSelected: (CommunityEntry entry) {
        widget.controller.text = entry.displayName;
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
        // Sync external controller → internal controller on first build
        if (textEditingController.text != widget.controller.text &&
            widget.controller.text.isNotEmpty) {
          textEditingController.text = widget.controller.text;
        }
        // Keep our external controller in sync when the user types
        textEditingController.addListener(() {
          widget.controller.text = textEditingController.text;
        });
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          decoration: const InputDecoration(
            labelText: 'Comunidad / Colonia',
            hintText: 'Busca o escribe la comunidad',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.location_on_outlined),
          ),
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }
}
