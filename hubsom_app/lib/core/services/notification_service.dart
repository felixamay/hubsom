import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'firebase_bootstrap.dart';

class NotificationService {
  NotificationService();

  final _local = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (kIsWeb) {
      // Web uses browser Notification API / FCM web when Firebase is enabled.
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _local.initialize(
      const InitializationSettings(android: android, iOS: ios),
    );
    _ready = true;

    if (FirebaseBootstrap.ready) {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission();
      FirebaseMessaging.onMessage.listen(_onForeground);
    }
  }

  Future<void> _onForeground(RemoteMessage message) async {
    if (!_ready) return;
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      n.hashCode,
      n.title,
      n.body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'hubsom',
          'Hubsom',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }

  Future<void> showLocal({
    required String title,
    required String body,
  }) async {
    if (!_ready) return;
    await _local.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails('hubsom', 'Hubsom'),
        iOS: DarwinNotificationDetails(),
      ),
    );
  }
}
