import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';

/// Shared helpers for the management screens (classes / students / teachers).

/// Extracts a plain list from the API envelope. Handles both paginated and
/// non-paginated responses across all backend versions.
List<Map<String, dynamic>> extractList(dynamic data) {
  dynamic raw = data;
  if (raw is Map && raw['data'] != null) raw = raw['data'];
  if (raw is Map && raw['results'] != null) raw = raw['results'];
  if (raw is List) {
    return raw.whereType<Map<String, dynamic>>().toList();
  }
  return <Map<String, dynamic>>[];
}

/// Extracts pagination metadata (count / total_pages / current_page).
Map<String, dynamic> extractMeta(dynamic data) {
  if (data is Map && data['meta'] is Map) {
    return (data['meta'] as Map).cast<String, dynamic>();
  }
  if (data is Map && data['data'] is Map) {
    final inner = data['data'];
    if (inner is Map && inner['count'] != null) {
      return inner.cast<String, dynamic>();
    }
  }
  return const {};
}

String errorMessage(Object e) {
  if (e is DioException) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) return data['message'].toString();
    if (data is Map && data['detail'] != null) return data['detail'].toString();
    return e.message ?? 'Network error';
  }
  return e.toString();
}

Future<ApiClient> api() => ApiClient.fromPrefs();

/// Resolves the photo URL for a user payload (relative media paths work too).
String? resolvePhoto(Map<String, dynamic> userData) {
  final pic = userData['profile_picture'];
  if (pic == null || (pic is String && pic.isEmpty)) return null;
  final raw = pic.toString();
  if (raw.startsWith('http')) return raw;
  // Best-effort: derive base from compile-time default.
  const base = String.fromEnvironment('API_BASE_URL',
      defaultValue: 'http://192.168.1.5:8000/');
  final root = base.replaceFirst(RegExp(r'/api/?$'), '/');
  return '$root$raw';
}

/// Modern user avatar that falls back to initials.
class UserAvatar extends StatelessWidget {
  final Map<String, dynamic> userData;
  final double radius;
  const UserAvatar({super.key, required this.userData, this.radius = 26});

  @override
  Widget build(BuildContext context) {
    final url = resolvePhoto(userData);
    final name = (userData['full_name'] ?? userData['username'] ?? '?') as String;
    return CircleAvatar(
      radius: radius,
      backgroundImage: url != null ? NetworkImage(url) : null,
      child: url == null
          ? Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.bold),
            )
          : null,
    );
  }
}

/// Green/gray "Face Registered" chip.
class FaceStatusChip extends StatelessWidget {
  final bool registered;
  const FaceStatusChip({super.key, required this.registered});

  @override
  Widget build(BuildContext context) {
    final color = registered ? Colors.green : Colors.orange;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(registered ? Icons.face : Icons.face_retouching_off,
              size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            registered ? 'Face Registered' : 'Face Pending',
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Confirmation dialog used by every delete action.
Future<bool> confirmDelete(BuildContext context, String label) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded,
          color: Colors.redAccent, size: 48),
      title: Text('Delete $label?'),
      content: Text(
        'This will permanently remove $label along with related records. '
        'This action cannot be undone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: error ? Colors.redAccent : Colors.green,
      behavior: SnackBarBehavior.floating,
    ),
  );
}
