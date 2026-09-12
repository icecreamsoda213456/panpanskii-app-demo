import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'demo_seed.dart';

typedef DemoRow = Map<String, dynamic>;
typedef DemoTables = Map<String, List<DemoRow>>;

/// Isolated, browser-local demo data. No credentials or network transport.
class DemoStore {
  DemoStore();

  static final instance = DemoStore();
  static const storageKey = 'panpanskii_portfolio_demo_v1';
  static const userId = '11111111-1111-4111-8111-111111111111';
  static const partnerId = '22222222-2222-4222-8222-222222222222';
  static const profile = {
    'user_id': userId,
    'username': 'Alex',
    'mascot': 'panda'
  };
  static const partner = {
    'user_id': partnerId,
    'username': 'Sam',
    'mascot': 'koala'
  };

  final _changes = StreamController<void>.broadcast();
  DemoTables _tables = {};
  Future<void>? _initialization;
  Future<void> _pending = Future.value();
  late SharedPreferences _preferences;
  int _sequence = 0;

  Future<void> initialize() => _initialization ??= _load();

  Future<void> _load() async {
    _preferences = await SharedPreferences.getInstance();
    final raw = _preferences.getString(storageKey);
    if (raw != null) {
      try {
        _tables = _decode(raw);
        return;
      } on FormatException {
        // Only this demo's malformed snapshot is replaced.
      } on TypeError {
        // Older or incompatible snapshots must not break the demo startup.
      }
    }
    _tables = createDemoSeed(DateTime.now());
    await _preferences.setString(storageKey, jsonEncode(_tables));
  }

  DemoTables _decode(String raw) =>
      (jsonDecode(raw) as Map<String, dynamic>).map((key, value) => MapEntry(
          key,
          (value as List)
              .map((row) => Map<String, dynamic>.from(row as Map))
              .toList()));

  List<DemoRow> rows(String table,
      {DemoRow where = const {}, String? order, bool descending = false}) {
    final result = (_tables[table] ?? [])
        .where((row) =>
            where.entries.every((entry) => row[entry.key] == entry.value))
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
    if (order != null) {
      result.sort((a, b) =>
          '${a[order]}'.compareTo('${b[order]}') * (descending ? -1 : 1));
    }
    return result;
  }

  Stream<List<DemoRow>> watch(String table,
          {DemoRow where = const {}, String? order, bool descending = false}) =>
      Stream.multi((controller) {
        var active = true;
        void emit() {
          if (active) {
            controller.add(rows(table,
                where: where, order: order, descending: descending));
          }
        }

        final subscription = _changes.stream.listen((_) => emit());
        initialize().then((_) => emit(), onError: controller.addError);
        controller.onCancel = () {
          active = false;
          subscription.cancel();
        };
      });

  Future<T> transaction<T>(T Function(DemoTables tables) change) {
    final result = _pending.then((_) async {
      await initialize();
      final next = _decode(jsonEncode(_tables));
      final value = change(next);
      if (!await _preferences.setString(storageKey, jsonEncode(next))) {
        throw StateError(
            'Could not save this demo. Browser storage may be full.');
      }
      _tables = next;
      _changes.add(null);
      return value;
    });
    _pending = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<DemoRow> save(String table, DemoRow row,
          {List<String> keys = const ['id']}) =>
      transaction((tables) => put(tables, table, row, keys: keys));

  DemoRow put(DemoTables tables, String table, DemoRow row,
      {List<String> keys = const ['id']}) {
    final list = tables.putIfAbsent(table, () => []);
    final index = list.indexWhere(
        (old) => keys.every((key) => row[key] != null && old[key] == row[key]));
    final now = DateTime.now().toUtc().toIso8601String();
    final saved = <String, dynamic>{
      'id': 'demo-${DateTime.now().microsecondsSinceEpoch}-${_sequence++}',
      'created_at': now,
      if (index >= 0) ...list[index],
      ...row,
      'updated_at': now,
    };
    if (index < 0) {
      list.add(saved);
    } else {
      list[index] = saved;
    }
    return Map<String, dynamic>.from(saved);
  }

  Future<void> remove(String table, DemoRow where) => transaction((tables) {
        tables[table]?.removeWhere(
            (row) => where.entries.every((e) => row[e.key] == e.value));
      });

  Future<void> react(
          String table, String parentKey, String parentId, String reaction) =>
      transaction((tables) {
        final list = tables.putIfAbsent(table, () => []);
        final index = list.indexWhere(
            (row) => row[parentKey] == parentId && row['user_id'] == userId);
        if (index >= 0 && list[index]['reaction'] == reaction) {
          list.removeAt(index);
          return;
        }
        put(tables, table,
            {...profile, parentKey: parentId, 'reaction': reaction},
            keys: [parentKey, 'user_id']);
      });

  Future<void> reset() => transaction((tables) {
        tables
          ..clear()
          ..addAll(createDemoSeed(DateTime.now()));
      });

  Future<String?> loadDraft(String key) async {
    await initialize();
    final drafts = rows('drafts', where: {'id': key});
    return drafts.isEmpty ? null : drafts.first['body'] as String?;
  }

  Future<void> saveDraft(String key, String value) async {
    if (value.trim().isEmpty) {
      await remove('drafts', {'id': key});
    } else {
      await save('drafts', {'id': key, 'body': requireText(value)});
    }
  }

  static String requireText(String text, {int max = 4000}) {
    final value = text.trim();
    if (value.isEmpty) {
      throw const FormatException('Please write something first.');
    }
    if (value.length > max) {
      throw FormatException('Please use $max characters or fewer.');
    }
    return value;
  }
}
