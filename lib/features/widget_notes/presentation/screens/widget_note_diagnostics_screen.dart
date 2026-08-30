import 'dart:io';

import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';

import '../../../../core/supabase/supabase.dart';
import '../../data/widget_note_home_widget_service.dart';
import '../../data/widget_note_store.dart';

/// A hidden diagnostics screen that runs every step of the widget-note chain
/// and shows the raw result of each one, so a silent failure (RLS policy,
/// signed URL, widget data) becomes visible right on the phone.
class WidgetNoteDiagnosticsScreen extends StatefulWidget {
  const WidgetNoteDiagnosticsScreen({super.key});

  @override
  State<WidgetNoteDiagnosticsScreen> createState() =>
      _WidgetNoteDiagnosticsScreenState();
}

class _CheckResult {
  _CheckResult(this.title, this.detail, {required this.ok});

  final String title;
  final String detail;
  final bool ok;
}

class _WidgetNoteDiagnosticsScreenState
    extends State<WidgetNoteDiagnosticsScreen> {
  bool _running = false;
  final List<_CheckResult> _results = [];

  @override
  void initState() {
    super.initState();
    _runChecks();
  }

  Future<void> _runChecks() async {
    setState(() {
      _running = true;
      _results.clear();
    });

    void add(String title, String detail, bool ok) {
      _results.add(_CheckResult(title, detail, ok: ok));
      if (mounted) setState(() {});
    }

    // 1. Signed in?
    final user = supabase.auth.currentUser;
    if (user == null) {
      add('Account', 'WALANG naka-sign in! Di kayang mag-fetch ng notes.', false);
      setState(() => _running = false);
      return;
    }
    add('Account', 'Signed in: ${user.email ?? user.id}', true);

    // 2. Approved account?
    try {
      final approved = await supabase.rpc('is_panpanskii_approved_user');
      add('Approved account?', 'is_panpanskii_approved_user() = $approved',
          approved == true);
    } catch (error) {
      add('Approved account?', 'RPC failed: $error', false);
    }

    // 3. All visible rows in widget_notes (RLS-filtered).
    try {
      final rows = await supabase
          .from('widget_notes')
          .select('id, user_id, username, storage_path, created_at')
          .order('created_at', ascending: false)
          .limit(10);
      final list = (rows as List).map((row) => row as Map).toList();
      if (list.isEmpty) {
        add(
          'widget_notes rows (visible to you)',
          'WALANG rows na nakikita mo. Either walang nag-send pa, o '
          'hindi ka approved account (RLS).',
          false,
        );
      } else {
        final buffer = StringBuffer();
        for (final row in list) {
          buffer.writeln(
            '- ${row['username']} | ${row['created_at']} | '
            '${(row['storage_path'] as String?) ?? ''}',
          );
        }
        add('widget_notes rows (visible to you, newest 10)', buffer.toString(),
            true);
      }
    } catch (error) {
      add('widget_notes rows', 'SELECT failed: $error', false);
    }
    // 4. The exact query syncLatest() runs.
    WidgetNote? note;
    try {
      note = await WidgetNoteStore().fetchLatestPartnerNote();
      if (note == null) {
        add(
          'fetchLatestPartnerNote()',
          'returned NULL — walang partner note na nakikita ng app '
          '(RLS o wala pang nag-send mula sa kabilang account).',
          false,
        );
      } else {
        add(
          'fetchLatestPartnerNote()',
          'OK — ${note.username} | ${note.createdAt} | ${note.storagePath}',
          true,
        );
      }
    } catch (error) {
      add('fetchLatestPartnerNote()', 'THREW: $error', false);
    }

    // 5. Public URL generation.
    String? url;
    if (note != null) {
      try {
        url = await WidgetNoteStore().createNoteImageUrl(note.storagePath);
        add(
          'createNoteImageUrl()',
          url == null || url.isEmpty
              ? 'returned NULL/empty — hindi nagawa ang public URL.'
              : 'OK — $url',
          url != null && url.isNotEmpty,
        );
      } catch (error) {
        add('createNoteImageUrl()', 'THREW: $error', false);
      }
    }

    // 6. Can the PNG actually be downloaded over HTTP?
    if (url != null && url.isNotEmpty) {
      try {
        final client = HttpClient();
        final request = await client.getUrl(Uri.parse(url));
        final response = await request.close();
        final length = response.contentLength;
        await response.drain<void>();
        client.close();
        add(
          'PNG download test',
          'HTTP ${response.statusCode}, ${length < 0 ? '?' : '$length bytes'}',
          response.statusCode == 200,
        );
      } catch (error) {
        add('PNG download test', 'THREW: $error', false);
      }
    }

    // 7. What the widget data actually holds right now.
    try {
      final savedUrl = await HomeWidget.getWidgetData<String>(
        WidgetNoteHomeWidgetService.imageUrlKey,
      );
      final savedUser = await HomeWidget.getWidgetData<String>(
        WidgetNoteHomeWidgetService.usernameKey,
      );
      add(
        'Widget data (saved on this phone)',
        savedUrl == null || savedUrl.isEmpty
            ? 'EMPTY — walang na-save na image URL sa widget storage. '
                'Ibig sabihin hindi umabot dito ang syncLatest().'
            : 'URL saved: $savedUrl\nusername: ${savedUser ?? '-'}',
        savedUrl != null && savedUrl.isNotEmpty,
      );
    } catch (error) {
      add('Widget data', 'THREW: $error', false);
    }

    // 8. Force one more sync so the user can retry in-place.
    try {
      await WidgetNoteHomeWidgetService.syncLatest();
      add('Manual syncLatest()', 'Tumakbo nang walang exception.', true);
    } catch (error) {
      add('Manual syncLatest()', 'THREW: $error', false);
    }

    if (mounted) setState(() => _running = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Widget Note Diagnostics'),
        actions: [
          IconButton(
            onPressed: _running ? null : _runChecks,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _running && _results.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _results.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final result = _results[index];
                return Card(
                  color: result.ok
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  child: ListTile(
                    leading: Icon(
                      result.ok ? Icons.check_circle : Icons.error,
                      color: result.ok ? Colors.green : Colors.red,
                    ),
                    title: Text(result.title),
                    subtitle: SelectableText(result.detail),
                  ),
                );
              },
            ),
    );
  }
}