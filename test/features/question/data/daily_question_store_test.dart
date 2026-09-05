import 'package:flutter_test/flutter_test.dart';
import 'package:panpanskii_app/features/question/data/daily_question_prompts.dart';
import 'package:panpanskii_app/features/question/data/daily_question_store.dart';

void main() {
  group('Daily Question prompt bank', () {
    test('contains five years of unique daily questions', () {
      expect(dailyQuestionPrompts, hasLength(1825));
      expect(dailyQuestionPrompts.toSet(), hasLength(1825));
      expect(
        dailyQuestionPrompts.every(
          (question) => question.trim().isNotEmpty && question.endsWith('?'),
        ),
        isTrue,
      );
    });
  });

  group('Daily Question date selection', () {
    final store = DailyQuestionStore();
    final launchAtNoon = DateTime(2026, 7, 28, 12);

    test('uses every new prompt once before repeating', () {
      final firstCycle = <String>{};

      for (var dayIndex = 0; dayIndex < 1825; dayIndex++) {
        final round = store.questionForDate(
          launchAtNoon.add(Duration(days: dayIndex)),
        );

        expect(round.question, dailyQuestionPrompts[dayIndex]);
        expect(firstCycle.add(round.question), isTrue);
      }

      expect(firstCycle, hasLength(1825));
    });

    test('cycles back to the first prompt on day 1826', () {
      final first = store.questionForDate(launchAtNoon);
      final cycled = store.questionForDate(
        launchAtNoon.add(const Duration(days: 1825)),
      );

      expect(cycled.question, first.question);
    });

    test('preserves the existing 6 AM boundary at launch', () {
      final previousDay = store.questionForDate(
        DateTime(2026, 7, 27, 12),
      );
      final beforeBoundary = store.questionForDate(
        DateTime(2026, 7, 28, 5, 59),
      );
      final atBoundary = store.questionForDate(
        DateTime(2026, 7, 28, 6),
      );

      expect(beforeBoundary.dayKey, '2026-07-27');
      expect(beforeBoundary.question, previousDay.question);
      expect(atBoundary.dayKey, '2026-07-28');
      expect(atBoundary.question, dailyQuestionPrompts.first);
    });
  });
}
