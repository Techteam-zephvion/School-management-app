import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/page_header.dart';

class AdminSettingsView extends StatelessWidget {
  const AdminSettingsView({
    required this.years,
    required this.schoolName,
    super.key,
  });

  final List<Map<String, Object?>> years;
  final String schoolName;

  @override
  Widget build(BuildContext context) {
    final activeYear = years.isNotEmpty ? '${years.first['name']}' : '2026-2027';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'System Settings',
          description: 'Environment configurations, institutional metadata, and infrastructure status.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Institutional Configuration', style: AppTypography.subsectionHeading),
              const SizedBox(height: 16),
              _settingRow('Institution Name', schoolName),
              _settingRow('Active Academic Year', activeYear),
              _settingRow('Application Version', 'Schoolic Phase 5.2 (UX Redesign)'),
              _settingRow('Typography', 'Switzer (Bundled Fontshare Free License)'),
              _settingRow('Design Identity', 'Strict Monochrome (#111111 / #FFFFFF) with Emerald (#10A37F) Accent'),
              _settingRow('Database Layer', 'Neon Serverless PostgreSQL (Drizzle ORM)'),
              _settingRow('Edge Gateway', 'Cloudflare Workers (Hono TypeScript Runtime)'),
              _settingRow('Authentication', 'Neon Managed Auth (Better Auth JWT + Role Enforcement)'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.bodySecondary),
          Text(value, style: AppTypography.bodyMedium),
        ],
      ),
    );
  }
}
