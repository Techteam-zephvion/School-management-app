import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard.dart';
import '../features/auth/login_screen.dart';
import '../features/docs/docs_page.dart';
import '../features/legal/privacy_policy_view.dart';
import '../features/portal/portal_dashboard.dart';
import '../features/public/public_admissions_view.dart';
import '../features/public/public_certificate_verify_view.dart';
import '../features/shared/shell.dart';
import '../features/teacher/teacher_dashboard.dart';
import 'providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: auth,
    redirect: (context, state) {
      if (auth.isLoading) return null;

      // Publicly accessible without mandatory login
      final atPublic = state.matchedLocation.startsWith('/docs') ||
          state.matchedLocation.startsWith('/privacy') ||
          state.matchedLocation.startsWith('/terms') ||
          state.matchedLocation.startsWith('/data-safety') ||
          state.matchedLocation.startsWith('/apply') ||
          state.matchedLocation.startsWith('/verify');
      if (atPublic) return null;

      final signedIn = auth.session != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      if (atLogin) {
        if (auth.session!.isInstitutionalStaff) return '/admin';
        if (auth.session!.isTeacher) return '/teacher';
        return '/portal';
      }
      if (state.matchedLocation.startsWith('/admin') &&
          !auth.session!.isInstitutionalStaff) {
        return auth.session!.isTeacher ? '/teacher' : '/portal';
      }
      if (state.matchedLocation.startsWith('/teacher') &&
          !auth.session!.isTeacher) {
        return auth.session!.isInstitutionalStaff ? '/admin' : '/portal';
      }
      if (state.matchedLocation.startsWith('/portal') &&
          !auth.session!.isPortalUser) {
        return auth.session!.isInstitutionalStaff ? '/admin' : '/teacher';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/docs', builder: (context, state) => const DocsPage()),
      GoRoute(
        path: '/privacy',
        builder: (context, state) =>
            const PrivacyPolicyView(initialSection: LegalSection.privacy),
      ),
      GoRoute(
        path: '/terms',
        builder: (context, state) =>
            const PrivacyPolicyView(initialSection: LegalSection.terms),
      ),
      GoRoute(
        path: '/data-safety',
        builder: (context, state) =>
            const PrivacyPolicyView(initialSection: LegalSection.dataSafety),
      ),
      GoRoute(
        path: '/apply/:schoolCode',
        builder: (context, state) => PublicAdmissionsView(
          schoolCode: state.pathParameters['schoolCode'] ?? '',
        ),
      ),
      GoRoute(
        path: '/verify/:code',
        builder: (context, state) => PublicCertificateVerifyView(
          code: state.pathParameters['code'] ?? '',
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboard()),
          GoRoute(path: '/teacher', builder: (context, state) => const TeacherDashboard()),
          GoRoute(path: '/portal', builder: (context, state) => const PortalDashboard()),
        ],
      ),
    ],
  );
});
