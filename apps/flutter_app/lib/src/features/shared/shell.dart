import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../../core/theme.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/admin')) {
      return Scaffold(
        backgroundColor: AppColors.mainBackground,
        body: child,
      );
    }

    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    return Scaffold(
      backgroundColor: AppColors.mainBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(52),
        child: Container(
          decoration: const BoxDecoration(
            color: AppColors.mainBackground,
            border: Border(bottom: BorderSide(color: AppColors.primaryBorder)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              const Text(
                'schoolic.',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(width: 16),
              Container(width: 1, height: 18, color: AppColors.primaryBorder),
              const SizedBox(width: 16),
              const Text(
                'Teacher Portal',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.secondaryText,
                ),
              ),
              const Spacer(),
              if (session?.isAdmin ?? false)
                TextButton(
                  onPressed: () => context.go('/admin'),
                  child: const Text('Switch to Admin', style: TextStyle(fontSize: 13)),
                ),
              const SizedBox(width: 12),
              Text(
                session?.email ?? '',
                style: const TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 13,
                  color: AppColors.secondaryText,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Sign out',
                iconSize: 18,
                onPressed: () => ref.read(authControllerProvider).signOut(),
                icon: const Icon(Icons.logout, color: AppColors.secondaryText),
              ),
            ],
          ),
        ),
      ),
      body: child,
    );
  }
}

class PageFrame extends StatelessWidget {
  const PageFrame({required this.title, required this.child, this.actions, super.key});

  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(title, style: AppTypography.pageTitle),
            if (actions != null) Row(children: actions!),
          ],
        ),
        const SizedBox(height: 24),
        child,
      ],
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({required this.title, required this.value, required this.icon, super.key});

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.mainBackground,
        border: Border.all(color: AppColors.primaryBorder),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: AppColors.secondaryText),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.label),
              const SizedBox(height: 2),
              Text(value, style: AppTypography.sectionHeading),
            ],
          ),
        ],
      ),
    );
  }
}
