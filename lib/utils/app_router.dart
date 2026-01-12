import 'package:go_router/go_router.dart';
import '../screens/dashboard_screen.dart';
import '../screens/login_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/appointment_form_screen.dart';
import '../screens/appointment_list_screen.dart';
import '../screens/patient_list_screen.dart';
import '../screens/patient_form_screen.dart';
import '../screens/clinical_history_screen.dart';
import '../screens/reports_screen.dart';
import '../screens/user_management_screen.dart';
import '../models/appointment_model.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/calendar',
        name: 'calendar',
        builder: (context, state) => const CalendarScreen(),
      ),
      GoRoute(
        path: '/appointments',
        name: 'appointments',
        builder: (context, state) => const AppointmentListScreen(),
      ),
      GoRoute(
        path: '/appointment/new',
        name: 'appointment-new',
        builder: (context, state) {
          final appointment = state.extra as AppointmentModel?;
          return AppointmentFormScreen(appointment: appointment);
        },
      ),
      GoRoute(
        path: '/patients',
        name: 'patients',
        builder: (context, state) => const PatientListScreen(),
      ),
      GoRoute(
        path: '/patient/new',
        name: 'patient-new',
        builder: (context, state) => const PatientFormScreen(),
      ),
      GoRoute(
        path: '/patient/:id',
        name: 'patient-detail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return PatientFormScreen(patientId: id);
        },
      ),
      GoRoute(
        path: '/clinical-history',
        name: 'clinical-history',
        builder: (context, state) => const ClinicalHistoryScreen(),
      ),
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/users',
        name: 'users',
        builder: (context, state) => const UserManagementScreen(),
      ),
    ],
  );
}
