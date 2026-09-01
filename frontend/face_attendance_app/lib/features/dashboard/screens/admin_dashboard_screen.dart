import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../auth/providers/auth_provider.dart';

final dashboardSummaryProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final apiClient = ApiClient();
    final response = await apiClient.dio.get('reports/dashboard/');
    return response.data['data'] ?? {};
  } catch (e) {
    return {
      'total_students': 0,
      'total_teachers': 0,
      'total_classes': 0,
      'today_present': 0,
      'today_absent': 0,
      'face_registered': 0,
      'face_pending': 0,
      'attendance_rate': 0.0,
    };
  }
});

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final userState = ref.watch(authProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final dashboardAsync = ref.watch(dashboardSummaryProvider);

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
                          Text('Role: ${(userState.role ?? "admin").toUpperCase()} | AI Face Attendance ERP System'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Stat Cards Grid
            Text('Live System Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            dashboardAsync.when(
              loading: () => const Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator())),
              error: (err, stack) => const Text('Failed to load live metrics from database.'),
              data: (data) => GridView.count(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(title: 'Total Students', value: '${data['total_students'] ?? 0}', icon: Icons.groups, color: Colors.blue),
                  _StatCard(title: 'Total Teachers', value: '${data['total_teachers'] ?? 0}', icon: Icons.school, color: Colors.purple),
                  _StatCard(title: 'Total Classes', value: '${data['total_classes'] ?? 0}', icon: Icons.class_, color: Colors.orange),
                  _StatCard(title: "Today's Rate", value: '${data['attendance_rate'] ?? 0.0}%', icon: Icons.check_circle, color: Colors.green),
                  _StatCard(title: 'Present Today', value: '${data['today_present'] ?? 0}', icon: Icons.how_to_reg, color: Colors.lightGreen),
                  _StatCard(title: 'Absent Today', value: '${data['today_absent'] ?? 0}', icon: Icons.person_off, color: Colors.redAccent),
                  _StatCard(title: 'Face Registered', value: '${data['face_registered'] ?? 0}', icon: Icons.face, color: Colors.teal),
                  _StatCard(title: 'Face Pending', value: '${data['face_pending'] ?? 0}', icon: Icons.pending_actions, color: Colors.deepOrange),
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
