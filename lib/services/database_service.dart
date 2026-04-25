import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../models/appointment_model.dart';
import '../models/patient_model.dart';
import '../models/report_model.dart';
import '../models/talk_model.dart';
import 'data_notification_service.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  final _notificationService = DataNotificationService();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    // Carpeta de soporte por usuario (escribible siempre, incluso si la app
    // está instalada en C:\Program Files). En Windows resuelve a
    // %APPDATA%\<package_name>\.
    final supportDir = await getApplicationSupportDirectory();
    if (!await supportDir.exists()) {
      await supportDir.create(recursive: true);
    }
    final String path = join(supportDir.path, 'pannar_digital.db');
    final db = await openDatabase(
      path,
      version: 6, // v6: índices en deleted_at para acelerar queries con soft-delete
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );

    // Verificar y agregar columnas faltantes (por si la migración falló)
    await _ensureColumnsExist(db);

    return db;
  }

  /// Verifica que todas las columnas necesarias existan (safety net post-migración).
  Future<void> _ensureColumnsExist(Database db) async {
    // Columnas requeridas por tabla
    final requiredColumns = {
      'patients': ['psychologist_id', 'deleted_at'],
      'appointments': ['attended', 'deleted_at'],
      'talks': ['deleted_at'],
    };

    for (final entry in requiredColumns.entries) {
      final table = entry.key;
      final columns = entry.value;
      try {
        final info = await db.rawQuery('PRAGMA table_info($table)');
        final existing = info.map((c) => c['name'] as String).toSet();
        for (final col in columns) {
          if (!existing.contains(col)) {
            await db.execute('ALTER TABLE $table ADD COLUMN $col TEXT');
            debugPrint('_ensureColumnsExist: $col añadido a $table');
          }
        }
      } catch (e) {
        debugPrint('_ensureColumnsExist error en $table: $e');
      }
    }

    // Crear tabla reports si no existe
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reports (
          id TEXT PRIMARY KEY,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          psychologist_id TEXT,
          start_date TEXT,
          end_date TEXT,
          file_path TEXT,
          created_at TEXT NOT NULL
        )
      ''');
    } catch (e) {
      debugPrint('_ensureColumnsExist: error creando tabla reports: $e');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de pacientes
    await db.execute('''
      CREATE TABLE patients (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT,
        date_of_birth TEXT,
        gender TEXT,
        address TEXT,
        clinical_data TEXT,
        total_sessions INTEGER DEFAULT 0,
        psychologist_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Tabla de citas
    await db.execute('''
      CREATE TABLE appointments (
        id TEXT PRIMARY KEY,
        patient_id TEXT NOT NULL,
        psychologist_id TEXT NOT NULL,
        date_time TEXT NOT NULL,
        reason TEXT NOT NULL,
        status TEXT NOT NULL,
        notes TEXT,
        attended INTEGER,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced INTEGER DEFAULT 0,
        FOREIGN KEY (patient_id) REFERENCES patients (id)
      )
    ''');

    // Tabla de pláticas
    await db.execute('''
      CREATE TABLE talks (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        educational_institution TEXT NOT NULL,
        topic TEXT NOT NULL,
        school_location TEXT NOT NULL,
        students_benefited INTEGER NOT NULL,
        date TEXT NOT NULL,
        psychologist_id TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        deleted_at TEXT,
        synced INTEGER DEFAULT 0
      )
    ''');

    // Tabla de reportes generados
    await db.execute('''
      CREATE TABLE reports (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        psychologist_id TEXT,
        start_date TEXT,
        end_date TEXT,
        file_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // Índices para mejorar búsquedas
    await db.execute(
        'CREATE INDEX idx_appointments_date ON appointments(date_time)');
    await db.execute(
        'CREATE INDEX idx_appointments_psychologist ON appointments(psychologist_id)');
    await db.execute('CREATE INDEX idx_patients_name ON patients(name)');
    await db.execute(
        'CREATE INDEX idx_patients_psychologist ON patients(psychologist_id)');
    await db.execute('CREATE INDEX idx_talks_date ON talks(date)');
    // Índices en deleted_at: todos los queries de lectura filtran por
    // 'deleted_at IS NULL', por lo que sin índice serían O(n).
    await db.execute(
        'CREATE INDEX idx_patients_deleted ON patients(deleted_at)');
    await db.execute(
        'CREATE INDEX idx_appointments_deleted ON appointments(deleted_at)');
    await db.execute('CREATE INDEX idx_talks_deleted ON talks(deleted_at)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Agregar columna attended si no existe
      try {
        await db.execute(
          'ALTER TABLE appointments ADD COLUMN attended INTEGER',
        );
      } catch (e) {
        // La columna ya existe, ignorar error
        debugPrint('Columna attended ya existe o error al agregarla: $e');
      }
    }
    if (oldVersion < 3) {
      // Agregar tabla de pláticas
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS talks (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            educational_institution TEXT NOT NULL,
            topic TEXT NOT NULL,
            school_location TEXT NOT NULL,
            students_benefited INTEGER NOT NULL,
            date TEXT NOT NULL,
            psychologist_id TEXT,
            created_at TEXT NOT NULL,
            updated_at TEXT,
            synced INTEGER DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_talks_date ON talks(date)');
      } catch (e) {
        debugPrint('Error al crear tabla talks: $e');
      }
    }
    if (oldVersion < 4) {
      try {
        final tableInfo = await db.rawQuery('PRAGMA table_info(patients)');
        final hasColumn =
            tableInfo.any((col) => col['name'] == 'psychologist_id');
        if (!hasColumn) {
          await db.execute(
              'ALTER TABLE patients ADD COLUMN psychologist_id TEXT');
          await db.execute(
              'CREATE INDEX IF NOT EXISTS idx_patients_psychologist ON patients(psychologist_id)');
        }
      } catch (e) {
        debugPrint('Error en migración v4 psychologist_id: $e');
      }
    }

    if (oldVersion < 5) {
      // Agregar columna deleted_at (soft-delete) a las tres tablas
      for (final table in ['patients', 'appointments', 'talks']) {
        try {
          final info = await db.rawQuery('PRAGMA table_info($table)');
          if (!info.any((col) => col['name'] == 'deleted_at')) {
            await db.execute(
                'ALTER TABLE $table ADD COLUMN deleted_at TEXT');
            debugPrint('Columna deleted_at agregada a $table');
          }
        } catch (e) {
          debugPrint('Error agregando deleted_at a $table: $e');
        }
      }
      // Crear tabla de reportes si no existe
      try {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS reports (
            id TEXT PRIMARY KEY,
            type TEXT NOT NULL,
            title TEXT NOT NULL,
            psychologist_id TEXT,
            start_date TEXT,
            end_date TEXT,
            file_path TEXT,
            created_at TEXT NOT NULL
          )
        ''');
        debugPrint('Tabla reports creada en migración v5');
      } catch (e) {
        debugPrint('Error creando tabla reports: $e');
      }
    }

    if (oldVersion < 6) {
      // Crear índices en deleted_at para acelerar los queries que filtran
      // por 'deleted_at IS NULL' (todos los de lectura).
      const indexStatements = [
        'CREATE INDEX IF NOT EXISTS idx_patients_deleted ON patients(deleted_at)',
        'CREATE INDEX IF NOT EXISTS idx_appointments_deleted ON appointments(deleted_at)',
        'CREATE INDEX IF NOT EXISTS idx_talks_deleted ON talks(deleted_at)',
      ];
      for (final stmt in indexStatements) {
        try {
          await db.execute(stmt);
        } catch (e) {
          debugPrint('Error creando índice deleted_at: $e');
        }
      }
    }
  }

  // Métodos para pacientes
  /// [synced]: pasar true cuando el registro ya viene de Supabase (descarga).
  Future<void> insertPatient(PatientModel patient, {bool synced = false}) async {
    final db = await database;
    final data = patient.toJson();
    // clinical_data debe guardarse como JSON string en SQLite
    if (data['clinical_data'] is Map) {
      data['clinical_data'] = jsonEncode(data['clinical_data']);
    }
    data['synced'] = synced ? 1 : 0;
    await db.insert(
      'patients',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notificationService.notifyPatientChanged();
  }

  Future<List<PatientModel>> getPatients({
    String? searchQuery,
    String? psychologistId,
    String? psychologistName, // Nombre del psicólogo para búsqueda en citas
  }) async {
    final db = await database;
    List<Map<String, dynamic>> maps;

    // Si se proporciona un psychologistId, filtrar pacientes por ese psicólogo
    // Buscar pacientes creados por ese psicólogo O que tengan citas con ese psicólogo
    if (psychologistId != null && psychologistId.isNotEmpty) {
      String where = 'psychologist_id = ?';
      List<dynamic> whereArgs = [psychologistId];

      // También incluir pacientes que tienen citas con este psicólogo
      // Buscar por ID (si las citas usan ID) o por nombre (si las citas usan nombre)
      String appointmentWhere = '';
      List<dynamic> appointmentWhereArgs = [];

      if (psychologistName != null && psychologistName.isNotEmpty) {
        // Buscar citas por nombre usando LIKE
        appointmentWhere = 'psychologist_id LIKE ?';
        appointmentWhereArgs = ['%$psychologistName%'];
      } else {
        // También buscar por ID por compatibilidad
        appointmentWhere = 'psychologist_id = ? OR psychologist_id LIKE ?';
        appointmentWhereArgs = [psychologistId, '%$psychologistId%'];
      }

      final appointmentMaps = await db.query(
        'appointments',
        columns: ['patient_id'],
        where: appointmentWhere,
        whereArgs: appointmentWhereArgs,
        distinct: true,
      );
      final patientIdsFromAppointments = appointmentMaps
          .map((map) => map['patient_id'] as String)
          .toSet()
          .toList();

      if (patientIdsFromAppointments.isNotEmpty) {
        // Combinar: pacientes creados por este psicólogo O pacientes con citas
        final placeholders =
            patientIdsFromAppointments.map((_) => '?').join(',');
        where = '(psychologist_id = ? OR id IN ($placeholders))';
        whereArgs = [psychologistId, ...patientIdsFromAppointments];
      }

      if (searchQuery != null && searchQuery.isNotEmpty) {
        where += ' AND name LIKE ?';
        whereArgs.add('%$searchQuery%');
      }

      where += ' AND deleted_at IS NULL';
      maps = await db.query(
        'patients',
        where: where,
        whereArgs: whereArgs,
        orderBy: 'name ASC',
      );
    } else {
      // Si no se proporciona psychologistId (admin), devolver todos los pacientes
      if (searchQuery != null && searchQuery.isNotEmpty) {
        maps = await db.query(
          'patients',
          where: 'name LIKE ? AND deleted_at IS NULL',
          whereArgs: ['%$searchQuery%'],
          orderBy: 'name ASC',
        );
      } else {
        maps = await db.query(
          'patients',
          where: 'deleted_at IS NULL',
          orderBy: 'name ASC',
        );
      }
    }

    return List.generate(maps.length, (i) => PatientModel.fromJson(maps[i]));
  }

  Future<PatientModel?> getPatientById(String id) async {
    final db = await database;
    final maps = await db.query(
      'patients',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return PatientModel.fromJson(maps.first);
  }

  Future<void> deletePatient(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.transaction((txn) async {
      // Soft-delete las citas asociadas
      await txn.update(
        'appointments',
        {'deleted_at': now, 'synced': 0, 'updated_at': now},
        where: 'patient_id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
      // Soft-delete el paciente
      await txn.update(
        'patients',
        {'deleted_at': now, 'synced': 0, 'updated_at': now},
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [id],
      );
    });
    _notificationService.notifyPatientChanged();
  }

  // Métodos para citas
  /// [synced]: pasar true cuando el registro ya viene de Supabase (descarga).
  Future<void> insertAppointment(AppointmentModel appointment,
      {bool synced = false}) async {
    final db = await database;
    final data = appointment.toJson();
    data['synced'] = synced ? 1 : 0;
    await db.insert(
      'appointments',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notificationService.notifyAppointmentChanged();
  }

  // Actualizar asistencia de una cita
  // Si asistió, cambia el estado a "completed"
  // Si no asistió, cambia el estado a "cancelled"
  Future<void> updateAppointmentAttendance(
    String appointmentId,
    bool attended,
  ) async {
    final db = await database;
    final newStatus = attended ? 'completed' : 'cancelled';
    await db.update(
      'appointments',
      {
        'attended': attended ? 1 : 0,
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
        'synced': 0, // Marcar como no sincronizado para que se suba en el próximo sync
      },
      where: 'id = ?',
      whereArgs: [appointmentId],
    );
    _notificationService.notifyAppointmentChanged();
  }

  // Obtener una cita por ID
  Future<AppointmentModel?> getAppointmentById(String id) async {
    final db = await database;
    final maps = await db.query(
      'appointments',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return AppointmentModel.fromJson(maps.first);
  }

  // Eliminar una cita (soft-delete)
  Future<void> deleteAppointment(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'appointments',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    _notificationService.notifyAppointmentChanged();
  }

  Future<List<AppointmentModel>> getAppointments({
    String? psychologistId,
    String? psychologistName, // Nombre del psicólogo para búsqueda por LIKE
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final db = await database;
    String where = 'deleted_at IS NULL';
    List<dynamic> whereArgs = [];

    if (psychologistId != null || psychologistName != null) {
      // Buscar por ID exacto O por nombre (para compatibilidad con citas antiguas)
      // Esto permite encontrar citas guardadas con ID o con nombre
      List<String> conditions = [];
      List<dynamic> conditionArgs = [];

      if (psychologistId != null && psychologistId.isNotEmpty) {
        // Buscar por ID exacto
        conditions.add('psychologist_id = ?');
        conditionArgs.add(psychologistId);
      }

      if (psychologistName != null && psychologistName.isNotEmpty) {
        // Buscar por nombre (LIKE para búsqueda flexible)
        conditions.add('psychologist_id LIKE ?');
        conditionArgs.add('%$psychologistName%');
        // También buscar coincidencia exacta del nombre
        conditions.add('psychologist_id = ?');
        conditionArgs.add(psychologistName);
      }

      if (conditions.isNotEmpty) {
        where += ' AND (${conditions.join(' OR ')})';
        whereArgs.addAll(conditionArgs);
      }
    }

    if (startDate != null) {
      where += ' AND date_time >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += ' AND date_time <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    final maps = await db.query(
      'appointments',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date_time ASC',
    );

    return List.generate(
        maps.length, (i) => AppointmentModel.fromJson(maps[i]));
  }

  Future<List<PatientModel>> getPatientsByIds(Set<String> ids) async {
    if (ids.isEmpty) return [];
    final db = await database;
    final idList = ids.toList();
    const chunkSize = 900; // Mantener por debajo del límite de SQLite
    final patients = <PatientModel>[];

    for (var i = 0; i < idList.length; i += chunkSize) {
      final end = (i + chunkSize) > idList.length ? idList.length : i + chunkSize;
      final chunk = idList.sublist(i, end);
      final placeholders = List.filled(chunk.length, '?').join(',');
      final maps = await db.query(
        'patients',
        where: 'id IN ($placeholders) AND deleted_at IS NULL',
        whereArgs: chunk,
      );
      patients.addAll(maps.map((m) => PatientModel.fromJson(m)));
    }

    return patients;
  }

  // Obtener datos no sincronizados
  Future<List<Map<String, dynamic>>> getUnsyncedData() async {
    final db = await database;
    final patients = await db.query('patients',
        where: 'synced = 0 AND deleted_at IS NULL');
    final appointments = await db.query('appointments',
        where: 'synced = 0 AND deleted_at IS NULL');
    final talks =
        await db.query('talks', where: 'synced = 0 AND deleted_at IS NULL');

    return [
      {'table': 'patients', 'data': patients},
      {'table': 'appointments', 'data': appointments},
      {'table': 'talks', 'data': talks},
    ];
  }

  // Marcar datos como sincronizados
  Future<void> markAsSynced(String table, String id) async {
    final db = await database;
    await db.update(
      table,
      {'synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Estadísticas
  Future<Map<String, int>> getGenderStatistics({String? psychologistId}) async {
    final patients = await getPatients(psychologistId: psychologistId);

    int maleCount = 0;
    int femaleCount = 0;
    int otherCount = 0;

    for (var patient in patients) {
      final gender = patient.gender;
      if (gender == null) continue;

      final genderLower = gender.toLowerCase();
      if (genderLower.contains('masc') ||
          genderLower == 'm' ||
          genderLower == 'male') {
        maleCount++;
      } else if (genderLower.contains('fem') ||
          genderLower == 'f' ||
          genderLower == 'female') {
        femaleCount++;
      } else {
        otherCount++;
      }
    }

    return {
      'male': maleCount,
      'female': femaleCount,
      'other': otherCount,
      'total': patients.length,
    };
  }

  Future<int> getReportsCount() async {
    final db = await database;
    try {
      final result = await db.rawQuery('SELECT COUNT(*) as count FROM reports');
      return Sqflite.firstIntValue(result) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Registra un reporte generado en la tabla local.
  Future<void> insertReport(ReportModel report) async {
    final db = await database;
    await db.insert(
      'reports',
      {
        'id': report.id,
        'type': report.type.toString().split('.').last,
        'title': report.title,
        'psychologist_id': report.psychologistId,
        'start_date': report.startDate?.toIso8601String(),
        'end_date': report.endDate?.toIso8601String(),
        'file_path': report.filePath,
        'created_at': report.createdAt.toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Retorna registros eliminados localmente que aún no se borraron en Supabase.
  Future<List<Map<String, dynamic>>> getDeletedUnsyncedData() async {
    final db = await database;
    final patients = await db.query(
      'patients',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND synced = 0',
    );
    final appointments = await db.query(
      'appointments',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND synced = 0',
    );
    final talks = await db.query(
      'talks',
      columns: ['id'],
      where: 'deleted_at IS NOT NULL AND synced = 0',
    );
    return [
      {'table': 'patients', 'data': patients},
      {'table': 'appointments', 'data': appointments},
      {'table': 'talks', 'data': talks},
    ];
  }

  /// Elimina físicamente un registro (solo llamar después de confirmar el borrado en Supabase).
  Future<void> hardDelete(String table, String id) async {
    final db = await database;
    await db.delete(table, where: 'id = ?', whereArgs: [id]);
  }

  Future<Map<String, int>> getAppointmentStatusCounts({
    String? psychologistId,
    String? psychologistName,
  }) async {
    List<Map<String, dynamic>> appointments;
    if (psychologistId != null || psychologistName != null) {
      // Filtrar citas por psicólogo usando el método existente
      final appointmentModels = await getAppointments(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
      );
      appointments = appointmentModels.map((a) => a.toJson()).toList();
    } else {
      final db = await database;
      appointments = await db.query(
        'appointments',
        where: 'deleted_at IS NULL',
      );
    }

    int completed = 0;
    int pending = 0;
    int cancelled = 0;

    for (var appointment in appointments) {
      final status = (appointment['status'] as String? ?? '').toLowerCase();
      // Contar según el estado exacto guardado en la BD
      if (status == 'completed') {
        completed++;
      } else if (status == 'cancelled') {
        cancelled++;
      } else {
        // scheduled, rescheduled o cualquier otro estado se cuenta como pending
        pending++;
      }
    }

    return {
      'completed': completed,
      'pending': pending,
      'cancelled': cancelled,
    };
  }

  // Contar notificaciones (citas programadas para hoy)
  Future<int> getTodayAppointmentsCount({String? psychologistId}) async {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(const Duration(days: 1));

    final appointments = await getAppointments(
      psychologistId: psychologistId,
      startDate: todayStart,
      endDate: todayEnd,
    );

    // Solo contar citas programadas (no completadas ni canceladas)
    return appointments.where((apt) {
      final status = apt.status.toString().split('.').last.toLowerCase();
      return status == 'scheduled';
    }).length;
  }

  // Obtener actividad reciente (últimos pacientes, citas, etc.)
  Future<List<Map<String, dynamic>>> getRecentActivity({
    int limit = 5,
    String? psychologistId,
    String? psychologistName,
  }) async {
    final activities = <Map<String, dynamic>>[];
    final db = await database;

    // Pacientes recientes
    List<Map<String, dynamic>> recentPatients;
    if (psychologistId != null && psychologistId.isNotEmpty) {
      // Filtrar pacientes por psicólogo
      final patients = await getPatients(psychologistId: psychologistId);
      recentPatients = patients
          .map((p) => {
                'id': p.id,
                'name': p.name,
                'created_at': p.createdAt.toIso8601String(),
              })
          .toList()
        ..sort((a, b) =>
            (b['created_at'] as String).compareTo(a['created_at'] as String));
      recentPatients = recentPatients.take(limit).toList();
    } else {
      recentPatients = await db.query(
        'patients',
        where: 'deleted_at IS NULL',
        orderBy: 'created_at DESC',
        limit: limit,
      );
    }

    for (var patient in recentPatients) {
      activities.add({
        'type': 'patient',
        'iconName': 'person_add',
        'iconColorName': 'green',
        'title': 'Nuevo paciente registrado',
        'subtitle':
            '${patient['name']} - ${_formatTimeAgo(DateTime.parse(patient['created_at'] as String))}',
        'timestamp': DateTime.parse(patient['created_at'] as String),
      });
    }

    // Citas recientes (completadas o canceladas)
    List<Map<String, dynamic>> recentAppointments;
    if (psychologistId != null || psychologistName != null) {
      // Filtrar citas por psicólogo usando el método existente
      final appointmentModels = await getAppointments(
        psychologistId: psychologistId,
        psychologistName: psychologistName,
      );
      recentAppointments = appointmentModels
          .where((a) =>
              a.status == AppointmentStatus.completed ||
              a.status == AppointmentStatus.cancelled)
          .map((a) => {
                'patient_id': a.patientId,
                'status': a.status.toString().split('.').last,
                'created_at': a.createdAt.toIso8601String(),
                'updated_at': a.updatedAt?.toIso8601String() ??
                    a.createdAt.toIso8601String(),
              })
          .toList()
        ..sort((a, b) =>
            (b['updated_at'] as String).compareTo(a['updated_at'] as String));
      recentAppointments = recentAppointments.take(limit).toList();
    } else {
      recentAppointments = await db.query(
        'appointments',
        where: 'status IN (?, ?) AND deleted_at IS NULL',
        whereArgs: ['completed', 'cancelled'],
        orderBy: 'updated_at DESC, created_at DESC',
        limit: limit,
      );
    }

    for (var apt in recentAppointments) {
      final patient = await getPatientById(apt['patient_id'] as String);
      final status = apt['status'] as String;
      final timestamp = apt['updated_at'] != null
          ? DateTime.parse(apt['updated_at'] as String)
          : DateTime.parse(apt['created_at'] as String);

      activities.add({
        'type': 'appointment',
        'iconName': status == 'completed' ? 'check_circle' : 'cancel',
        'iconColorName': status == 'completed' ? 'blue' : 'red',
        'title': status == 'completed' ? 'Cita completada' : 'Cita cancelada',
        'subtitle':
            '${patient?.name ?? 'Paciente'} - ${_formatTimeAgo(timestamp)}',
        'timestamp': timestamp,
      });
    }

    // Ordenar por timestamp y limitar
    activities.sort((a, b) =>
        (b['timestamp'] as DateTime).compareTo(a['timestamp'] as DateTime));
    return activities.take(limit).toList();
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 7) {
      return 'Hace ${difference.inDays ~/ 7} ${difference.inDays ~/ 7 == 1 ? 'semana' : 'semanas'}';
    } else if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} ${difference.inDays == 1 ? 'día' : 'días'}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} ${difference.inHours == 1 ? 'hora' : 'horas'}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} ${difference.inMinutes == 1 ? 'minuto' : 'minutos'}';
    } else {
      return 'Hace unos momentos';
    }
  }

  // Obtener citas por día de la semana (última semana)
  Future<Map<int, int>> getAppointmentsByWeekday({
    String? psychologistId,
    String? psychologistName,
  }) async {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    final weekEnd = weekStart.add(const Duration(days: 7));

    final appointments = await getAppointments(
      psychologistId: psychologistId,
      psychologistName: psychologistName,
      startDate: weekStart,
      endDate: weekEnd,
    );

    final Map<int, int> weekdayCounts = {
      0: 0, // Lunes
      1: 0, // Martes
      2: 0, // Miércoles
      3: 0, // Jueves
      4: 0, // Viernes
      5: 0, // Sábado
      6: 0, // Domingo
    };

    for (var apt in appointments) {
      final weekday = apt.dateTime.weekday - 1; // Convertir a índice 0-6
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    return weekdayCounts;
  }

  // Métodos para pláticas
  /// [synced]: pasar true cuando el registro ya viene de Supabase (descarga).
  Future<void> insertTalk(TalkModel talk, {bool synced = false}) async {
    final db = await database;
    final data = talk.toJson();
    data['synced'] = synced ? 1 : 0;
    await db.insert(
      'talks',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notificationService.notifyPatientChanged();
  }

  Future<List<TalkModel>> getTalks({
    DateTime? startDate,
    DateTime? endDate,
    String? psychologistId,
  }) async {
    final db = await database;
    String where = 'deleted_at IS NULL';
    List<dynamic> whereArgs = [];

    if (startDate != null) {
      where += ' AND date >= ?';
      whereArgs.add(startDate.toIso8601String());
    }

    if (endDate != null) {
      where += ' AND date <= ?';
      whereArgs.add(endDate.toIso8601String());
    }

    if (psychologistId != null) {
      where += ' AND psychologist_id = ?';
      whereArgs.add(psychologistId);
    }

    final maps = await db.query(
      'talks',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'date DESC',
    );

    return List.generate(maps.length, (i) => TalkModel.fromJson(maps[i]));
  }

  Future<TalkModel?> getTalkById(String id) async {
    final db = await database;
    final maps = await db.query(
      'talks',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return TalkModel.fromJson(maps.first);
  }

  // Eliminar una plática (soft-delete)
  Future<void> deleteTalk(String id) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    await db.update(
      'talks',
      {'deleted_at': now, 'synced': 0, 'updated_at': now},
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
    );
    _notificationService.notifyPatientChanged();
  }

  // Métodos para reportes mensuales
  Future<Map<String, dynamic>> getMonthlyReportData({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    // Obtener citas atendidas en el período
    final appointments = await getAppointments(
      startDate: startDate,
      endDate: endDate,
    );

    // Filtrar solo citas que fueron atendidas (puede ser por attended=true O status=completed)
    final attendedAppointments = appointments
        .where((apt) =>
            (apt.attended == true) ||
            (apt.status == AppointmentStatus.completed))
        .toList();

    // Obtener pacientes únicos de las citas
    final patientIds = attendedAppointments.map((apt) => apt.patientId).toSet();
    final patients = await getPatientsByIds(patientIds);

    // Estadísticas de género
    int maleCount = 0;
    int femaleCount = 0;
    for (final patient in patients) {
      if (patient.gender != null) {
        final genderLower = patient.gender!.toLowerCase();
        if (genderLower.contains('masc') ||
            genderLower == 'm' ||
            genderLower == 'male') {
          maleCount++;
        } else if (genderLower.contains('fem') ||
            genderLower == 'f' ||
            genderLower == 'female') {
          femaleCount++;
        }
      }
    }

    // Estadísticas por comunidad
    final communityCounts = <String, int>{};
    for (final patient in patients) {
      if (patient.address != null && patient.address!.isNotEmpty) {
        // Extraer comunidad de la dirección
        // Por ahora, usamos la dirección completa como comunidad
        // En el futuro se puede mejorar para extraer solo el nombre de la comunidad
        final community = _extractCommunity(patient.address!);
        communityCounts[community] = (communityCounts[community] ?? 0) + 1;
      }
    }

    // Obtener pláticas en el período
    final talks = await getTalks(startDate: startDate, endDate: endDate);

    // Obtener citas por día de la semana en el período
    final weekdayCounts = <int, int>{
      0: 0, // Lunes
      1: 0, // Martes
      2: 0, // Miércoles
      3: 0, // Jueves
      4: 0, // Viernes
      5: 0, // Sábado
      6: 0, // Domingo
    };
    for (var apt in attendedAppointments) {
      final weekday = apt.dateTime.weekday - 1; // Convertir a índice 0-6
      weekdayCounts[weekday] = (weekdayCounts[weekday] ?? 0) + 1;
    }

    return {
      'totalAppointments': attendedAppointments.length,
      'maleCount': maleCount,
      'femaleCount': femaleCount,
      'communityCounts': communityCounts,
      'uniqueCommunities': communityCounts.keys.length,
      'talks': talks.map((talk) => talk.toJson()).toList(),
      'patients': patients.map((p) => p.toJson()).toList(),
      'weekdayCounts': weekdayCounts,
    };
  }

  String _extractCommunity(String address) {
    // Intentar extraer el nombre de la comunidad de la dirección
    // Por ahora, devolvemos la dirección completa
    // Se puede mejorar con lógica específica según el formato de direcciones
    final parts = address.split(',').map((p) => p.trim()).toList();
    if (parts.isNotEmpty) {
      // Si hay múltiples partes, intentar usar la primera como comunidad
      return parts[0];
    }
    return address;
  }
}
