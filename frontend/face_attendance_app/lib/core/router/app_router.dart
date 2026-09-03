import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/admin_dashboard_screen.dart';
import '../../features/registration/screens/student_registration_screen.dart';
import '../../features/registration/screens/teacher_registration_screen.dart';
import '../../features/face_registration/screens/face_registration_screen.dart';
import '../../features/attendance/screens/live_attendance_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/common/placeholder_screens.dart';
import '../../features/management/screens/classes_screen.dart';
import '../../features/management/screens/class_details_screen.dart';
import '../../features/management/screens/teachers_screen.dart';
import '../../features/management/screens/students_screen.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/dashboard' : '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/register-student',
        builder: (context, state) => const StudentRegistrationScreen(),
      ),
      GoRoute(
        path: '/register-teacher',
        builder: (context, state) => const TeacherRegistrationScreen(),
      ),
      GoRoute(
        path: '/face-registration',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map) {
            return FaceRegistrationScreen(
              targetUserId: (extra['userId'] as num?)?.toInt() ?? 0,
              studentName: (extra['studentName'] as String?) ?? 'Student',
            );
          }
          // Face enrollment must always be tied to a registered student.
          return const FaceRegistrationScreen(targetUserId: 0, studentName: 'Student');
        },
      ),
      GoRoute(
        path: '/attendance-live',
        builder: (context, state) => const LiveAttendanceScreen(),
      ),
      GoRoute(
        path: '/attendance-history',
        builder: (context, state) => const ShellDashboardScreen(title: 'Attendance History Log'),
      ),
      GoRoute(
        path: '/reports',
        builder: (context, state) => const ReportsScreen(),
      ),
      GoRoute(
        path: '/classes',
        builder: (context, state) => const ClassesScreen(),
      ),
      GoRoute(
        path: '/class-details',
        builder: (context, state) {
          final extra = state.extra as Map?;
          final classId = (extra?['classId'] as num?)?.toInt();
          final className = extra?['className']?.toString();
          if (classId == null || className == null) {
            return const ShellDashboardScreen(title: 'Class was not selected');
          }
          return ClassDetailsScreen(classId: classId, className: className);
        },
      ),
      GoRoute(
        path: '/teachers',
        builder: (context, state) => const TeachersScreen(),
      ),
      GoRoute(
        path: '/students',
        builder: (context, state) => const StudentsScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ShellDashboardScreen(title: 'Profile Settings'),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const ShellDashboardScreen(title: 'App Settings'),
      ),
    ],
  );
});
