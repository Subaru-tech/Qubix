import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_constants.dart';
import 'core/theme/theme.dart';
import 'core/router.dart';
import 'core/utils/api_client.dart';
import 'core/services/snackbar_service.dart';

import 'core/theme/theme_notifier.dart';

import 'package:firebase_core/firebase_core.dart';
import 'core/services/push_notification_service.dart';
import 'core/services/deep_link_service.dart';

import 'presentation/widgets/error_boundary.dart';

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

  // Initialize Deep Linking
  await container.read(deepLinkServiceProvider).initialize();

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

    ref.listen<DeepLinkEvent?>(deepLinkProvider, (previous, next) {
      if (next != null && context.mounted) {
        if (next.path == '/auth') {
          final token = next.params['token'];
          final error = next.params['error'];
          if (token != null) {
            // Store token and update providers
            final prefs = ref.read(sharedPreferencesProvider);
            prefs.setString(AppConstants.keyAuthToken, token);
            ref.read(authTokenProvider.notifier).update(token);
            
            // Try fetching user profile
            try {
              final dio = ref.read(dioProvider);
              dio.get('/auth/me').then((response) {
                final user = response.data['user'] as Map<String, dynamic>;
                prefs.setString(AppConstants.keyUserId, user['id'] as String);
                prefs.setString(AppConstants.keyUserEmail, user['email'] as String);
                if (user['displayName'] != null) {
                  prefs.setString(AppConstants.keyUserDisplayName, user['displayName'] as String);
                }
              }).catchError((_) {});
            } catch (_) {}

            router.go(Routes.chatList);
          } else if (error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Auth Error: $error')),
            );
            router.go(Routes.login);
          }
        } else if (next.path == '/thread') {
          final id = next.params['id'];
          if (id != null) {
            router.push('/chats/$id');
          }
        } else if (next.path == '/settings') {
          router.push(Routes.settings);
        } else if (next.path == '/chats') {
          router.go(Routes.chatList);
        } else {
          router.go(Routes.chatList);
        }
      }
    });

    return ErrorBoundary(
      child: MaterialApp.router(
        title: AppConstants.appName,
        scaffoldMessengerKey: SnackBarService.scaffoldMessengerKey,
        theme: QubixTheme.dark, // We will extend this to support light theme if necessary
        darkTheme: QubixTheme.dark,
        themeMode: themeState.themeMode,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

