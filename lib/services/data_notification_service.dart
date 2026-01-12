import 'package:flutter/foundation.dart';

class DataNotificationService extends ChangeNotifier {
  static final DataNotificationService _instance =
      DataNotificationService._internal();
  factory DataNotificationService() => _instance;
  DataNotificationService._internal();

  // Notificar cambios en citas
  void notifyAppointmentChanged() {
    notifyListeners();
  }

  // Notificar cambios en pacientes
  void notifyPatientChanged() {
    notifyListeners();
  }

  // Notificar cambios generales en los datos
  void notifyDataChanged() {
    notifyListeners();
  }
}
