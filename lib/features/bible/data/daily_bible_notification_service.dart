import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

class DailyBibleNotificationService {
  static const _legacyNotificationId = 600;
  static const _dailyReminderBaseId = 610;
  static const _channelId = 'daily_bible_verse';
  static const _channelName = 'Daily Bible Verse';
  static const _channelDescription =
      'Hourly Panpanskii reminders from 6 AM to 9 PM.';
  static const _wisdomNotificationId = 601;
  static const _wisdomChannelId = 'daily_wisdom';
  static const _wisdomChannelName = 'Daily Wisdom';
  static const _wisdomChannelDescription = 'Daily encouragement reminder.';
  static const _sendLoveNotificationId = 700;
  static const _sendLoveChannelId = 'send_love';
  static const _sendLoveChannelName = 'Send Love';
  static const _sendLoveChannelDescription =
      'Notifications for sent love letters.';
  static const _realtimeNotificationBaseId = 800;
  static const _realtimeChannelId = 'realtime_updates';
  static const _realtimeChannelName = 'Realtime Updates';
  static const _realtimeChannelDescription =
      'Notifications for chat, love, thoughts, and journal updates.';
  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  static Future<void> initializeAndSchedule() async {
    try {
      await _initialize();
      await _requestPermissions();
      await scheduleDailyReminder();
      await scheduleDailyWisdomReminder();
    } catch (_) {
      // Notifications should never block the app from opening.
    }
  }

  static Future<void> scheduleDailyWisdomReminder() async {
    try {
      await _initialize();
      await _notifications.zonedSchedule(
        id: _wisdomNotificationId,
        title: 'Today\'s wisdom is ready',
        body: 'Open Communal Wisdom for a little encouragement.',
        scheduledDate: _nextTime(hour: 6, minute: 5),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _wisdomChannelId,
            _wisdomChannelName,
            channelDescription: _wisdomChannelDescription,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexact,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    } catch (_) {
      // Daily reminders should never prevent the app from opening.
    }
  }

  static Future<void> scheduleDailyReminder() async {
    try {
      await _initialize();
      await _notifications.cancel(id: _legacyNotificationId);

      for (var hour = 6; hour <= 21; hour++) {
        final copy = hourlyReminders[hour - 6];
        await _notifications.zonedSchedule(
          id: _dailyReminderBaseId + hour - 6,
          title: copy.title,
          body: copy.body,
          scheduledDate: _nextTime(hour: hour),
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              _channelId,
              _channelName,
              channelDescription: _channelDescription,
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
            macOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: AndroidScheduleMode.inexact,
          matchDateTimeComponents: DateTimeComponents.time,
        );
      }
    } catch (_) {
      // Some desktop/web targets do not support repeating scheduled notifications.
    }
  }

  static Future<void> showSendLoveNotification({
    required String username,
    required bool hasAttachment,
  }) async {
    try {
      await _initialize();
      await _notifications.show(
        id: _sendLoveNotificationId,
        title: 'Love letter sent',
        body: hasAttachment
            ? '$username sent love with a photo attached.'
            : '$username sent a new love letter.',
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _sendLoveChannelId,
            _sendLoveChannelName,
            channelDescription: _sendLoveChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Local notification support can differ by platform and permission state.
    }
  }

  static Future<void> showRealtimeNotification({
    required String title,
    required String body,
    int seed = 0,
  }) async {
    try {
      await _initialize();
      await _notifications.show(
        id: _realtimeNotificationBaseId + (seed.abs() % 100),
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _realtimeChannelId,
            _realtimeChannelName,
            channelDescription: _realtimeChannelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } catch (_) {
      // Local notification support can differ by platform and permission state.
    }
  }

  static Future<void> _initialize() async {
    if (_isInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    await _setLocalTimezone();

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(
      settings: initializationSettings,
    );
    _isInitialized = true;
  }

  static Future<void> _requestPermissions() async {
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _notifications
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await _notifications
        .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<void> _setLocalTimezone() async {
    var locationName = 'Asia/Manila';
    try {
      final localTimezone = await FlutterTimezone.getLocalTimezone();
      locationName = localTimezone.identifier;
    } catch (_) {
      // Asia/Manila keeps the intended 6 AM behavior for the user's timezone.
    }

    try {
      timezone.setLocalLocation(timezone.getLocation(locationName));
    } catch (_) {
      timezone.setLocalLocation(timezone.getLocation('Asia/Singapore'));
    }
  }

  static timezone.TZDateTime _nextTime({required int hour, int minute = 0}) {
    final now = timezone.TZDateTime.now(timezone.local);
    var scheduled = timezone.TZDateTime(
      timezone.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

class DailyReminder {
  const DailyReminder({
    required this.hour,
    required this.title,
    required this.body,
  });

  final int hour;
  final String title;
  final String body;
}

const hourlyReminders = <DailyReminder>[
  DailyReminder(
    hour: 6,
    title: 'Plan your day',
    body: 'Choose your three most important tasks before the day gets busy.',
  ),
  DailyReminder(
    hour: 7,
    title: 'Start with intention',
    body: 'Review your schedule and give your first task your full attention.',
  ),
  DailyReminder(
    hour: 8,
    title: 'Focus block',
    body: 'Silence distractions for a while and finish one meaningful task.',
  ),
  DailyReminder(
    hour: 9,
    title: 'Quick progress check',
    body: 'Notice what is moving forward and adjust your priorities if needed.',
  ),
  DailyReminder(
    hour: 10,
    title: 'Take a short break',
    body: 'Stand up, drink water, and rest your eyes before returning to work.',
  ),
  DailyReminder(
    hour: 11,
    title: 'Check your pace',
    body: 'Work steadily, but do not rush a task that needs careful attention.',
  ),
  DailyReminder(
    hour: 12,
    title: 'Lunch break',
    body:
        'Step away from your screen and give yourself a real break if you can.',
  ),
  DailyReminder(
    hour: 13,
    title: 'Afternoon reset',
    body:
        'Choose one clear next step and begin again without carrying the morning.',
  ),
  DailyReminder(
    hour: 14,
    title: 'Protect your focus',
    body:
        'Group small tasks together so your attention can stay where it matters.',
  ),
  DailyReminder(
    hour: 15,
    title: 'Posture check',
    body:
        'Relax your shoulders, stretch your neck, and take a few slow breaths.',
  ),
  DailyReminder(
    hour: 16,
    title: 'Finish one thing',
    body: 'Pick one task to complete before starting another new one.',
  ),
  DailyReminder(
    hour: 17,
    title: 'Review your wins',
    body:
        'Take note of what you completed today, even if the list feels small.',
  ),
  DailyReminder(
    hour: 18,
    title: 'Workday transition',
    body:
        'Write down unfinished tasks so you do not have to keep carrying them.',
  ),
  DailyReminder(
    hour: 19,
    title: 'Protect your evening',
    body: 'Give yourself permission to be present outside of work for a while.',
  ),
  DailyReminder(
    hour: 20,
    title: 'Prepare tomorrow',
    body: 'Set out one thing that will make tomorrow morning easier.',
  ),
  DailyReminder(
    hour: 21,
    title: 'Close the day',
    body: 'Put your phone down when you can and make room for proper rest.',
  ),
];
