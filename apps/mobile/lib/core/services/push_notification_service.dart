import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/push_repository.dart';
import 'deep_link_service.dart';

// Top-level function for background messages
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // We don't have access to Riverpod easily here, so we just log or store in SharedPreferences if needed.
  // ignore: avoid_print
  print('Handling a background message: ${message.messageId}');
}

final pushNotificationServiceProvider = Provider<PushNotificationService>((ref) {
  return PushNotificationService(ref);
});

class PushNotificationService {
  final Ref _ref;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  PushNotificationService(this._ref);

  Future<void> initialize() async {
    // 1. Request permissions (especially for iOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize local notifications for foreground display
    const androidChannel = AndroidNotificationChannel(
      'qubix_agent_responses',
      'Agent Responses',
      description: 'Notifications when your AI agents respond',
      importance: Importance.high,
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _localNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (details) {
        // Foreground/Background local notification tap
        final payload = details.payload;
        if (payload != null) {
          final data = jsonDecode(payload);
          _navigateToThread(data['threadId']);
        }
      },
    );

    // 3. Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 4. Handle foreground FCM messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        _localNotificationsPlugin.show(
          id: message.hashCode,
          title: message.notification?.title,
          body: message.notification?.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              androidChannel.id,
              androidChannel.name,
              channelDescription: androidChannel.description,
              icon: '@mipmap/ic_launcher',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // 5. Handle tapping FCM notification when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToThread(message.data['threadId']);
    });

    // 6. Register token with backend
    try {
      final token = await _firebaseMessaging.getToken();
      if (token != null) {
        await _ref.read(pushRepositoryProvider).registerPushToken(token);
      }

      _firebaseMessaging.onTokenRefresh.listen((newToken) {
        _ref.read(pushRepositoryProvider).registerPushToken(newToken);
      });
    } catch (e) {
      // Ignore
    }
  }

  Future<void> handleInitialMessage() async {
    // 7. Handle app opened from terminated state via notification
    final RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _navigateToThread(initialMessage.data['threadId']);
    }
  }

  void _navigateToThread(String? threadId) {
    if (threadId != null) {
      _ref.read(deepLinkServiceProvider).emit(DeepLinkEvent(path: '/thread', params: {'id': threadId}));
    }
  }
}
