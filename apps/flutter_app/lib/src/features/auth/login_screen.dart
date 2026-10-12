import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/feedback_banner.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) return;
    ref.read(authControllerProvider).signIn(email, password);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
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
                        // Brand Header
                        Row(
                          children: [
                            const Text(
                              'schoolic.',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.6,
                                color: AppColors.primaryText,
                              ),
                            ),
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

                        if (auth.error != null)
                          FeedbackBanner(
                            message: auth.error!,
                            tone: FeedbackTone.error,
                          ),

                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Institutional Email',
                            hintText: 'user@schoolic.edu',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _password,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            auth.isLoading ? 'Authenticating...' : 'Sign in',
                          ),
                        ),

                        if (AppConfig.isLocalDev &&
                            AppConfig.allowDevSignIn) ...[
                          const SizedBox(height: 24),
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
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => ref
                                            .read(authControllerProvider)
                                            .devSignIn(AppRole.admin),
                                  icon: const Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Dev Admin',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: auth.isLoading
                                      ? null
                                      : () => ref
                                            .read(authControllerProvider)
                                            .devSignIn(AppRole.teacher),
                                  icon: const Icon(
                                    Icons.school_outlined,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'Dev Teacher',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
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
    );
  }
}
