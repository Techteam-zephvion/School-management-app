import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard.dart';
import '../features/auth/login_screen.dart';
import '../features/docs/docs_page.dart';
import '../features/legal/privacy_policy_view.dart';
import '../features/portal/portal_dashboard.dart';
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

      final atDocs = state.matchedLocation.startsWith('/docs');
      final atLegal = state.matchedLocation.startsWith('/privacy') ||
          state.matchedLocation.startsWith('/terms') ||
          state.matchedLocation.startsWith('/data-safety');
      if (atDocs || atLegal) return null; // Publicly accessible without mandatory login

      final signedIn = auth.session != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      if (atLogin) {
        if (auth.session!.isAdmin) return '/admin';
        if (auth.session!.isTeacher) return '/teacher';
        return '/portal';
      }
      if (state.matchedLocation.startsWith('/admin') && !auth.session!.isAdmin) {
        return auth.session!.isTeacher ? '/teacher' : '/portal';
      }
      if (state.matchedLocation.startsWith('/teacher') && !auth.session!.isTeacher) {
        return auth.session!.isAdmin ? '/admin' : '/portal';
      }
      if (state.matchedLocation.startsWith('/portal') && !auth.session!.isPortalUser) {
        return auth.session!.isAdmin ? '/admin' : '/teacher';
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
