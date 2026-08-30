import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

import '../../../core/supabase/supabase.dart';
import 'widget_note_store.dart';

/// Keeps the Android home-screen widget in sync with the partner's latest
/// note. Safe to call at any time: every failure is swallowed so the app
/// itself never breaks because the widget could not refresh.
class WidgetNoteHomeWidgetService {
  const WidgetNoteHomeWidgetService._();

  static const String _androidProviderName = 'NoteWidgetProvider';
  static const String _qualifiedAndroidName =
      'com.example.panpanskii_app.NoteWidgetProvider';

  static const String imageUrlKey = 'widget_note_image_url';
  static const String usernameKey = 'widget_note_username';
  static const String mascotKey = 'widget_note_mascot';
  static const String captionKey = 'widget_note_caption';
  static const String updatedAtKey = 'widget_note_updated_at';

  /// Fetches the partner's newest note and hands the widget a download URL.
  ///
  /// The PNG is no longer downloaded here: the Android widget itself fetches
  /// the image over WiFi/mobile data (see `NoteWidgetProvider.kt`), so it can
  /// refresh even while the app is closed. Every failure is swallowed so the
  /// app itself never breaks because the widget could not refresh.
  static Future<void> syncLatest() async {
    try {
      if (supabase.auth.currentUser == null) {
        return;
      }

      final store = WidgetNoteStore();
      final note = await store.fetchLatestPartnerNote();

      if (note == null || note.storagePath.isEmpty) {
        await HomeWidget.saveWidgetData<String>(imageUrlKey, null);
        await HomeWidget.saveWidgetData<String>(usernameKey, null);
        await HomeWidget.saveWidgetData<String>(captionKey, null);
        await _updateWidget();
        return;
      }

      final url = await store.createNoteImageUrl(note.storagePath);
      if (url == null || url.isEmpty) {
        return;
      }

      await HomeWidget.saveWidgetData<String>(imageUrlKey, url);
      await HomeWidget.saveWidgetData<String>(usernameKey, note.username);
      await HomeWidget.saveWidgetData<String>(mascotKey, note.mascot);
      await HomeWidget.saveWidgetData<String>(captionKey, note.caption);
      await HomeWidget.saveWidgetData<String>(
        updatedAtKey,
        note.createdAt.toIso8601String(),
      );
      await _updateWidget();
    } catch (error) {
      debugPrint('WidgetNoteHomeWidgetService.syncLatest failed: $error');
    }
  }

  static Future<void> _updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: _androidProviderName,
        androidName: _androidProviderName,
        qualifiedAndroidName: _qualifiedAndroidName,
      );
    } catch (error) {
      debugPrint('WidgetNoteHomeWidgetService.updateWidget failed: $error');
    }
  }
}
