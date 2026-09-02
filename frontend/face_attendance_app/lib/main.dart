import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/network/api_client.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'features/auth/providers/auth_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Print the resolved API base URL so it's visible in the debug console.
  final apiClient = await ApiClient.fromPrefs();
  developer.log('Resolved API base URL: ${apiClient.baseUrl}', name: 'APP');

  runApp(
    const ProviderScope(
      child: FaceAttendanceApp(),
    ),
  );
}

class FaceAttendanceApp extends ConsumerWidget {
  const FaceAttendanceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'AI Face Attendance System',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: router,
    );
  }
}
