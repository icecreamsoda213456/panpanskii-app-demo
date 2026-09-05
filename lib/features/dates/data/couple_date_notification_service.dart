import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

import 'couple_date_store.dart';

class CoupleDateReminderAccess {
  const CoupleDateReminderAccess({
    required this.notificationsAllowed,
    required this.exactTimingAllowed,
    required this.fullScreenAllowed,
  });

  final bool notificationsAllowed;
  final bool exactTimingAllowed;
  final bool fullScreenAllowed;

  bool get prominentAlertsReady =>
      notificationsAllowed && exactTimingAllowed && fullScreenAllowed;
}

class CoupleDateNotificationService {
  static const remoteSyncType = 'couple_date_alarm_sync';
  static const _remoteUpsertAction = 'upsert';
  static const _remoteCancelAction = 'cancel';
  static const _remoteSyncVersionKeyPrefix =
      'panpanskii_couple_date_sync_version_';

  // Android channel alert settings are immutable after first creation, so a
  // new channel id reliably enables sound and vibration for existing installs.
  static const _channelId = 'couple_date_alarm_reminders_v4';
  static const _channelName = 'Date alarms';
  static const _channelDescription =
      'Alarm-style alerts with sound and strong vibration for date plans.';
  static const _notificationIdFloor = 100000000;
  static const _notificationIdSpan = 900000000;
  static const _testNotificationId = _notificationIdFloor - 1;
  static const _scheduledTestDelay = Duration(seconds: 8);
  static const _alarmTimeoutMilliseconds = 60000;
  static const _testAlarmTimeoutMilliseconds = 15000;
  static const _alarmSound =
      UriAndroidNotificationSound('content://settings/system/alarm_alert');

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static final Int64List _vibrationPattern = Int64List.fromList(
    const <int>[
      0,
      900,
      250,
      900,
      250,
      1400,
      450,
      900,
      250,
      900,
      250,
      1400,
    ],
  );
  // Android Notification.FLAG_INSISTENT repeats the alarm sound until the
  // alert is opened, dismissed, or reaches its timeout.
  static final Int32List _alarmFlags = Int32List.fromList(const <int>[4]);

  static bool _isInitialized = false;

  static Future<void> syncUpcomingPlans() async {
    try {
      final plans = await CoupleDateStore().loadUpcomingPlans();
      await syncPlans(plans);
    } catch (_) {
      // A failed sync can retry on the next login, Realtime event, or screen load.
    }
  }

  static Future<void> syncPlans(List<CoupleDatePlan> plans) async {
    try {
      await _initialize();
      final now = DateTime.now();
      final desired = <int, CoupleDatePlan>{};

      for (final plan in plans) {
        // RLS already applies this rule. Keep the same guard on-device so a
        // personal plan can never be scheduled for the other account even if
        // a malformed or stale row reaches the client.
        if (!plan.isShared && !plan.isMine) {
          continue;
        }
        final reminderAt = plan.reminderAt;
        if (reminderAt == null || !reminderAt.isAfter(now)) {
          continue;
        }
        desired[_notificationId(plan.id)] = plan;
      }

      final pending = await _notifications.pendingNotificationRequests();
      for (final request in pending) {
        if (_isDateNotificationId(request.id) &&
            !desired.containsKey(request.id)) {
          await _notifications.cancel(id: request.id);
        }
      }

      for (final entry in desired.entries) {
        await _schedule(entry.key, entry.value);
      }
    } catch (_) {
      // Scheduling support differs by platform and should not block the feature.
    }
  }

  static Future<void> cancelPlan(String planId) async {
    try {
      await _initialize();
      await _notifications.cancel(id: _notificationId(planId));
    } catch (_) {
      // Cancellation can safely retry during the next full sync.
    }
  }

  static Future<void> schedulePlan(CoupleDatePlan plan) async {
    await _initialize();
    final reminderAt = plan.reminderAt;
    if (reminderAt == null) {
      await _notifications.cancel(id: _notificationId(plan.id));
      return;
    }
    if (!reminderAt.isAfter(DateTime.now())) {
      throw StateError(
        'The selected reminder time has already passed. Choose a later plan or a shorter reminder.',
      );
    }

    final id = _notificationId(plan.id);
    await _schedule(id, plan);
    final pending = await _notifications.pendingNotificationRequests();
    if (!pending.any((request) => request.id == id)) {
      throw StateError(
        'Android did not keep this date alarm. Check Notifications and Alarms & reminders access, then save again.',
      );
    }
  }

  static Future<bool> requestNotificationPermission() async {
    await _initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return true;
    }

    var allowed = await android.areNotificationsEnabled() ?? true;
    if (!allowed) {
      allowed = await android.requestNotificationsPermission() ?? false;
    }
    return allowed;
  }

  static Future<CoupleDateReminderAccess>
      requestProminentReminderAccess() async {
    await _initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) {
      return const CoupleDateReminderAccess(
        notificationsAllowed: true,
        exactTimingAllowed: true,
        fullScreenAllowed: true,
      );
    }

    final notificationsAllowed = await requestNotificationPermission();
    if (!notificationsAllowed) {
      return const CoupleDateReminderAccess(
        notificationsAllowed: false,
        exactTimingAllowed: false,
        fullScreenAllowed: false,
      );
    }

    var exactTimingAllowed =
        await android.canScheduleExactNotifications() ?? true;
    if (!exactTimingAllowed) {
      exactTimingAllowed =
          await android.requestExactAlarmsPermission() ?? false;
    }

    final fullScreenAllowed =
        await android.requestFullScreenIntentPermission() ?? false;
    return CoupleDateReminderAccess(
      notificationsAllowed: true,
      exactTimingAllowed: exactTimingAllowed,
      fullScreenAllowed: fullScreenAllowed,
    );
  }

  static Future<void> showTestReminder() async {
    await _initialize();
    const title = 'Our Dates reminder test';
    const body =
        'Your prominent calendar alert is working. Future plans will ring and vibrate at their reminder time.';
    await _showWithIconFallback(
      id: _testNotificationId,
      title: title,
      body: body,
      summary: 'Prominent reminder test',
      payload: 'couple-date:test',
      timeoutAfter: _testAlarmTimeoutMilliseconds,
    );
  }

  static Future<void> scheduleTestReminder() async {
    await _initialize();
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExactly =
        await android?.canScheduleExactNotifications() ?? false;
    if (!canScheduleExactly) {
      throw StateError(
        'Exact alarms are off. Enable Alarms & reminders, then run the test again.',
      );
    }

    const title = 'Our Dates alarm test';
    const body =
        'Your scheduled date alarm is working with sound and vibration.';
    final scheduledDate =
        timezone.TZDateTime.now(timezone.local).add(_scheduledTestDelay);

    Future<void> schedule({required bool useCustomIcon}) {
      return _notifications.zonedSchedule(
        id: _testNotificationId,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(
          title: title,
          body: body,
          summary: 'Scheduled reminder test',
          useCustomIcon: useCustomIcon,
          timeoutAfter: _testAlarmTimeoutMilliseconds,
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'couple-date:test',
      );
    }

    await _notifications.cancel(id: _testNotificationId);
    try {
      await schedule(useCustomIcon: true);
    } on PlatformException catch (error) {
      if (error.code != 'invalid_icon') {
        rethrow;
      }
      await schedule(useCustomIcon: false);
    }

    final pending = await _notifications.pendingNotificationRequests();
    if (!pending.any((request) => request.id == _testNotificationId)) {
      throw StateError('Android did not keep the scheduled alarm test.');
    }
  }

  static Future<bool> handleRemotePushData(
    Map<String, dynamic> data,
  ) async {
    if (data['type']?.toString() != remoteSyncType) {
      return false;
    }

    final planId = data['plan_id']?.toString().trim() ?? '';
    if (planId.isEmpty) {
      return true;
    }

    final syncVersion =
        DateTime.tryParse(data['sync_version']?.toString() ?? '');
    if (syncVersion == null ||
        !await _acceptRemoteSyncVersion(planId, syncVersion)) {
      return true;
    }

    final action = data['action']?.toString();
    if (action == _remoteCancelAction) {
      await cancelPlan(planId);
      return true;
    }

    // Only authoritative shared-plan payloads may create an alarm on the
    // partner phone. Anything else removes a possibly stale local alarm.
    if (action != _remoteUpsertAction ||
        data['visibility']?.toString() != CoupleDateVisibility.shared.name) {
      await cancelPlan(planId);
      return true;
    }

    final startsAt = DateTime.tryParse(data['starts_at']?.toString() ?? '');
    final reminderText = data['reminder_minutes']?.toString() ?? '';
    final reminderMinutes = int.tryParse(reminderText);
    if (startsAt == null ||
        reminderMinutes == null ||
        !const {0, 10, 60, 1440}.contains(reminderMinutes)) {
      await cancelPlan(planId);
      return true;
    }

    final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '') ??
        DateTime.now().toUtc();
    final updatedAt =
        DateTime.tryParse(data['updated_at']?.toString() ?? '') ?? createdAt;
    final plan = CoupleDatePlan.fromJson({
      'id': planId,
      'user_id': data['user_id']?.toString() ?? '',
      'username': data['username']?.toString() ?? 'your person',
      'mascot': data['mascot']?.toString() ?? 'panda',
      'title': data['title']?.toString() ?? 'Our plan',
      // Notes stay in Supabase and are loaded under RLS when the app opens.
      // Omitting them keeps the high-priority FCM data payload compact.
      'notes': '',
      'category': data['category']?.toString() ?? 'other',
      'visibility': CoupleDateVisibility.shared.name,
      'starts_at': startsAt.toUtc().toIso8601String(),
      'reminder_minutes': reminderMinutes,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    });

    final reminderAt = plan.reminderAt;
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      await cancelPlan(planId);
      return true;
    }

    try {
      await schedulePlan(plan);
    } catch (_) {
      // A normal foreground/app-start sync will retry when the app next opens.
    }
    return true;
  }

  static Future<bool> _acceptRemoteSyncVersion(
    String planId,
    DateTime incomingVersion,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final key = '$_remoteSyncVersionKeyPrefix$planId';
    final savedVersion = DateTime.tryParse(preferences.getString(key) ?? '');
    if (savedVersion != null && !incomingVersion.isAfter(savedVersion)) {
      return false;
    }
    await preferences.setString(key, incomingVersion.toUtc().toIso8601String());
    return true;
  }

  static Future<void> _schedule(int id, CoupleDatePlan plan) async {
    final reminderAt = plan.reminderAt;
    if (reminderAt == null || !reminderAt.isAfter(DateTime.now())) {
      return;
    }

    final title = 'Our Dates: ${plan.title}';
    final timing = plan.isShared
        ? '${plan.category.label} time with your person at ${_formatTime(plan.startsAt)}.'
        : 'Your personal plan starts at ${_formatTime(plan.startsAt)}.';
    final body =
        plan.notes.trim().isEmpty ? timing : '$timing\n\n${plan.notes.trim()}';
    final android = _notifications.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final canScheduleExactly =
        await android?.canScheduleExactNotifications() ?? false;
    final preferredMode = canScheduleExactly
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    await _notifications.cancel(id: id);
    try {
      await _zonedSchedule(
        id: id,
        plan: plan,
        title: title,
        body: body,
        mode: preferredMode,
      );
    } catch (_) {
      if (preferredMode != AndroidScheduleMode.exactAllowWhileIdle) {
        rethrow;
      }
      await _zonedSchedule(
        id: id,
        plan: plan,
        title: title,
        body: body,
        mode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  static Future<void> _zonedSchedule({
    required int id,
    required CoupleDatePlan plan,
    required String title,
    required String body,
    required AndroidScheduleMode mode,
  }) async {
    final summary = plan.isShared ? 'Shared date plan' : 'Personal date plan';
    final scheduledDate = timezone.TZDateTime.from(
      plan.reminderAt!,
      timezone.local,
    );

    Future<void> schedule({required bool useCustomIcon}) {
      return _notifications.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(
          title: title,
          body: body,
          summary: summary,
          useCustomIcon: useCustomIcon,
        ),
        androidScheduleMode: mode,
        payload: 'couple-date:${plan.id}',
      );
    }

    try {
      await schedule(useCustomIcon: true);
    } on PlatformException catch (error) {
      if (error.code != 'invalid_icon') {
        rethrow;
      }
      await schedule(useCustomIcon: false);
    }
  }

  static Future<void> _showWithIconFallback({
    required int id,
    required String title,
    required String body,
    required String summary,
    required String payload,
    required int timeoutAfter,
  }) async {
    Future<void> show({required bool useCustomIcon}) {
      return _notifications.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: _notificationDetails(
          title: title,
          body: body,
          summary: summary,
          useCustomIcon: useCustomIcon,
          timeoutAfter: timeoutAfter,
        ),
        payload: payload,
      );
    }

    try {
      await show(useCustomIcon: true);
    } on PlatformException catch (error) {
      if (error.code != 'invalid_icon') {
        rethrow;
      }
      await show(useCustomIcon: false);
    }
  }

  static NotificationDetails _notificationDetails({
    required String title,
    required String body,
    required String summary,
    bool useCustomIcon = true,
    int timeoutAfter = _alarmTimeoutMilliseconds,
  }) {
    return NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        icon: useCustomIcon ? 'ic_stat_panpanskii_reminder' : null,
        importance: Importance.max,
        priority: Priority.max,
        styleInformation: BigTextStyleInformation(
          body,
          contentTitle: title,
          summaryText: summary,
        ),
        playSound: true,
        sound: _alarmSound,
        audioAttributesUsage: AudioAttributesUsage.alarm,
        enableVibration: true,
        vibrationPattern: _vibrationPattern,
        autoCancel: true,
        ongoing: false,
        onlyAlertOnce: false,
        enableLights: true,
        ticker: title,
        visibility: NotificationVisibility.private,
        timeoutAfter: timeoutAfter,
        category: AndroidNotificationCategory.alarm,
        fullScreenIntent: true,
        additionalFlags: _alarmFlags,
        subText: 'Our Dates',
      ),
      iOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
      macOS: const DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      ),
    );
  }

  static Future<void> _initialize() async {
    if (_isInitialized) {
      return;
    }

    timezone_data.initializeTimeZones();
    await _setLocalTimezone();

    const settings = InitializationSettings(
      // The launcher icon is guaranteed to exist, so permission setup and plan
      // saving cannot fail before the custom reminder icon is resolved.
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      macOS: DarwinInitializationSettings(),
    );
    await _notifications.initialize(settings: settings);
    await _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            _channelId,
            _channelName,
            description: _channelDescription,
            importance: Importance.max,
            playSound: true,
            sound: _alarmSound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern: _vibrationPattern,
            enableLights: true,
          ),
        );
    _isInitialized = true;
  }

  static Future<void> _setLocalTimezone() async {
    var locationName = 'Asia/Manila';
    try {
      locationName = (await FlutterTimezone.getLocalTimezone()).identifier;
    } catch (_) {
      // Asia/Manila matches the app's intended default timezone.
    }

    try {
      timezone.setLocalLocation(timezone.getLocation(locationName));
    } catch (_) {
      timezone.setLocalLocation(timezone.getLocation('Asia/Manila'));
    }
  }

  static int _notificationId(String planId) {
    var hash = 0x811c9dc5;
    for (final codeUnit in planId.codeUnits) {
      hash ^= codeUnit;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return _notificationIdFloor + (hash % _notificationIdSpan);
  }

  static bool _isDateNotificationId(int id) {
    return id >= _notificationIdFloor &&
        id < _notificationIdFloor + _notificationIdSpan;
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour >= 12 ? 'PM' : 'AM'}';
  }
}
