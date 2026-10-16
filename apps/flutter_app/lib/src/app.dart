import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/localization/app_localizations.dart';
import 'core/router.dart';
import 'core/theme.dart';

class SchoolicApp extends ConsumerWidget {
  const SchoolicApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final appLanguage = ref.watch(appLanguageProvider);

    return MaterialApp.router(
      title: 'Schoolic',
      debugShowCheckedModeBanner: false,
      theme: buildSchoolicTheme(),
      locale: appLanguage.locale,
      routerConfig: router,
    );
  }
}
