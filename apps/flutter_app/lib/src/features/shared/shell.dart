import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme.dart';
import 'components/shortcuts_dialog.dart';
import 'components/tour_dialog.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.slash, control: true):
            () => ShortcutsDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.slash, meta: true):
            () => ShortcutsDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.keyT, control: true, shift: true):
            () => TourDialog.show(context),
        const SingleActivator(LogicalKeyboardKey.keyT, meta: true, shift: true):
            () => TourDialog.show(context),
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.mainBackground,
          body: child,
        ),
      ),
    );
  }
}
