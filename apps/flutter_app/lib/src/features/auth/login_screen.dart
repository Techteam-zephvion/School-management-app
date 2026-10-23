import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// ignore: unused_import
import '../../core/config.dart';
import '../../core/fluid_ui.dart';
// ignore: unused_import
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/theme.dart';
import '../shared/components/brand_deck_dialog.dart';
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

    if (AppConfig.isLocalDev) {
      final lower = email.toLowerCase();
      if (lower.contains('admin')) {
        ref.read(authControllerProvider).devSignIn(AppRole.admin);
        return;
      } else if (lower.contains('teacher')) {
        ref.read(authControllerProvider).devSignIn(AppRole.teacher);
        return;
      } else if (lower.contains('student')) {
        ref.read(authControllerProvider).devSignIn(AppRole.student);
        return;
      }
    }

    ref.read(authControllerProvider).signIn(email, password);
  }

  Widget _shortcutBadge(String keyLabel, String actionLabel,
      {bool isClickable = false}) {
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

  Widget _demoChip({
    required IconData icon,
    required String label,
    required String email,
    required String password,
    required AppRole role,
  }) {
    return FluidPressable(
      onTap: () {
        _email.text = email;
        _password.text = password;
        setState(() => _validationError = null);
        if (AppConfig.isLocalDev) {
          ref.read(authControllerProvider).devSignIn(role);
        } else {
          ref.read(authControllerProvider).signIn(email, password);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.secondaryBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primaryBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: AppColors.primaryText),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Switzer',
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.primaryText,
              ),
            ),
          ],
        ),
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
          backgroundColor: const Color(0xFFF6F8FA),
          resizeToAvoidBottomInset: true,
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 940;
                final isPhone = constraints.maxWidth < 520;
                final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

                final loginTerminal = Container(
                  width: isDesktop ? 420 : double.infinity,
                  padding: EdgeInsets.all(isPhone ? 24 : 36),
                  color: AppColors.mainBackground,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const SchoolicLogo(size: 26),
                          const Spacer(),
                          const FluidMascotInsignia(size: 24, showStatusDot: false),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Institutional school management workspace.',
                        style: AppTypography.bodySecondary,
                      ),
                      const SizedBox(height: 20),
                      const Divider(
                        height: 1,
                        color: AppColors.primaryBorder,
                      ),
                      const SizedBox(height: 20),

                      if (displayError != null) ...[
                        FeedbackBanner(
                          message: displayError,
                          tone: FeedbackTone.error,
                        ),
                        const SizedBox(height: 12),
                      ],

                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        onSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Institutional Email',
                          hintText: 'name@institution.edu',
                          filled: true,
                          fillColor: AppColors.secondaryBackground.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.brandCyan, width: 1.5),
                          ),
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
                          filled: true,
                          fillColor: AppColors.secondaryBackground.withValues(alpha: 0.5),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.primaryBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppRadii.rMd,
                            borderSide: const BorderSide(color: AppColors.brandCyan, width: 1.5),
                          ),
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
                              () => _obscurePassword = !_obscurePassword,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _demoChip(
                            icon: Icons.school_outlined,
                            label: 'Student Demo',
                            email: 'student@portfolio.schoolic.test',
                            password: 'Schoolic@2026',
                            role: AppRole.student,
                          ),
                          _demoChip(
                            icon: Icons.co_present_outlined,
                            label: 'Teacher Demo',
                            email: 'teacher-login@portfolio.schoolic.test',
                            password: 'Schoolic@2026',
                            role: AppRole.teacher,
                          ),
                          _demoChip(
                            icon: Icons.admin_panel_settings_outlined,
                            label: 'Admin Demo',
                            email: 'admin@portfolio.schoolic.test',
                            password: 'Schoolic@2026',
                            role: AppRole.admin,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Fluid Agency Island CTA
                      FluidIslandButton(
                        label: auth.isLoading ? 'Authenticating...' : 'Sign in',
                        isLoading: auth.isLoading,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: auth.isLoading ? null : _submit,
                        backgroundColor: AppColors.primaryText,
                        foregroundColor: Colors.white,
                        radius: 8.0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      ),
                      const SizedBox(height: 18),

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
                      const SizedBox(height: 10),

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
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                      const SizedBox(height: 4),

                      // Official Brand Deck presentation trigger
                      Center(
                        child: TextButton.icon(
                          onPressed: () => BrandDeckDialog.show(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.auto_stories_outlined,
                            size: 14,
                            color: AppColors.brandCyanDark,
                          ),
                          label: const Text(
                            'Design System & Brand Deck',
                            style: TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.brandCyanDark,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Documentation & How-To Guides link
                      Center(
                        child: TextButton.icon(
                          onPressed: () => context.push('/docs'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(
                            Icons.menu_book_outlined,
                            size: 14,
                            color: AppColors.secondaryText,
                          ),
                          label: const Text(
                            'User Manual & Feature Documentation',
                            style: TextStyle(
                              fontFamily: 'Switzer',
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryText,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Legal, Privacy & Data Safety for Store Compliance
                      Wrap(
                        alignment: WrapAlignment.center,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () => context.push('/privacy'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Privacy Policy & Data Safety',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 11,
                                color: AppColors.secondaryText,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                          const Text('•', style: TextStyle(color: AppColors.mutedText, fontSize: 10)),
                          TextButton(
                            onPressed: () => context.push('/terms'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Terms of Service',
                              style: TextStyle(
                                fontFamily: 'Switzer',
                                fontSize: 11,
                                color: AppColors.secondaryText,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

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
                    child: FluidDoubleBezel(
                      outerPadding: const EdgeInsets.all(4.0),
                      outerRadius: 24.0,
                      innerRadius: 20.0,
                      outerColor: const Color(0x08000000),
                      outerBorderColor: const Color(0x14000000),
                      innerColor: AppColors.mainBackground,
                      innerShadow: AppShadows.ambientElevated,
                      child: isDesktop
                          ? IntrinsicHeight(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _BrandHeroPanel(
                                    onOpenDeck: () =>
                                        BrandDeckDialog.show(context),
                                  ),
                                  Container(
                                    width: 1,
                                    color: const Color(0x12000000),
                                  ),
                                  loginTerminal,
                                ],
                              ),
                            )
                          : Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _CompactMobileBrandHeader(
                                  onOpenDeck: () =>
                                      BrandDeckDialog.show(context),
                                ),
                                loginTerminal,
                              ],
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

/// Atmospheric Lord Espandor Showcase Panel for Desktop Master Console.
class _BrandHeroPanel extends StatelessWidget {
  const _BrandHeroPanel({required this.onOpenDeck});

  final VoidCallback onOpenDeck;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 440,
      padding: const EdgeInsets.all(36),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1017),
        gradient: RadialGradient(
          center: Alignment(0.0, 0.2),
          radius: 0.9,
          colors: [
            Color(0x3300A3FF), // Electric cyan atmospheric glow
            Color(0xFF0C1017),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SchoolicLogo(
                size: 26,
                color: Colors.white,
                dotColor: AppColors.brandCyan,
              ),
              SizedBox(height: 20),
              Text(
                'The Operating System\nfor Modern Institutions',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 1.18,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Soft Cyan Ambient Halo
                Container(
                  width: 200,
                  height: 200,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x3300A3FF),
                        blurRadius: 60,
                        spreadRadius: 10,
                      ),
                    ],
                  ),
                ),
                Image.asset(
                  'assets/branding/lord_espandor_standing_transparent.png',
                  height: 240,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => const SizedBox(height: 240),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Anchored by Lord Espandor, Schoolic unifies academic operations, intelligent copilot workflows, and institutional governance.',
                style: TextStyle(
                  fontFamily: 'Switzer',
                  fontSize: 12,
                  height: 1.45,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              FluidPressable(
                onTap: onOpenDeck,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.brandCyan,
                    borderRadius: AppRadii.rSm,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brandCyan.withValues(alpha: 0.35),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.auto_stories_outlined, size: 16, color: Colors.black),
                      SizedBox(width: 8),
                      Text(
                        'Explore Design System',
                        style: TextStyle(
                          fontFamily: 'Switzer',
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact Header for Mobile Consoles.
class _CompactMobileBrandHeader extends StatelessWidget {
  const _CompactMobileBrandHeader({required this.onOpenDeck});

  final VoidCallback onOpenDeck;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0C1017),
        border: Border(bottom: BorderSide(color: Color(0x1FFFFFFF))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.brandCyan, width: 1.5),
              boxShadow: AppShadows.glowCyan,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/branding/lord_espandor_avatar.png',
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Schoolic.',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Anchored by Lord Espandor',
                  style: TextStyle(
                    fontFamily: 'Switzer',
                    fontSize: 11,
                    color: AppColors.brandCyan,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onOpenDeck,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.brandCyan,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size.zero,
            ),
            child: const Text('Deck', style: TextStyle(fontFamily: 'Switzer', fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
