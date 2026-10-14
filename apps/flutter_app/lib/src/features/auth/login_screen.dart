import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';
import '../shared/components/schoolic_logo.dart';
import '../shared/components/shortcuts_dialog.dart';
import '../shared/components/tour_dialog.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _obscurePassword = true;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (await TourDialog.shouldShowAutoTour()) {
        if (mounted) {
          TourDialog.show(context, isFirstVisit: true);
        }
      }
    });
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() {
        _validationError =
            'Please enter both your institutional email and password.';
      });
      return;
    }
    setState(() => _validationError = null);
    ref.read(authControllerProvider).signIn(email, password);
  }

  Widget _shortcutBadge(String keyLabel, String actionLabel, {bool isClickable = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: isClickable
            ? AppColors.secondaryBackground
            : AppColors.mainBackground,
        borderRadius: AppRadii.rSm,
        border: Border.all(color: AppColors.primaryBorder),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            keyLabel,
            style: const TextStyle(
              fontFamily: 'Switzer',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            actionLabel,
            style: const TextStyle(
              fontFamily: 'Switzer',
              fontSize: 10,
              color: AppColors.mutedText,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final displayError = _validationError ?? auth.error;

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
          backgroundColor: AppColors.secondaryBackground,
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isPhone = constraints.maxWidth < 520;
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
                return Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: EdgeInsets.fromLTRB(
                      isPhone ? 16 : 24,
                      isPhone ? 16 : 24,
                      isPhone ? 16 : 24,
                      (isPhone ? 16 : 24) + bottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Container(
                        padding: EdgeInsets.all(isPhone ? 22 : 32),
                        decoration: BoxDecoration(
                          color: AppColors.mainBackground,
                          border: Border.all(color: AppColors.primaryBorder),
                          borderRadius: AppRadii.rLg,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Brand Header: full horizontal logo Schoolic.
                            Row(
                              children: [
                                const SchoolicLogo(size: 26),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondaryBackground,
                                    borderRadius: AppRadii.rSm,
                                    border: Border.all(
                                      color: AppColors.primaryBorder,
                                    ),
                                  ),
                                  child: const Text(
                                    'V1 PILOT',
                                    style: TextStyle(
                                      fontFamily: 'Switzer',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.secondaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Institutional school management workspace.',
                              style: AppTypography.bodySecondary,
                            ),
                            const SizedBox(height: 24),
                            const Divider(
                              height: 1,
                              color: AppColors.primaryBorder,
                            ),
                            const SizedBox(height: 20),

                            if (displayError != null)
                              FeedbackBanner(
                                message: displayError,
                                tone: FeedbackTone.error,
                              ),

                            TextField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _submit(),
                              decoration: const InputDecoration(
                                labelText: 'Institutional Email',
                                hintText: 'name@institution.edu',
                              ),
                            ),
                            const SizedBox(height: 12),
                            TextField(
                              controller: _password,
                              obscureText: _obscurePassword,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _submit(),
                              decoration: InputDecoration(
                                labelText: 'Password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: AppColors.secondaryText,
                                  ),
                                  tooltip: _obscurePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () =>
                                        _obscurePassword = !_obscurePassword,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.school, size: 14),
                                  label: const Text(
                                    'Student Demo',
                                    style: TextStyle(fontFamily: 'Switzer', fontSize: 11),
                                  ),
                                  onPressed: () {
                                    _email.text = 'student@portfolio.schoolic.test';
                                    _password.text = 'Schoolic@2026';
                                    setState(() => _validationError = null);
                                  },
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.co_present_outlined, size: 14),
                                  label: const Text(
                                    'Teacher Demo',
                                    style: TextStyle(fontFamily: 'Switzer', fontSize: 11),
                                  ),
                                  onPressed: () {
                                    _email.text = 'teacher-login@portfolio.schoolic.test';
                                    _password.text = 'Schoolic@2026';
                                    setState(() => _validationError = null);
                                  },
                                ),
                                ActionChip(
                                  avatar: const Icon(Icons.admin_panel_settings_outlined, size: 14),
                                  label: const Text(
                                    'Admin Demo',
                                    style: TextStyle(fontFamily: 'Switzer', fontSize: 11),
                                  ),
                                  onPressed: () {
                                    _email.text = 'admin@portfolio.schoolic.test';
                                    _password.text = 'Schoolic@2026';
                                    setState(() => _validationError = null);
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: auth.isLoading ? null : _submit,
                              icon: auth.isLoading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.arrow_forward, size: 16),
                              label: Text(
                                auth.isLoading
                                    ? 'Authenticating...'
                                    : 'Sign in',
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Keyboard Shortcuts Bar
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _shortcutBadge('↵ Enter', 'Sign in'),
                                _shortcutBadge('Tab', 'Next'),
                                InkWell(
                                  onTap: () => ShortcutsDialog.show(context),
                                  borderRadius: AppRadii.rSm,
                                  child: _shortcutBadge(
                                    '?',
                                    'Shortcuts',
                                    isClickable: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // First-time tour button
                            Center(
                              child: TextButton.icon(
                                onPressed: () => TourDialog.show(context),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  minimumSize: Size.zero,
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                                icon: const Icon(
                                  Icons.explore_outlined,
                                  size: 14,
                                  color: AppColors.secondaryText,
                                ),
                                label: const Text(
                                  'First time here? Explore Product Tour',
                                  style: TextStyle(
                                    fontFamily: 'Switzer',
                                    fontSize: 11,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            ),

                            if (AppConfig.isLocalDev &&
                                AppConfig.allowDevSignIn) ...[
                              const SizedBox(height: 20),
                              const Divider(
                                height: 1,
                                color: AppColors.primaryBorder,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'LOCAL DEVELOPMENT ACCESS',
                                style: TextStyle(
                                  fontFamily: 'Switzer',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                  color: AppColors.mutedText,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _DevAccessButton(
                                    label: 'Dev Admin',
                                    icon: Icons.admin_panel_settings_outlined,
                                    enabled: !auth.isLoading,
                                    onPressed: () => ref
                                        .read(authControllerProvider)
                                        .devSignIn(AppRole.admin),
                                  ),
                                  _DevAccessButton(
                                    label: 'Dev Teacher',
                                    icon: Icons.school_outlined,
                                    enabled: !auth.isLoading,
                                    onPressed: () => ref
                                        .read(authControllerProvider)
                                        .devSignIn(AppRole.teacher),
                                  ),
                                  _DevAccessButton(
                                    label: 'Dev Parent',
                                    icon: Icons.family_restroom_outlined,
                                    enabled: !auth.isLoading,
                                    onPressed: () => ref
                                        .read(authControllerProvider)
                                        .devSignIn(AppRole.parent),
                                  ),
                                  _DevAccessButton(
                                    label: 'Dev Student',
                                    icon: Icons.person_outline,
                                    enabled: !auth.isLoading,
                                    onPressed: () => ref
                                        .read(authControllerProvider)
                                        .devSignIn(AppRole.student),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _DevAccessButton extends StatelessWidget {
  const _DevAccessButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 142,
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
