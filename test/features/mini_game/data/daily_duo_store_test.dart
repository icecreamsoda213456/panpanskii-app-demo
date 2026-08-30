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

    test('consecutive days never repeat the same answer set', () {
      for (var index = 1; index < dailyDuoV2Prompts.length; index++) {
        expect(
          dailyDuoV2Prompts[index].options,
          isNot(equals(dailyDuoV2Prompts[index - 1].options)),
          reason: 'Back-to-back answer sets at index $index',
        );
      }
    });

    test('the same answer set stays at least 359 days apart', () {
      for (var index = 30; index < dailyDuoV2Prompts.length; index++) {
        for (var other = index + 1;
            other < dailyDuoV2Prompts.length;
            other++) {
          const separator = '\u0001';
          final options = dailyDuoV2Prompts[index].options.join(separator);
          if (options ==
              dailyDuoV2Prompts[other].options.join(separator)) {
            expect(
              other - index,
              greaterThanOrEqualTo(359),
              reason: 'Answer set at $index repeats too soon at $other',
            );
          }
        }
      }
    });

    test('the V2 packs rotate through a full year before repeating', () {
      // The bank is five phrasings of 359 topics. The phrasings are laid out so
      // each 359-day slot block covers every topic exactly once, then the same
      // topic returns one year later with a fresh wording. This catches anyone
      // "helpfully" grouping the packs back together (five same-answer days).
      final legacyCount = dailyDuoLegacyPrompts.length;
      final packs = dailyDuoV2Prompts.skip(legacyCount).toList();
      final blockSize = packs.length ~/ 5;

      expect(blockSize, 359);

      String optionsKey(DailyDuoPrompt prompt) =>
          prompt.options.join('\u0001');

      final perSetCounts = <String, int>{};
      for (final prompt in packs) {
        perSetCounts.update(
          optionsKey(prompt),
          (count) => count + 1,
          ifAbsent: () => 1,
        );
      }
      for (final count in perSetCounts.values) {
        expect(
          count,
          5,
          reason: 'every topic should have exactly five phrasings',
        );
      }

      for (var block = 0; block < 5; block++) {
        final seen = <String>{};
        for (var index = block * blockSize;
            index < (block + 1) * blockSize;
            index++) {
          expect(
            seen.add(optionsKey(packs[index])),
            isTrue,
            reason: 'an answer set repeats inside slot block $block '
                'at bank index ${index + legacyCount}',
          );
        }
        expect(seen, hasLength(blockSize));
      }
    });
  });

  group('Daily Duo date selection', () {
    final store = DailyDuoStore();
    // UTC-noon inputs keep date selection stable on any machine timezone; the
    // store itself decides the day in Manila time (UTC+8) like the garden.
    final v2StartAtNoon = DateTime.utc(2026, 7, 28, 12);

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
        DateTime.utc(2024, 1, 3, 12),
        DateTime.utc(2025, 6, 15, 12),
        DateTime.utc(2026, 7, 27, 12),
      ];

      for (final date in legacyDates) {
        final round = store.roundForDate(date);
        final expected = dailyDuoLegacyPrompts[
            _legacyStableHash(round.dayKey) % dailyDuoLegacyPrompts.length];

        expect(round.prompt, expected.question);
        expect(round.options, expected.options);
      }
    });

    test('keeps the 6 AM Manila day boundary at the V2 launch', () {
      // UTC inputs keep this test stable on any machine timezone.
      final beforeBoundary = store.roundForDate(
        DateTime.utc(2026, 7, 27, 21, 59), // Manila 2026-07-28 05:59
      );
      final atBoundary = store.roundForDate(
        DateTime.utc(2026, 7, 27, 22), // Manila 2026-07-28 06:00
      );

      final expectedLegacy = dailyDuoLegacyPrompts[
          _legacyStableHash(beforeBoundary.dayKey) %
              dailyDuoLegacyPrompts.length];

      expect(beforeBoundary.dayKey, '2026-07-27');
      expect(beforeBoundary.prompt, expectedLegacy.question);
      expect(atBoundary.dayKey, '2026-07-28');
      expect(atBoundary.prompt, dailyDuoV2Prompts.first.question);
      expect(atBoundary.options, dailyDuoV2Prompts.first.options);
    });

    test('keys days in Manila time so both phones always agree', () {
      // 8 AM UTC is still the same Manila day, but 10 PM UTC is already the
      // next Manila day. This matches CozyGardenStore.todayKey(), so duo
      // answers and the garden bonus always share one day across both phones.
      expect(
        store.roundForDate(DateTime.utc(2026, 8, 30, 0)).dayKey,
        '2026-08-30',
      );
      expect(
        store.roundForDate(DateTime.utc(2026, 8, 30, 22)).dayKey,
        '2026-08-31',
      );
    });
  });
}

int _legacyStableHash(String value) {
  return value.codeUnits
      .fold<int>(0, (sum, codeUnit) => sum * 31 + codeUnit)
      .abs();
}
