import 'dart:convert';
import '../config/supabase_config.dart';
import '../services/database_service.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
import '../models/talk_model.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class SyncService {
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
      final unsyncedPatients = unsyncedData
          .firstWhere((e) => e['table'] == 'patients')['data'] as List;
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
            } catch (_) {}
          }
          await _supabase.from('patients').upsert(uploadData);
          await _db.markAsSynced('patients', patientData['id'] as String);
        } catch (e) {
          print('Error sincronizando paciente ${patientData['id']}: $e');
        }
      }

      // Sincronizar citas
      final unsyncedAppointments = unsyncedData
          .firstWhere((e) => e['table'] == 'appointments')['data'] as List;
      for (var appointmentData in unsyncedAppointments) {
        try {
          final uploadData = Map<String, dynamic>.from(appointmentData as Map);
          uploadData.remove('synced');
          await _supabase.from('appointments').upsert(uploadData);
          await _db.markAsSynced('appointments', appointmentData['id'] as String);
        } catch (e) {
          print('Error sincronizando cita ${appointmentData['id']}: $e');
        }
      }

      // Sincronizar pláticas
      final unsyncedTalks = unsyncedData
          .firstWhere((e) => e['table'] == 'talks')['data'] as List;
      for (var talkData in unsyncedTalks) {
        try {
          final uploadData = Map<String, dynamic>.from(talkData as Map);
          uploadData.remove('synced');
          await _supabase.from('talks').upsert(uploadData);
          await _db.markAsSynced('talks', talkData['id'] as String);
        } catch (e) {
          print('Error sincronizando plática ${talkData['id']}: $e');
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

  /// Borra en Supabase los registros eliminados localmente y luego los elimina físicamente.
  Future<void> _syncDeletions() async {
    final deletedData = await _db.getDeletedUnsyncedData();
    for (final entry in deletedData) {
      final table = entry['table'] as String;
      final records = entry['data'] as List;
      for (final record in records) {
        final id = record['id'] as String;
        try {
          await _supabase.from(table).delete().eq('id', id);
          // Confirmado en Supabase: eliminación física local
          await _db.hardDelete(table, id);
        } catch (e) {
          print('Error eliminando $table/$id en Supabase: $e');
          // Se reintentará en el próximo sync (synced=0 permanece)
        }
      }
    }
  }

  // Descargar datos de Supabase a local
  Future<void> _downloadFromSupabase() async {
    try {
      // Descargar pacientes
      // synced:true evita que los registros descargados queden como no-sincronizados
      final patientsResponse = await _supabase.from('patients').select();
      for (var patientData in patientsResponse) {
        final patient = PatientModel.fromJson(patientData);
        await _db.insertPatient(patient, synced: true);
      }

      // Descargar citas
      final appointmentsResponse =
          await _supabase.from('appointments').select();
      for (var appointmentData in appointmentsResponse) {
        final appointment = AppointmentModel.fromJson(appointmentData);
        await _db.insertAppointment(appointment, synced: true);
      }

      // Descargar pláticas
      try {
        final talksResponse = await _supabase.from('talks').select();
        for (var talkData in talksResponse) {
          final talk = TalkModel.fromJson(talkData);
          await _db.insertTalk(talk, synced: true);
        }
      } catch (e) {
        // La tabla talks puede no existir aún en Supabase
        print('Aviso: no se pudieron descargar pláticas de Supabase: $e');
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
}
