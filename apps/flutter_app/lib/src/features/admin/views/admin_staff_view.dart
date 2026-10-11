import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../shared/components/app_table.dart';
import '../../shared/components/page_header.dart';

class AdminStaffView extends StatelessWidget {
  const AdminStaffView({
    required this.staff,
    required this.onOpenAddStaff,
    super.key,
  });

  final List<Map<String, Object?>> staff;
  final VoidCallback onOpenAddStaff;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PageHeader(
          title: 'Teaching & Administrative Staff',
          description: 'Faculty directory, communication details, and institutional accounts.',
          primaryAction: FilledButton.icon(
            onPressed: onOpenAddStaff,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('Add staff'),
          ),
        ),
        const SizedBox(height: 20),

        AppTable<Map<String, Object?>>(
          title: 'Staff Directory',
          subtitle: 'Active educators and school administrators',
          items: staff,
          count: staff.length,
          emptyMessage: 'No staff members registered yet.',
          filterPredicate: (s, query) {
            final name = '${s['fullName'] ?? ''}'.toLowerCase();
            final email = '${s['email'] ?? ''}'.toLowerCase();
            final phone = '${s['phone'] ?? ''}'.toLowerCase();
            return name.contains(query) || email.contains(query) || phone.contains(query);
          },
          searchHint: 'Search staff by name or email...',
          columns: [
            AppTableColumn(
              header: 'Full Name',
              flex: 3,
              cellBuilder: (context, s) => Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.secondaryBackground,
                    child: Text(
                      '${s['fullName'] ?? 'F'}'[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('${s['fullName'] ?? '—'}', style: AppTypography.compactTableMedium),
                ],
              ),
            ),
            AppTableColumn(
              header: 'Email Address',
              flex: 3,
              cellBuilder: (context, s) => Text('${s['email'] ?? '—'}', style: AppTypography.compactTable),
            ),
            AppTableColumn(
              header: 'Phone Number',
              width: 160,
              cellBuilder: (context, s) => Text('${s['phone'] ?? '—'}', style: AppTypography.compactTable),
            ),
          ],
        ),
      ],
    );
  }
}
