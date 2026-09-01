import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class UserState {
  final bool isAuthenticated;
  final String? role; // 'admin', 'teacher', 'student'
  final String? username;
  final String? fullName;
  final int? userId;
  final String? accessToken;

  UserState({
    this.isAuthenticated = false,
    this.role,
    this.username,
    this.fullName,
    this.userId,
    this.accessToken,
  });

  UserState copyWith({
    bool? isAuthenticated,
    String? role,
    String? username,
    String? fullName,
    int? userId,
    String? accessToken,
  }) {
    return UserState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      role: role ?? this.role,
      username: username ?? this.username,
      fullName: fullName ?? this.fullName,
      userId: userId ?? this.userId,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}

class AuthNotifier extends StateNotifier<UserState> {
  AuthNotifier() : super(UserState()) {
    checkLoginStatus();
  }

  Future<void> checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    final role = prefs.getString('user_role');
    final username = prefs.getString('user_name');
    final fullName = prefs.getString('full_name');
    final userId = prefs.getInt('user_id');

    if (token != null && token.isNotEmpty) {
      state = UserState(
        isAuthenticated: true,
        accessToken: token,
        role: role,
        username: username,
        fullName: fullName,
        userId: userId,
      );
    }
  }

  Future<void> loginSuccess({
    required String accessToken,
    required String refreshToken,
    required String role,
    required String username,
    required String fullName,
    required int userId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('user_role', role);
    await prefs.setString('user_name', username);
    await prefs.setString('full_name', fullName);
    await prefs.setInt('user_id', userId);

    state = UserState(
      isAuthenticated: true,
      accessToken: accessToken,
      role: role,
      username: username,
      fullName: fullName,
      userId: userId,
    );
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    state = UserState(isAuthenticated: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, UserState>((ref) {
  return AuthNotifier();
});
