import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_shell.dart';
import 'core/config.dart';
import 'core/onboarding.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Portrait only: the tracking target geometry and the info sheet layout both
  // assume it, and a rotating viewfinder makes tracking harder to hold steady.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  if (Config.isConfigured) {
    await Supabase.initialize(
      url: Config.supabaseUrl,
      publishableKey: Config.supabaseKey,
    );
  }

  final onboarding = await OnboardingStore.load();

  runApp(ArGalleryApp(onboarding: onboarding));
}

class ArGalleryApp extends StatelessWidget {
  const ArGalleryApp({super.key, required this.onboarding});

  final OnboardingStore onboarding;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ARise',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: AppShell(onboarding: onboarding),
    );
  }
}
