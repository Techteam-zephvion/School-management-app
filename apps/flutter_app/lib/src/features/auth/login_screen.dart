import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Schoolic', style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 8),
                  const Text('Sign in with your pilot account.'),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  if (auth.error != null) ...[
                    const SizedBox(height: 12),
                    Text(auth.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: auth.isLoading
                        ? null
                        : () => ref.read(authControllerProvider).signIn(_email.text, _password.text),
                    icon: const Icon(Icons.login),
                    label: Text(auth.isLoading ? 'Signing in...' : 'Sign in'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () => ref.read(authControllerProvider).devSignIn(AppRole.admin),
                        icon: const Icon(Icons.admin_panel_settings_outlined),
                        label: const Text('Dev admin'),
                      ),
                      OutlinedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () => ref.read(authControllerProvider).devSignIn(AppRole.teacher),
                        icon: const Icon(Icons.fact_check_outlined),
                        label: const Text('Dev teacher'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
