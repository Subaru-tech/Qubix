import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme.dart';
import 'core/router.dart';
import 'core/utils/api_client.dart';

import 'core/theme/theme_notifier.dart';

import 'package:firebase_core/firebase_core.dart';
import 'core/services/push_notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp();
  } catch (e) {
    // Usually means google-services.json is missing or invalid.
    // We catch this so the app doesn't immediately crash if the user hasn't added it yet.
    debugPrint('Firebase init failed: $e');
  }

  // Make system UI match our dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0F0F12), // QubixColors.background
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ],
  );

  try {
    // Initialize Push Notifications
    await container.read(pushNotificationServiceProvider).initialize();
    await container.read(pushNotificationServiceProvider).handleInitialMessage();
  } catch (e) {
    debugPrint('Push notifications init failed: $e');
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const QubixApp(),
    ),
  );
}

class QubixApp extends ConsumerWidget {
  const QubixApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeState = ref.watch(themeProvider);

    ref.listen<String?>(notificationTapProvider, (previous, next) {
      if (next != null && context.mounted) {
        router.push('/chats/$next');
      }
    });

    return MaterialApp.router(
      title: AppConstants.appName,
      theme: QubixTheme.dark, // We will extend this to support light theme if necessary
      darkTheme: QubixTheme.dark,
      themeMode: themeState.themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
