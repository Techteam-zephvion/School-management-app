import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/admin/admin_dashboard.dart';
import '../features/auth/login_screen.dart';
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

      final signedIn = auth.session != null;
      final atLogin = state.matchedLocation == '/login';
      if (!signedIn) return atLogin ? null : '/login';
      if (atLogin) {
        return auth.session!.isAdmin ? '/admin' : '/teacher';
      }
      if (state.matchedLocation.startsWith('/admin') && !auth.session!.isAdmin) {
        return '/teacher';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/admin', builder: (context, state) => const AdminDashboard()),
          GoRoute(path: '/teacher', builder: (context, state) => const TeacherDashboard()),
        ],
      ),
    ],
  );
});
