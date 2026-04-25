import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/supabase_config.dart';
import '../services/database_service.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/talk_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
  // Timeout para cada operación de red individual. Sin esto, una conexión
  // lenta podría dejar la sync colgada indefinidamente.
  static const Duration _networkTimeout = Duration(seconds: 30);

  final _supabase = SupabaseConfig.client;
  final _db = DatabaseService();
  final _connectivity = Connectivity();

  // Sincronizar datos locales con Supabase
  Future<void> syncData() async {
    try {
      // Verificar conexión
      final connectivityResult = await _connectivity.checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('No hay conexión a internet');
      }

      // Obtener datos no sincronizados
      final unsyncedData = await _db.getUnsyncedData();

      // Sincronizar pacientes
      final unsyncedPatients = _extractTableData(unsyncedData, 'patients');
      for (var patientData in unsyncedPatients) {
        try {
          // Supabase no usa el campo 'synced'; se excluye antes de subir
          final uploadData = Map<String, dynamic>.from(patientData as Map);
          uploadData.remove('synced');
          // clinical_data: si está como string JSON, decodificar para Supabase
          if (uploadData['clinical_data'] is String) {
            try {
              uploadData['clinical_data'] =
                  jsonDecode(uploadData['clinical_data'] as String);
            } catch (e) {
              debugPrint(
                  'clinical_data inválido en paciente ${uploadData['id']}: $e');
            }
          }
          await _supabase
              .from('patients')
              .upsert(uploadData)
              .timeout(_networkTimeout);
          await _db.markAsSynced('patients', patientData['id'] as String);
        } catch (e) {
          debugPrint('Error sincronizando paciente ${patientData['id']}: $e');
        }
      }

      // Sincronizar citas
      final unsyncedAppointments =
          _extractTableData(unsyncedData, 'appointments');
      for (var appointmentData in unsyncedAppointments) {
        try {
          final uploadData = Map<String, dynamic>.from(appointmentData as Map);
          uploadData.remove('synced');
          await _supabase
              .from('appointments')
              .upsert(uploadData)
              .timeout(_networkTimeout);
          await _db.markAsSynced('appointments', appointmentData['id'] as String);
        } catch (e) {
          debugPrint('Error sincronizando cita ${appointmentData['id']}: $e');
        }
      }

      // Sincronizar pláticas
      final unsyncedTalks = _extractTableData(unsyncedData, 'talks');
      for (var talkData in unsyncedTalks) {
        try {
          final uploadData = Map<String, dynamic>.from(talkData as Map);
          uploadData.remove('synced');
          await _supabase
              .from('talks')
              .upsert(uploadData)
              .timeout(_networkTimeout);
          await _db.markAsSynced('talks', talkData['id'] as String);
        } catch (e) {
          debugPrint('Error sincronizando plática ${talkData['id']}: $e');
        }
      }

      // Propagar eliminaciones locales a Supabase
      await _syncDeletions();

      // Descargar datos actualizados de Supabase
      await _downloadFromSupabase();
    } catch (e) {
      throw Exception('Error en sincronización: $e');
    }
  }

  /// Extrae la lista de datos de una tabla específica del resultado de
  /// [DatabaseService.getUnsyncedData]. Devuelve [] si la entrada no existe,
  /// evitando que un cambio en el contrato del servicio crashee la sync.
  List _extractTableData(
      List<Map<String, dynamic>> unsyncedData, String tableName) {
    for (final entry in unsyncedData) {
      if (entry['table'] == tableName) {
        return (entry['data'] as List?) ?? const [];
      }
    }
    debugPrint(
        'Aviso: getUnsyncedData no devolvió entrada para tabla "$tableName"');
    return const [];
  }

  /// Borra en Supabase los registros eliminados localmente y luego los elimina físicamente.
  Future<void> _syncDeletions() async {
    final deletedData = await _db.getDeletedUnsyncedData();
    for (final entry in deletedData) {
      final table = entry['table'] as String;
      final records = entry['data'] as List;
      for (final record in records) {
        final id = record['id'] as String;
        try {
          await _supabase
              .from(table)
              .delete()
              .eq('id', id)
              .timeout(_networkTimeout);
          // Confirmado en Supabase: eliminación física local
          await _db.hardDelete(table, id);
        } catch (e) {
          debugPrint('Error eliminando $table/$id en Supabase: $e');
          // Se reintentará en el próximo sync (synced=0 permanece)
        }
      }
    }
  }

  // Descargar datos de Supabase a local
  Future<void> _downloadFromSupabase() async {
    try {
      // Descargar pacientes (excluyendo soft-deleted en Supabase)
      // synced:true evita que los registros descargados queden como no-sincronizados
      final patientsResponse = await _supabase
          .from('patients')
          .select()
          .filter('deleted_at', 'is', null)
          .timeout(_networkTimeout);
      for (var patientData in patientsResponse) {
        try {
          final patient = PatientModel.fromJson(patientData);
          await _db.insertPatient(patient, synced: true);
        } catch (e) {
          debugPrint(
              '⚠️ Saltando paciente con datos inválidos id=${patientData['id']}: $e');
          debugPrint('   Fila: $patientData');
        }
      }

      // Descargar citas (excluyendo soft-deleted en Supabase)
      final appointmentsResponse = await _supabase
          .from('appointments')
          .select()
          .filter('deleted_at', 'is', null)
          .timeout(_networkTimeout);
      for (var appointmentData in appointmentsResponse) {
        try {
          final appointment = AppointmentModel.fromJson(appointmentData);
          await _db.insertAppointment(appointment, synced: true);
        } catch (e) {
          debugPrint(
              '⚠️ Saltando cita con datos inválidos id=${appointmentData['id']}: $e');
          debugPrint('   Fila: $appointmentData');
        }
      }

      // Descargar pláticas
      try {
        final talksResponse = await _supabase
            .from('talks')
            .select()
            .filter('deleted_at', 'is', null)
            .timeout(_networkTimeout);
        for (var talkData in talksResponse) {
          try {
            final talk = TalkModel.fromJson(talkData);
            await _db.insertTalk(talk, synced: true);
          } catch (e) {
            debugPrint(
                '⚠️ Saltando plática con datos inválidos id=${talkData['id']}: $e');
            debugPrint('   Fila: $talkData');
          }
        }
      } catch (e) {
        // La tabla talks puede no existir aún en Supabase
        debugPrint('Aviso: no se pudieron descargar pláticas de Supabase: $e');
      }
    } catch (e) {
      throw Exception('Error descargando datos: $e');
    }
  }

  // Verificar si hay conexión
  Future<bool> hasConnection() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  // Stream de cambios de conectividad
  Stream<ConnectivityResult> get connectivityStream =>
      _connectivity.onConnectivityChanged;

  /// Envía un ping liviano a Supabase para evitar que el proyecto free-tier
  /// se pause por inactividad (Supabase pausa tras ~1 semana sin llamadas API).
  /// Solo se ejecuta una vez cada 4 días para no afectar el rendimiento.
  Future<void> keepAlive() async {
    try {
      // Verificar conexión antes de intentar el ping
      final connected = await hasConnection();
      if (!connected) return;

      // Leer la última vez que se hizo el ping
      final prefs = await SharedPreferences.getInstance();
      final lastPingMs = prefs.getInt('supabase_last_ping') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      const fourDaysMs = 4 * 24 * 60 * 60 * 1000;

      if (now - lastPingMs < fourDaysMs) return; // Aún no toca

      // Ping: SELECT mínimo a la tabla users (1 fila, solo columna id)
      await _supabase
          .from('users')
          .select('id')
          .limit(1)
          .timeout(_networkTimeout);

      // Guardar timestamp del ping exitoso
      await prefs.setInt('supabase_last_ping', now);
      debugPrint('✅ Supabase keep-alive ping enviado.');
    } catch (e) {
      // Silencioso: si falla el ping no interrumpe el flujo de la app
      debugPrint('⚠️ Supabase keep-alive falló (se reintentará): $e');
    }
  }
}
