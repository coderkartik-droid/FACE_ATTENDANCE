import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  String _selectedFormat = 'Excel (.xlsx)';
  bool _isExporting = false;

  void _exportReport() {
    setState(() => _isExporting = true);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully exported attendance report as $_selectedFormat!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports & Export')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Export Attendance Records', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Generate full attendance logs in Excel spreadsheet or PDF document format.', style: theme.textTheme.bodyMedium),
            const SizedBox(height: 24),

            // Format Selection Cards
            _FormatSelectionCard(
              title: 'Excel Spreadsheet (.xlsx)',
              subtitle: 'Includes date, roll number, student name, verification method, and score',
              icon: Icons.table_chart,
              iconColor: Colors.green,
              isSelected: _selectedFormat == 'Excel (.xlsx)',
              onTap: () => setState(() => _selectedFormat = 'Excel (.xlsx)'),
            ),
            const SizedBox(height: 16),
            _FormatSelectionCard(
              title: 'PDF Report (.pdf)',
              subtitle: 'Printable formatted document with headers and summary statistics',
              icon: Icons.picture_as_pdf,
              iconColor: Colors.red,
              isSelected: _selectedFormat == 'PDF (.pdf)',
              onTap: () => setState(() => _selectedFormat = 'PDF (.pdf)'),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _isExporting ? null : _exportReport,
                icon: const Icon(Icons.download),
                label: _isExporting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('Download $_selectedFormat Report', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatSelectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final bool isSelected;
  final VoidCallback onTap;

  const _FormatSelectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? theme.primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, color: iconColor, size: 40),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(subtitle, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? theme.primaryColor : Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
