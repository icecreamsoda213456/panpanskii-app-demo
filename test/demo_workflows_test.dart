import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:panpanskii_app/core/demo/demo_store.dart';
import 'package:panpanskii_app/features/auth/data/local_account_store.dart';
import 'package:panpanskii_app/features/chat/data/private_chat_store.dart';
import 'package:panpanskii_app/features/dates/data/couple_date_store.dart';
import 'package:panpanskii_app/features/journal/data/shared_journal_store.dart';
import 'package:panpanskii_app/features/mood/data/mood_status_store.dart';
import 'package:panpanskii_app/features/send_love/data/send_love_store.dart';
import 'package:panpanskii_app/features/thoughts/data/thoughts_store.dart';
import 'package:panpanskii_app/features/question/data/daily_question_store.dart';
import 'package:panpanskii_app/features/mini_game/data/daily_duo_store.dart';
import 'package:panpanskii_app/features/mini_game/data/cozy_garden_store.dart';
import 'package:panpanskii_app/features/photobooth/data/photobooth_store.dart';
import 'package:panpanskii_app/features/magnetic_hearts/data/demo_magnetic_heart_repository.dart';
import 'package:panpanskii_app/features/magnetic_hearts/domain/magnetic_heart_models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final demo = DemoStore.instance;
  const alex = LocalAccount(
      username: 'Alex', mascot: AccountMascot.panda, isBiometricEnabled: false);

  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'unrelated-setting': 'keep-me'});
    await demo.initialize();
  });
  setUp(() => demo.reset());

  test('fictional content loads without initializing Supabase', () async {
    expect(await PrivateChatStore().watchMessages().first, hasLength(5));
    expect(await SendLoveStore().loadSentLoveLetters(), hasLength(3));
    expect(await ThoughtsStore().loadThoughts(), hasLength(3));
    expect(await SharedJournalStore().watchEntries().first, hasLength(3));
    expect(await MoodStatusStore().loadStatuses(), hasLength(2));
    expect(await CoupleDateStore().loadUpcomingPlans(), hasLength(3));
    expect(await PhotoBoothStore().loadCompletedSessions(), hasLength(3));
  });

  test('demo drafts persist and reset without touching native drafts',
      () async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('journal_draft_Alex', 'Keep native draft');
    await demo.saveDraft('journal_draft_Alex', 'A fictional draft');
    final reopened = DemoStore();
    expect(await reopened.loadDraft('journal_draft_Alex'), 'A fictional draft');
    await demo.reset();
    expect(await demo.loadDraft('journal_draft_Alex'), isNull);
    expect(preferences.getString('journal_draft_Alex'), 'Keep native draft');
  });

  test('chat sends, streams updates, and persists across store instances',
      () async {
    final store = PrivateChatStore();
    final next =
        store.watchMessages().firstWhere((messages) => messages.length == 6);
    await store.sendMessage(account: alex, message: '  See you soon!  ');
    final messages = await next;
    expect(messages.last.message, 'See you soon!');
    expect(messages.last.isMine, isTrue);
    final reopened = DemoStore();
    await reopened.initialize();
    expect(reopened.rows('private_chat_messages'), hasLength(6));
    await store.sendMessage(account: alex, message: '  ');
    expect(await store.watchMessages().first, hasLength(6));
  });

  test('reactions change or remove without duplicate ownership rows', () async {
    final store = PrivateChatStore();
    await store.toggleReaction(
        account: alex,
        messageId: 'chat-1',
        reaction: 'love',
        currentReaction: null);
    await store.toggleReaction(
        account: alex,
        messageId: 'chat-1',
        reaction: 'happy',
        currentReaction: 'love');
    final mine = (await store.watchReactions().first)
        .where((reaction) => reaction.isMine)
        .toList();
    expect(mine, hasLength(1));
    expect(mine.single.reaction, 'happy');
    await store.toggleReaction(
        account: alex,
        messageId: 'chat-1',
        reaction: 'happy',
        currentReaction: null);
    expect(
        (await store.watchReactions().first)
            .where((reaction) => reaction.isMine),
        isEmpty);
  });

  test('letters, comments, and thoughts save and reject empty content',
      () async {
    final letters = SendLoveStore();
    final letter =
        await letters.sendLove(account: alex, message: 'A sample letter');
    await letters.addComment(
        account: alex, letterId: letter.id, message: 'A sample comment');
    await letters.toggleReaction(
        account: alex,
        letterId: letter.id,
        reaction: 'love',
        currentReaction: null);
    expect((await letters.loadComments(letter.id)).single.message,
        'A sample comment');
    expect((await letters.loadReactionSummary(letter.id)).totalCount, 1);
    final thoughts = ThoughtsStore();
    await thoughts.createThought(account: alex, body: 'A new thought');
    final thought = (await thoughts.loadThoughts()).first;
    await thoughts.addComment(
        account: alex, thoughtId: thought.id, message: 'Thanks');
    expect(await thoughts.loadComments(thought.id), hasLength(1));
    await expectLater(thoughts.createThought(account: alex, body: '  '),
        throwsFormatException);
    await expectLater(
        letters.sendLove(account: alex, message: ''), throwsFormatException);
  });

  test('journal updates tonight instead of duplicating it and moods update',
      () async {
    final journal = SharedJournalStore();
    await journal.saveTonightEntry(
        account: alex, title: 'Today', body: 'First draft');
    await journal.saveTonightEntry(
        account: alex, title: 'Today', body: 'Final draft');
    final entries = await journal.watchEntries().first;
    expect(entries, hasLength(4));
    expect(entries.first.body, 'Final draft');
    final moods = MoodStatusStore();
    await moods.setMood(account: alex, mood: 'happy');
    await moods.setMood(account: alex, mood: 'calm');
    expect(await moods.loadStatuses(), hasLength(2));
    expect(
        (await moods.loadStatuses())
            .firstWhere((mood) => mood.userId == DemoStore.userId)
            .mood,
        'calm');
  });

  test('question answers validate length and cannot delete partner answers',
      () async {
    final store = DailyQuestionStore();
    final day = store.questionForNow().dayKey;
    await store.deleteComment('question-1');
    expect(await store.watchComments(day).first, hasLength(1));
    await store.addComment(
        account: alex, dayKey: day, message: 'Being present');
    final mine = (await store.watchComments(day).first).last;
    await store.deleteComment(mine.id);
    expect(await store.watchComments(day).first, hasLength(1));
    await expectLater(
        store.addComment(account: alex, dayKey: day, message: 'a' * 601),
        throwsFormatException);
  });

  test('dates create, edit, filter, delete, and enforce ownership', () async {
    final store = CoupleDateStore();
    final date = DateTime.now().add(const Duration(days: 10));
    var plan = await store.savePlan(
        account: alex,
        title: 'Coffee',
        notes: 'Sample',
        category: CoupleDateCategory.food,
        visibility: CoupleDateVisibility.shared,
        previousVisibility: null,
        startsAt: date,
        reminderMinutes: null);
    plan = await store.savePlan(
        id: plan.id,
        account: alex,
        title: 'Tea',
        notes: '',
        category: CoupleDateCategory.food,
        visibility: CoupleDateVisibility.personal,
        previousVisibility: plan.visibility,
        startsAt: date,
        reminderMinutes: null);
    expect(await store.watchPlans().first, hasLength(4));
    expect(
        (await store.loadUpcomingPlans(
                from: date.subtract(const Duration(hours: 1))))
            .single
            .title,
        'Tea');
    await store.deletePlan(plan);
    expect(await store.watchPlans().first, hasLength(3));
    final partnerPlan =
        (await store.watchPlans().first).firstWhere((plan) => !plan.isMine);
    await expectLater(store.deletePlan(partnerPlan), throwsStateError);
    await expectLater(
        store.savePlan(
            id: partnerPlan.id,
            account: alex,
            title: 'No',
            notes: '',
            category: CoupleDateCategory.other,
            visibility: CoupleDateVisibility.shared,
            previousVisibility: null,
            startsAt: date,
            reminderMinutes: null),
        throwsStateError);
  });

  test('garden watering, harvest, and unlocks are consistent and idempotent',
      () async {
    final store = CozyGardenStore();
    final day = store.todayKey();
    final watered = await store.waterGarden(account: alex, dayKey: day);
    expect(watered.growth, 100);
    expect(watered.currentStreak, 4);
    await expectLater(
        store.waterGarden(account: alex, dayKey: day), throwsStateError);
    final harvested = await store.harvestGarden(nextPlant: 'sakura');
    expect(harvested.garden.growth, 0);
    expect(harvested.garden.totalHarvests, 3);
    expect(await store.loadHarvests(), hasLength(3));
    expect((await store.watchUnlocks().first).map((unlock) => unlock.unlockKey),
        contains('plant:rose'));
    await expectLater(
        store.harvestGarden(nextPlant: 'sakura'), throwsStateError);
  });

  test('Daily Duo rejects invalid options and awards each bonus only once',
      () async {
    final duo = DailyDuoStore();
    final garden = CozyGardenStore();
    final round = duo.roundForNow();
    await expectLater(
        duo.submitAnswer(account: alex, round: round, optionIndex: -1),
        throwsStateError);
    await duo.submitAnswer(account: alex, round: round, optionIndex: 0);
    final bonus = await garden.claimDailyDuoBonus(dayKey: round.dayKey);
    expect(bonus.isComplete, isTrue);
    expect(bonus.isMatch, isTrue);
    expect(bonus.awardedGrowth, 3);
    expect(
        (await garden.claimDailyDuoBonus(dayKey: round.dayKey)).awardedGrowth,
        0);
    expect((await garden.watchGarden().first).growth, 93);
  });

  test('photo gallery filters and sample image data load locally', () async {
    final store = PhotoBoothStore();
    final albums = await store.loadCompletedSessions(frameStyle: 'sakura');
    expect(albums, hasLength(1));
    final photos = await store.loadPhotos(albums.single.id);
    expect(photos, hasLength(10));
    expect(photos.first.imageUrl, startsWith('data:image/png;base64,'));
    expect(
        await store.loadCompletedSessions(
            startDate: DateTime.now().add(const Duration(days: 1))),
        isEmpty);
  });

  test('local practice game supports create, ready, play, complete, replay',
      () async {
    final repository = DemoMagneticHeartRepository();
    final room = await repository.createRoom(alex);
    expect(await repository.watchMembers(room.id).first, hasLength(2));
    expect((await repository.setReady(roomId: room.id, ready: true)).status,
        MagneticHeartRoomStatus.countdown);
    expect((await repository.beginGame(room.id)).status,
        MagneticHeartRoomStatus.playing);
    expect((await repository.completeGame(room.id)).isCompleted, isTrue);
    expect((await repository.resetGame(room.id)).status,
        MagneticHeartRoomStatus.waiting);
    await expectLater(repository.joinRoom(roomCode: 'WRONG1', account: alex),
        throwsStateError);
    await repository.dispose();
  });

  test('concurrent writes are preserved and reset only touches demo storage',
      () async {
    await Future.wait(List.generate(
        12,
        (index) => demo.save('thought_posts', {
              ...DemoStore.profile,
              'body': 'Sample $index',
            })));
    expect(demo.rows('thought_posts'), hasLength(15));
    await demo.reset();
    expect(demo.rows('thought_posts'), hasLength(3));
    expect(
        (await SharedPreferences.getInstance()).getString('unrelated-setting'),
        'keep-me');
  });

  test('failed transaction does not publish partial data', () async {
    await expectLater(demo.transaction((tables) {
      tables['thought_posts']!.clear();
      throw StateError('Simulated write failure');
    }), throwsStateError);
    expect(demo.rows('thought_posts'), hasLength(3));
  });
}
