import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final dashboardDateFilterProvider = StateProvider<String>((ref) => 'Today');

final dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    ref.watch(managementRefreshProvider);
    final apiClient = await ApiClient.fromPrefs();
    final filter = ref.watch(dashboardDateFilterProvider);
    final dates = dashboardDateRange(filter);
    final response = await apiClient.dio.get('reports/dashboard/', queryParameters: {
      if (dates.length == 1) 'date': dates.first,
      if (dates.length == 2) 'start_date': dates.first,
      if (dates.length == 2) 'end_date': dates.last,
    }, options: Options(extra: {'skipCache': true}));
    return response.data['data'] ?? {};
  } catch (e) {
    return {
      'total_students': 0,
      'total_teachers': 0,
      'total_classes': 0,
      'today_attendance': 0,
      'today_present': 0,
      'today_absent': 0,
      'face_registered': 0,
      'face_pending': 0,
      'attendance_rate': 0.0,
      'class_attendance': <dynamic>[],
    };
  }
});

/// A shared invalidation signal for management mutations.  Screens keep their
/// local lists, while the dashboard statistics are refreshed immediately.
final managementRefreshProvider = StateProvider<int>((ref) => 0);

// Auto-refresh controller for dashboard
class DashboardAutoRefresh extends StateNotifier<void> {
  DashboardAutoRefresh(this.ref) : super(null) {
    _startAutoRefresh();
  }

  Timer? _timer;
  final Ref ref;

  void _startAutoRefresh() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.invalidate(dashboardSummaryProvider);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final dashboardAutoRefreshProvider = StateNotifierProvider<DashboardAutoRefresh, void>((ref) {
  return DashboardAutoRefresh(ref);
});

List<String> dashboardDateRange(String filter) {
  final today = DateTime.now();
  String dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  if (filter.startsWith('custom:')) return [filter.substring(7)];
  if (filter == 'Yesterday') return [dateOnly(today.subtract(const Duration(days: 1)))];
  if (filter == 'Last 7 Days') return [dateOnly(today.subtract(const Duration(days: 6))), dateOnly(today)];
  if (filter == 'Last 30 Days') return [dateOnly(today.subtract(const Duration(days: 29))), dateOnly(today)];
  return [dateOnly(today)];
}

String _attendanceLabel(String filter) => filter.startsWith('custom:') ? filter.substring(7) : filter;

class _DashboardDateSelector extends StatelessWidget {
  const _DashboardDateSelector({required this.selected, required this.onChanged});
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final value = selected.startsWith('custom:') ? 'Custom date' : selected;
    return Row(
      children: [
        const Text('Attendance date:'),
        const SizedBox(width: 12),
        DropdownButton<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'Today', child: Text('Today')),
            DropdownMenuItem(value: 'Yesterday', child: Text('Yesterday')),
            DropdownMenuItem(value: 'Last 7 Days', child: Text('Last 7 Days')),
            DropdownMenuItem(value: 'Last 30 Days', child: Text('Last 30 Days')),
            DropdownMenuItem(value: 'Custom date', child: Text('Custom date')),
          ],
          onChanged: (choice) async {
            if (choice != 'Custom date') {
              if (choice != null) onChanged(choice);
              return;
            }
            final date = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              onChanged('custom:${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}');
            }
          },
        ),
      ],
    );
  }
}

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final dashboardAsync = ref.watch(dashboardSummaryProvider);
    
    // Enable auto-refresh when dashboard is shown
    ref.watch(dashboardAutoRefreshProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('School ERP Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode),
            tooltip: 'Toggle Dark Mode',
            onPressed: () {
              ref.read(themeModeProvider.notifier).state =
                  isDark ? ThemeMode.light : ThemeMode.dark;
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Metrics',
            onPressed: () => ref.invalidate(dashboardSummaryProvider),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authProvider.notifier).logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Header Card
            Card(
              elevation: 4,
              color: theme.colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: theme.colorScheme.primary,
                      child: const Icon(Icons.admin_panel_settings, color: Colors.white, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back, ${userState.fullName ?? "Administrator"}!',
                            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text('Role: ${_displayRole(userState.role)} | AI Face Attendance ERP System'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stat Cards Grid


            _DashboardDateSelector(
              selected: ref.watch(dashboardDateFilterProvider),
              onChanged: (value) => ref.read(dashboardDateFilterProvider.notifier).state = value,
            ),
            const SizedBox(height: 16),
            Text('Live System Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            dashboardAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, stack) => const Text('Failed to load live metrics from database.'),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GridView.count(
                    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _StatCard(title: 'Total Students', value: '${data['total_students'] ?? 0}', icon: Icons.groups, color: Colors.blue),
                      _StatCard(title: 'Total Teachers', value: '${data['total_teachers'] ?? 0}', icon: Icons.school, color: Colors.purple),
                      _StatCard(title: 'Total Classes', value: '${data['total_classes'] ?? 0}', icon: Icons.class_, color: Colors.orange),
                      _StatCard(title: '${_attendanceLabel(ref.watch(dashboardDateFilterProvider))} Attendance', value: '${data['today_attendance'] ?? 0}', icon: Icons.event_available, color: Colors.green),
                      _StatCard(title: 'Present ${_attendanceLabel(ref.watch(dashboardDateFilterProvider))}', value: '${data['today_present'] ?? 0}', icon: Icons.how_to_reg, color: Colors.lightGreen),
                      _StatCard(title: 'Absent ${_attendanceLabel(ref.watch(dashboardDateFilterProvider))}', value: '${data['today_absent'] ?? 0}', icon: Icons.person_off, color: Colors.redAccent),
                      _StatCard(title: 'Face Registered', value: '${data['face_registered'] ?? 0}', icon: Icons.face, color: Colors.teal),
                      _StatCard(title: 'Face Pending', value: '${data['face_pending'] ?? 0}', icon: Icons.pending_actions, color: Colors.deepOrange),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Class-wise breakdown (student count + today's attendance)
                  Text('Class-wise Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildClassWiseBreakdown(data, theme),
                  const SizedBox(height: 28),
                  _buildRecentAttendance(data, theme),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Quick Actions Grid
            Text('School Management Actions', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _ActionCard(
                  title: 'Register Teacher',
                  icon: Icons.person_add_alt_1,
                  color: Colors.indigo,
                  onTap: () => context.push('/register-teacher'),
                ),
                _ActionCard(
                  title: 'Register Student',
                  icon: Icons.person_add,
                  color: Colors.teal,
                  onTap: () => context.push('/register-student'),
                ),
                _ActionCard(
                  title: 'Classes',
                  icon: Icons.class_,
                  color: Colors.orange,
                  onTap: () => context.push('/classes'),
                ),
                _ActionCard(
                  title: 'Teachers',
                  icon: Icons.school,
                  color: Colors.purple,
                  onTap: () => context.push('/teachers'),
                ),
                _ActionCard(
                  title: 'Students',
                  icon: Icons.groups,
                  color: Colors.blue,
                  onTap: () => context.push('/students'),
                ),
                _ActionCard(
                  title: 'Live Attendance',
                  icon: Icons.camera_front,
                  color: Colors.redAccent,
                  onTap: () => context.push('/attendance-live'),
                ),
                _ActionCard(
                  title: 'Attendance History',
                  icon: Icons.history,
                  color: Colors.blueGrey,
                  onTap: () => context.push('/attendance-history'),
                ),
                _ActionCard(
                  title: 'PDF & Excel Reports',
                  icon: Icons.bar_chart,
                  color: Colors.green,
                  onTap: () => context.push('/reports'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _displayRole(String? role) {
  switch (role?.toLowerCase()) {
    case 'super_admin':
    case 'school_admin':
    case 'admin':
      return 'Admin';
    case 'teacher':
      return 'Teacher';
    case 'student':
      return 'Student';
    default:
      return 'Admin';
  }
}

Widget _buildRecentAttendance(Map<String, dynamic> data, ThemeData theme) {
  final records = data['recent_activity'] as List<dynamic>? ?? const [];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Recent Attendance', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      if (records.isEmpty)
        const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No attendance records yet.')))
      else
        Card(
          child: Column(
            children: [
              for (final record in records)
                ListTile(
                  title: Text(record['student_name']?.toString() ?? 'Unknown'),
                  subtitle: Text('${record['role']?.toString() ?? 'Student'}  •  ${record['class_name']?.toString() ?? 'N/A'}'),
                ),
            ],
          ),
        ),
    ],
  );
}

Widget _buildClassWiseBreakdown(Map<String, dynamic> data, ThemeData theme) {
  final classes = data['class_attendance'] as List<dynamic>? ?? const [];
  if (classes.isEmpty) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: Text('No classes created yet. Register a class to see class-wise statistics.')),
          ],
        ),
      ),
    );
  }

  return Column(
    children: [
      for (final item in classes)
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.primary,
              child: const Icon(Icons.class_, color: Colors.white),
            ),
            title: Text(
              item['class_name']?.toString() ?? 'Unknown Class',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              'Students: ${item['student_count'] ?? 0}  •  Present today: ${item['present'] ?? 0}/${item['marked'] ?? 0}',
            ),
          ),
        ),
    ],
  );
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 36, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard({required this.title, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}
