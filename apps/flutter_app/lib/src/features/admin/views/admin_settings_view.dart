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
    final activeYear = years.isNotEmpty
        ? '${years.first['name']}'
        : '2026-2027';
    final isPhone = MediaQuery.sizeOf(context).width < 560;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PageHeader(
          title: 'System Settings',
          description: 'Environment configurations, institutional metadata, and infrastructure status.',
        ),
        const SizedBox(height: 20),

        Container(
          padding: EdgeInsets.all(isPhone ? 18 : 24),
          decoration: BoxDecoration(
            color: AppColors.mainBackground,
            border: Border.all(color: AppColors.primaryBorder),
            borderRadius: AppRadii.rLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Institutional Configuration',
                style: AppTypography.subsectionHeading,
              ),
              const SizedBox(height: 16),
              _settingRow('Institution Name', schoolName, isPhone: isPhone),
              _settingRow('Active Academic Year', activeYear, isPhone: isPhone),
              _settingRow(
                'Application Version',
                'Schoolic v1.0.0 (Production Release Build)',
                isPhone: isPhone,
              ),
              _settingRow(
                'Real-time Sync',
                'Active (Automated Live Background Sync)',
                isPhone: isPhone,
              ),
              _settingRow(
                'Typography',
                'Switzer (Bundled Fontshare Free License)',
                isPhone: isPhone,
              ),
              _settingRow(
                'Design Identity',
                'Strict Monochrome (#111111 / #FFFFFF) with Emerald (#10A37F) Accent',
                isPhone: isPhone,
              ),
              _settingRow(
                'Database Layer',
                'Neon Serverless PostgreSQL (Drizzle ORM)',
                isPhone: isPhone,
              ),
              _settingRow(
                'Edge Gateway',
                'Cloudflare Workers (Hono TypeScript Runtime)',
                isPhone: isPhone,
              ),
              _settingRow(
                'Authentication',
                'Neon Managed Auth (Better Auth JWT + Role Enforcement)',
                isPhone: isPhone,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String label, String value, {required bool isPhone}) {
    if (isPhone) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTypography.bodySecondary),
            const SizedBox(height: 4),
            Text(value, style: AppTypography.bodyMedium, softWrap: true),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: AppTypography.bodySecondary)),
          const SizedBox(width: 24),
          Expanded(
            flex: 2,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppTypography.bodyMedium,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
