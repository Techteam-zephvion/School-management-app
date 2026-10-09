import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

class AppShell extends ConsumerWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final session = auth.session;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schoolic'),
        actions: [
          if (session?.isAdmin ?? false)
            TextButton.icon(
              onPressed: () => context.go('/admin'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Admin'),
            ),
          if (session?.isTeacher ?? false)
            TextButton.icon(
              onPressed: () => context.go('/teacher'),
              icon: const Icon(Icons.fact_check_outlined),
              label: const Text('Teacher'),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(child: Text(session?.email ?? '')),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(authControllerProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
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
      padding: const EdgeInsets.all(24),
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 12,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineMedium),
            if (actions != null) Wrap(spacing: 8, runSpacing: 8, children: actions!),
          ],
        ),
        const SizedBox(height: 20),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.labelLarge),
                Text(value, style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
