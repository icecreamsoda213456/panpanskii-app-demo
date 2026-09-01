import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/supabase/supabase.dart';
import 'features/bible/data/daily_bible_notification_service.dart';
import 'features/dates/data/couple_date_notification_service.dart';
import 'features/widget_notes/data/widget_note_home_widget_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // A background push runs in its own isolate where main() never executed, so
  // Supabase has to be initialized again before the widget sync can read the
  // note and hand the widget a fresh download URL.
  try {
    await Supabase.initialize(
      url: 'https://pjzlsllqypoxlfueaiji.supabase.co',
      publishableKey: 'sb_publishable_rOc75h74rzwPJW9QI5uPKA_ibUe6hBB',
    );
  } catch (_) {
    // Already initialized in this isolate; safe to continue.
  }
  if (message.data['type'] == 'widget_note') {
    // The partner sent a new note: hand the widget a fresh URL so it can pull
    // the drawing over WiFi/data even with the app closed.
    try {
      // In this fresh background isolate the Supabase session stored on disk
      // has to be hydrated before the sync can read the partner's note.
      await supabase.auth.recoverSession();
    } catch (_) {
      // No saved session; syncLatest will skip and log.
    }
    await WidgetNoteHomeWidgetService.syncLatest();
  }
  await CoupleDateNotificationService.handleRemotePushData(message.data);
}

Future<bool> _handleForegroundFirebaseMessage(RemoteMessage message) {
  // A fresh widget note arrived: refresh the home-screen widget in the
  // background while the couple-date handler does its usual work.
  if (message.data['type'] == 'widget_note') {
    WidgetNoteHomeWidgetService.syncLatest();
  }
  return CoupleDateNotificationService.handleRemotePushData(message.data);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  await Supabase.initialize(
    url: 'https://pjzlsllqypoxlfueaiji.supabase.co',
    publishableKey: 'sb_publishable_rOc75h74rzwPJW9QI5uPKA_ibUe6hBB',
  );

  final user = supabase.auth.currentUser;
  if (kDebugMode) {
    debugPrint('Supabase current user: $user');
    debugPrint('User ID: ${user?.id}');
    debugPrint('User email: ${user?.email}');
    debugPrint('Is authenticated: ${user != null}');
  }

  await DailyBibleNotificationService.initializeAndSchedule();
  await PushNotificationService.initialize(
    onForegroundMessage: _handleForegroundFirebaseMessage,
  );

  // Show the partner's newest note on the home-screen widget, even when the
  // push arrived while the app was closed. Safe no-op when signed out.
  await WidgetNoteHomeWidgetService.syncLatest();

  runApp(const PanpanskiiApp());
}
