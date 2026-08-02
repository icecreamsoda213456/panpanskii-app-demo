import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/notifications/push_notification_service.dart';
import 'core/supabase/supabase.dart';
import 'features/bible/data/daily_bible_notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
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
  debugPrint('Supabase current user: $user');
  debugPrint('User ID: ${user?.id}');
  debugPrint('User email: ${user?.email}');
  debugPrint('Is authenticated: ${user != null}');

  await DailyBibleNotificationService.initializeAndSchedule();
  await PushNotificationService.initialize();

  runApp(const PanpanskiiApp());
}
