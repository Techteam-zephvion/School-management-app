import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';

class SchoolicApp extends ConsumerWidget {
  const SchoolicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'Schoolic',
      debugShowCheckedModeBanner: false,
      theme: buildSchoolicTheme(),
      routerConfig: router,
    );
  }
}
