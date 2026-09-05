import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/auth/data/local_account_store.dart';
import '../../features/bible/data/daily_bible_notification_service.dart';
import '../supabase/supabase.dart';

typedef ForegroundPushHandler = Future<bool> Function(RemoteMessage message);

class PushNotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> initialize({
    ForegroundPushHandler? onForegroundMessage,
  }) async {
    try {
      await _messaging.requestPermission(alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessage.listen((message) async {
        try {
          if (onForegroundMessage != null &&
              await onForegroundMessage(message)) {
            return;
          }
        } catch (_) {
          // Fall through to the normal visible notification.
        }
        _handleForegroundMessage(message);
      });
    } catch (_) {
      // Push support can fail on emulators/devices without Google Play services.
    }
  }

  static Future<void> registerDevice(LocalAccount account) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return;
      }

      await _saveToken(
        userId: user.id,
        token: token,
        account: account,
      );

      _messaging.onTokenRefresh.listen((newToken) {
        _saveToken(userId: user.id, token: newToken, account: account);
      });
    } catch (_) {
      // Token registration should not block login.
    }
  }

  static Future<void> sendPush({
    required String type,
    required String title,
    required String body,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        return;
      }

      final response = await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'type': type,
          'title': title,
          'body': body,
        },
      );
      if (kDebugMode) {
        debugPrint('PUSH DEBUG sendPush OK response=${response.data}');
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('PUSH DEBUG sendPush failed: $error');
      }
    }
  }

  static Future<bool> syncCoupleDateAlarm({
    required String planId,
    required String action,
  }) async {
    try {
      if (supabase.auth.currentUser == null || planId.trim().isEmpty) {
        return false;
      }
      await supabase.functions.invoke(
        'send-push-notification',
        body: {
          'type': 'couple_date_alarm_sync',
          'planId': planId,
          'action': action,
        },
      );
      return true;
    } catch (_) {
      // Realtime and app-start synchronization remain a safe retry path.
      return false;
    }
  }

  static Future<void> _saveToken({
    required String userId,
    required String token,
    required LocalAccount account,
  }) async {
    await supabase.from('push_tokens').upsert(
      {
        'user_id': userId,
        'token': token,
        'platform': _platform,
        'username': account.username,
        'mascot': account.mascot.name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'token',
    );
  }

  static void _handleForegroundMessage(RemoteMessage message) {
    final title = message.notification?.title ?? message.data['title'];
    final body = message.notification?.body ?? message.data['body'];
    if (title == null || body == null) {
      return;
    }

    DailyBibleNotificationService.showRealtimeNotification(
      title: title.toString(),
      body: body.toString(),
      seed: message.messageId?.hashCode ?? title.hashCode,
    );
  }

  static String get _platform {
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}
