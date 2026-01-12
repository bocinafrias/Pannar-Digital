import '../config/supabase_config.dart';
import '../services/database_service.dart';
import '../models/patient_model.dart';
import '../models/appointment_model.dart';
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
          await _supabase.from('patients').upsert(patientData);
          await _db.markAsSynced('patients', patientData['id']);
        } catch (e) {
          print('Error sincronizando paciente ${patientData['id']}: $e');
        }
      }

      // Sincronizar citas
      final unsyncedAppointments = unsyncedData
          .firstWhere((e) => e['table'] == 'appointments')['data'] as List;
      for (var appointmentData in unsyncedAppointments) {
        try {
          await _supabase.from('appointments').upsert(appointmentData);
          await _db.markAsSynced('appointments', appointmentData['id']);
        } catch (e) {
          print('Error sincronizando cita ${appointmentData['id']}: $e');
        }
      }

      // Descargar datos actualizados de Supabase
      await _downloadFromSupabase();
    } catch (e) {
      throw Exception('Error en sincronización: $e');
    }
  }

  // Descargar datos de Supabase a local
  Future<void> _downloadFromSupabase() async {
    try {
      // Descargar pacientes
      final patientsResponse = await _supabase.from('patients').select();
      for (var patientData in patientsResponse) {
        final patient = PatientModel.fromJson(patientData);
        await _db.insertPatient(patient);
      }

      // Descargar citas
      final appointmentsResponse =
          await _supabase.from('appointments').select();
      for (var appointmentData in appointmentsResponse) {
        final appointment = AppointmentModel.fromJson(appointmentData);
        await _db.insertAppointment(appointment);
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
