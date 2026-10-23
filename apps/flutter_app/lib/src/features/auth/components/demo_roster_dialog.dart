import 'package:flutter/material.dart';
import '../../../core/fluid_ui.dart';
import '../../../core/models.dart';
import '../../../core/theme.dart';

class DemoAccountInfo {
  final String name;
  final String email;
  final String password;
  final AppRole role;
  final String badgeText;
  final String subtitle;
  final IconData icon;

  const DemoAccountInfo({
    required this.name,
    required this.email,
    required this.password,
    required this.role,
    required this.badgeText,
    required this.subtitle,
    required this.icon,
  });
}

const List<DemoAccountInfo> kAllDemoAccounts = [
  // Admin
  DemoAccountInfo(
    name: 'Dr. Meera Das',
    email: 'admin@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.admin,
    badgeText: 'ADMIN',
    subtitle: 'Principal & Chief Administrator • Full System Access',
    icon: Icons.admin_panel_settings_outlined,
  ),
  // 5 Teachers
  DemoAccountInfo(
    name: 'Priya Menon',
    email: 'teacher-login@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.teacher,
    badgeText: 'MATH',
    subtitle: 'Mathematics • Class Teacher Grade 6A & Educator 6B',
    icon: Icons.co_present_outlined,
  ),
  DemoAccountInfo(
    name: 'Arjun Rao',
    email: 'teacher.rao@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.teacher,
    badgeText: 'SCI',
    subtitle: 'Science (Physics & Chemistry) • Class Teacher 7A & 7B',
    icon: Icons.co_present_outlined,
  ),
  DemoAccountInfo(
    name: 'Sara Iyer',
    email: 'teacher.iyer@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.teacher,
    badgeText: 'ENG',
    subtitle: 'English Literature • Class Teacher Grade 8A & 8B',
    icon: Icons.co_present_outlined,
  ),
  DemoAccountInfo(
    name: 'Vikramaditya Sengupta',
    email: 'teacher.sengupta@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.teacher,
    badgeText: 'SST',
    subtitle: 'Social Studies & Civics • Grade 6B & 7B',
    icon: Icons.co_present_outlined,
  ),
  DemoAccountInfo(
    name: 'Dr. Anita Kulkarni',
    email: 'teacher.kulkarni@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.teacher,
    badgeText: 'CS',
    subtitle: 'Computer Science & AI Lab • Grade 7A & 8A',
    icon: Icons.co_present_outlined,
  ),
  // 10 Students
  DemoAccountInfo(
    name: 'Aarav Sharma',
    email: 'student@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 6A',
    subtitle: 'Roll 06A-01 • PA-001 • Mother: Nisha Sharma • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Anika Nair',
    email: 'student.anika@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 6A',
    subtitle: 'Roll 06A-02 • PA-002 • Father: Vikram Nair • Partial Dues',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Ishaan Gupta',
    email: 'student.ishaan@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 6A',
    subtitle: 'Roll 06A-03 • PA-003 • Mother: Ritika Gupta • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Maya Krishnan',
    email: 'student.maya@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 6B',
    subtitle: 'Roll 06B-01 • PA-004 • Father: Dev Krishnan • Term 1 Due',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Kabir Ali',
    email: 'student.kabir@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 6B',
    subtitle: 'Roll 06B-02 • PA-005 • Mother: Farah Ali • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Diya Patel',
    email: 'student.diya@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 7A',
    subtitle: 'Roll 07A-01 • PA-006 • Father: Mohan Patel • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Rohan Sen',
    email: 'student.rohan@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 7A',
    subtitle: 'Roll 07A-02 • PA-007 • Mother: Ananya Sen • Partial Dues',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Tara Joseph',
    email: 'student.tara@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 7B',
    subtitle: 'Roll 07B-01 • PA-008 • Mother: Leena Joseph • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Vivaan Mehta',
    email: 'student.vivaan@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 8A',
    subtitle: 'Roll 08A-01 • PA-009 • Mother: Kavita Mehta • Fees Paid',
    icon: Icons.school_outlined,
  ),
  DemoAccountInfo(
    name: 'Naina Roy',
    email: 'student.naina@portfolio.schoolic.test',
    password: 'Schoolic@2026',
    role: AppRole.student,
    badgeText: 'GRADE 8B',
    subtitle: 'Roll 08B-01 • PA-010 • Father: Amit Roy • Term 1 Due',
    icon: Icons.school_outlined,
  ),
];

class DemoRosterDialog extends StatefulWidget {
  final void Function(String email, String password, AppRole role) onSelect;

  const DemoRosterDialog({super.key, required this.onSelect});

  static Future<void> show(
    BuildContext context, {
    required void Function(String email, String password, AppRole role) onSelect,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => DemoRosterDialog(onSelect: onSelect),
    );
  }

  @override
  State<DemoRosterDialog> createState() => _DemoRosterDialogState();
}

class _DemoRosterDialogState extends State<DemoRosterDialog> {
  int _selectedFilter = 0; // 0: All, 1: Admin, 2: Teachers, 3: Students

  List<DemoAccountInfo> get _filteredAccounts {
    switch (_selectedFilter) {
      case 1:
        return kAllDemoAccounts.where((a) => a.role == AppRole.admin).toList();
      case 2:
        return kAllDemoAccounts.where((a) => a.role == AppRole.teacher).toList();
      case 3:
        return kAllDemoAccounts.where((a) => a.role == AppRole.student).toList();
      default:
        return kAllDemoAccounts;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isNarrow = media.size.width < 580;

    return Dialog(
      backgroundColor: AppColors.mainBackground,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.rLg,
        side: const BorderSide(color: AppColors.primaryBorder),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: media.size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.brandCyan.withValues(alpha: 0.12),
                      borderRadius: AppRadii.rMd,
                    ),
                    child: const Icon(
                      Icons.supervised_user_circle_outlined,
                      size: 20,
                      color: AppColors.brandCyan,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Demo Accounts Roster',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '1 Admin • 5 Teachers • 10 Students in Production',
                          style: TextStyle(
                            fontFamily: 'Switzer',
                            fontSize: 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppColors.secondaryText),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.primaryBorder),

            // Password Notice Banner
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.secondaryBackground,
                borderRadius: AppRadii.rMd,
                border: Border.all(color: AppColors.primaryBorder),
              ),
              child: Row(
                children: const [
                  Icon(Icons.key_outlined, size: 14, color: AppColors.brandCyan),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'All accounts use standard credential: Schoolic@2026',
                      style: TextStyle(
                        fontFamily: 'Switzer',
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Category Filter Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('All (16)', 0),
                    const SizedBox(width: 8),
                    _filterChip('Admin (1)', 1),
                    const SizedBox(width: 8),
                    _filterChip('Teachers (5)', 2),
                    const SizedBox(width: 8),
                    _filterChip('Students (10)', 3),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),

            // Roster List
            Flexible(
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _filteredAccounts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final acc = _filteredAccounts[index];
                  return _accountCard(acc);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int index) {
    final isSelected = _selectedFilter == index;
    return InkWell(
      onTap: () => setState(() => _selectedFilter = index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryText : AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryText : AppColors.primaryBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Switzer',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : AppColors.secondaryText,
          ),
        ),
      ),
    );
  }

  Widget _accountCard(DemoAccountInfo acc) {
    Color badgeColor;
    switch (acc.role) {
      case AppRole.admin:
        badgeColor = const Color(0xFF8B5CF6);
        break;
      case AppRole.teacher:
        badgeColor = const Color(0xFF0EA5E9);
        break;
      case AppRole.student:
        badgeColor = const Color(0xFF10B981);
        break;
      default:
        badgeColor = AppColors.secondaryText;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.secondaryBackground,
        borderRadius: AppRadii.rMd,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(acc.icon, size: 18, color: badgeColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        acc.name,
                        style: const TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryText,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        acc.badgeText,
                        style: TextStyle(
                          fontFamily: 'Switzer',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  acc.email,
                  style: const TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  acc.subtitle,
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 10,
                    color: AppColors.secondaryText.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FluidPressable(
            onTap: () {
              Navigator.of(context).pop();
              widget.onSelect(acc.email, acc.password, acc.role);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryText,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
