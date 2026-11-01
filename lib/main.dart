import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'utils/app_errors.dart';
import 'widgets/offline_banner.dart';
import 'widgets/state_views.dart';

Future<void> main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      AppErrors.log(details.exception, details.stack);
    };

    // Release me laal crash screen ki jagah saaf message
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const FriendlyErrorWidget();
    }

    await Firebase.initializeApp();
    runApp(const SurpatneJewellersApp());
  }, (error, stack) => AppErrors.log(error, stack));
}

class SurpatneJewellersApp extends StatelessWidget {
  const SurpatneJewellersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Surpatne Jewellers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      builder: (context, child) => OfflineBanner(child: child ?? const SizedBox.shrink()),
      home: const SplashScreen(),
    );
  }
}