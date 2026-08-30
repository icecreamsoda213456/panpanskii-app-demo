import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/notifications/push_notification_service.dart';
import '../../../core/supabase/supabase.dart';
import '../../auth/data/local_account_store.dart';

/// A hand-drawn note that is displayed on the partner's home-screen widget.
class WidgetNote {
  const WidgetNote({
    required this.id,
    required this.userId,
    required this.username,
    required this.mascot,
    required this.storagePath,
    this.caption,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String username;
  final String mascot;
  final String storagePath;
  final String? caption;
  final DateTime createdAt;

  bool get isMine => supabase.auth.currentUser?.id == userId;

  static WidgetNote fromJson(Map<String, dynamic> json) {
    return WidgetNote(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'panpanskii',
      mascot: json['mascot'] as String? ?? 'panda',
      storagePath: json['storage_path'] as String? ?? '',
      caption: json['caption'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now().toUtc(),
    );
  }
}

/// Sends widget notes and reads the partner's latest note.
///
/// Like the rest of Panpanskii this is a fixed two-account app: the partner is
/// simply every row whose `user_id` differs from the signed-in account.
class WidgetNoteStore {
  static const String bucket = 'widget-notes';

  /// Uploads the drawing, stores the row, and nudges the partner's phone.
  Future<WidgetNote> sendNote({
    required LocalAccount account,
    required Uint8List pngBytes,
    String? caption,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      throw Exception('Kailangang naka-sign in ka bago magpadala ng note.');
    }

    final cleanCaption = caption?.trim() ?? '';
    final path = '${user.id}/${DateTime.now().microsecondsSinceEpoch}.png';

    try {
      await supabase.storage.from(bucket).uploadBinary(
            path,
            pngBytes,
            fileOptions: const FileOptions(
              contentType: 'image/png',
              upsert: false,
            ),
          );
    } on StorageException catch (error) {
      throw Exception('Hindi ma-upload ang drawing. ${error.message}');
    }

    try {
      final row = await supabase
          .from('widget_notes')
          .insert({
            'user_id': user.id,
            'username': account.username,
            'mascot': account.mascot.name,
            'storage_path': path,
            'caption': cleanCaption.isEmpty ? null : cleanCaption,
          })
          .select('id, user_id, username, mascot, storage_path, caption, created_at')
          .single();

      await PushNotificationService.sendPush(
        type: 'widget_note',
        title: 'May bagong widget note 🐼',
        body: '${account.username} left a drawing on your home screen.',
      );

      return WidgetNote.fromJson(row);
    } on PostgrestException catch (error) {
      // Best effort cleanup so orphaned uploads do not pile up.
      try {
        await supabase.storage.from(bucket).remove([path]);
      } catch (_) {
        // Ignore cleanup failures; the error below matters more.
      }
      throw Exception(
        'Hindi maisulat sa widget_notes table. Check RLS policies. '
        '${error.message}',
      );
    }
  }

  /// The newest note from the partner, or null when there is none yet.
  Future<WidgetNote?> fetchLatestPartnerNote() async {
    final user = supabase.auth.currentUser;
    if (user == null) {
      return null;
    }

    try {
      final rows = await supabase
          .from('widget_notes')
          .select('id, user_id, username, mascot, storage_path, caption, created_at')
          .neq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(1);
      if (rows.isEmpty) {
        return null;
      }
      return WidgetNote.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (_) {
      return null;
    }
  }

  /// Downloads the drawing bytes for a stored note.
  Future<Uint8List> downloadNotePng(String storagePath) async {
    return supabase.storage.from(bucket).download(storagePath);
  }

  /// A permanent public URL for a stored note PNG. The bucket is public
  /// (see supabase_widget_notes.sql), so this never expires — safer for the
  /// widget than signed URLs which die after at most one week.
  static String publicNoteUrl(String storagePath) {
    return supabase.storage.from(bucket).getPublicUrl(storagePath);
  }

  /// A temporary URL the Android widget can download the PNG from directly,
  /// without the Flutter app running. Supabase signed URLs live at most one
  /// week, so the app refreshes it on every launch and foreground sync; the
  /// widget keeps its cached copy whenever the URL has expired.
  Future<String?> createNoteImageUrl(String storagePath) async {
    try {
      return publicNoteUrl(storagePath);
    } catch (_) {
      return null;
    }
  }
}
