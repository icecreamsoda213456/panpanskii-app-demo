import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/features/mini_game/data/daily_duo_prompts.dart';
import 'package:panpanskii_app/features/mini_game/data/daily_duo_store.dart';

void main() {
  group('Daily Duo prompt bank', () {
    test('contains the original 30 and exactly 1825 V2 prompts', () {
      expect(dailyDuoLegacyPrompts, hasLength(30));
      expect(dailyDuoV2Prompts, hasLength(1825));
      expect(
        dailyDuoV2Prompts.take(dailyDuoLegacyPrompts.length).toList(),
        dailyDuoLegacyPrompts,
      );
    });

    test('every prompt has one unique question and four unique options', () {
      final normalizedQuestions = <String>{};

      for (final prompt in dailyDuoV2Prompts) {
        expect(prompt.question.trim(), isNotEmpty);
        expect(prompt.question.endsWith('?'), isTrue);
        expect(prompt.options, hasLength(4));
        expect(prompt.options.toSet(), hasLength(4));
        expect(
            prompt.options.every((option) => option.trim().isNotEmpty), isTrue);
        expect(
          normalizedQuestions.add(prompt.question.trim().toLowerCase()),
          isTrue,
          reason: 'Duplicate Daily Duo question: ${prompt.question}',
        );
      }
    });
  });

  group('Daily Duo date selection', () {
    final store = DailyDuoStore();
    final v2StartAtNoon = DateTime(2026, 7, 28, 12);

    test('uses every V2 prompt once before cycling', () {
      final firstCycleQuestions = <String>{};

      for (var dayIndex = 0; dayIndex < 1825; dayIndex++) {
        final round = store.roundForDate(
          v2StartAtNoon.add(Duration(days: dayIndex)),
        );
        final expected = dailyDuoV2Prompts[dayIndex];

        expect(round.prompt, expected.question);
        expect(round.options, expected.options);
        expect(firstCycleQuestions.add(round.prompt), isTrue);
      }

      expect(firstCycleQuestions, hasLength(1825));
    });

    test('cycles to the first prompt on day 1826', () {
      final first = store.roundForDate(v2StartAtNoon);
      final cycled = store.roundForDate(
        v2StartAtNoon.add(const Duration(days: 1825)),
      );

      expect(cycled.prompt, first.prompt);
      expect(cycled.options, first.options);
    });

    test('preserves the original stable-hash selection before V2', () {
      final legacyDates = <DateTime>[
        DateTime(2024, 1, 3, 12),
        DateTime(2025, 6, 15, 12),
        DateTime(2026, 7, 27, 12),
      ];

      for (final date in legacyDates) {
        final round = store.roundForDate(date);
        final expected = dailyDuoLegacyPrompts[
            _legacyStableHash(round.dayKey) % dailyDuoLegacyPrompts.length];

        expect(round.prompt, expected.question);
        expect(round.options, expected.options);
      }
    });

    test('keeps the existing 6 AM day boundary at the V2 launch', () {
      final beforeBoundary = store.roundForDate(
        DateTime(2026, 7, 28, 5, 59),
      );
      final atBoundary = store.roundForDate(DateTime(2026, 7, 28, 6));

      final expectedLegacy = dailyDuoLegacyPrompts[
          _legacyStableHash(beforeBoundary.dayKey) %
              dailyDuoLegacyPrompts.length];

      expect(beforeBoundary.dayKey, '2026-07-27');
      expect(beforeBoundary.prompt, expectedLegacy.question);
      expect(atBoundary.dayKey, '2026-07-28');
      expect(atBoundary.prompt, dailyDuoV2Prompts.first.question);
      expect(atBoundary.options, dailyDuoV2Prompts.first.options);
    });
  });
}

int _legacyStableHash(String value) {
  return value.codeUnits
      .fold<int>(0, (sum, codeUnit) => sum * 31 + codeUnit)
      .abs();
}
