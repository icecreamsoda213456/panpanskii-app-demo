import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class DailyBibleVerse {
  const DailyBibleVerse({
    required this.reference,
    required this.text,
    required this.reflection,
    required this.translation,
    required this.isFromFallback,
  });

  final String reference;
  final String text;
  final String reflection;
  final String translation;
  final bool isFromFallback;

  Map<String, String> toCache() {
    return {
      'reference': reference,
      'text': text,
      'reflection': reflection,
      'translation': translation,
      'isFromFallback': isFromFallback.toString(),
    };
  }

  static DailyBibleVerse? fromCache(Map<String, String> cache) {
    final reference = cache['reference'];
    final text = cache['text'];
    final reflection = cache['reflection'];
    final translation = cache['translation'];
    if (reference == null ||
        text == null ||
        reflection == null ||
        translation == null) {
      return null;
    }

    return DailyBibleVerse(
      reference: reference,
      text: text,
      reflection: reflection,
      translation: translation,
      isFromFallback: cache['isFromFallback'] == 'true',
    );
  }
}

class DailyBibleVerseStore {
  static const _cacheDateKey = 'daily_bible_verse_date';
  static const _cachePayloadKey = 'daily_bible_verse_payload';
  static const _apiHost = 'bible-api.com';
  static const _apiPath = '/data/web/random/NT';

  Future<DailyBibleVerse> loadTodayVerse({bool forceRefresh = false}) async {
    final preferences = await SharedPreferences.getInstance();
    final todayKey = _todayKey(DateTime.now());

    if (!forceRefresh && preferences.getString(_cacheDateKey) == todayKey) {
      final cached = _readCachedVerse(preferences);
      if (cached != null) {
        return cached;
      }
    }

    try {
      final verse = await _fetchRandomVerse();
      await _cacheVerse(preferences, todayKey, verse);
      return verse;
    } catch (_) {
      final fallback = _fallbackForToday(todayKey);
      await _cacheVerse(preferences, todayKey, fallback);
      return fallback;
    }
  }

  DailyBibleVerse? _readCachedVerse(SharedPreferences preferences) {
    final payload = preferences.getString(_cachePayloadKey);
    if (payload == null) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return DailyBibleVerse.fromCache(
        decoded.map((key, value) => MapEntry(key, value.toString())),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheVerse(
    SharedPreferences preferences,
    String todayKey,
    DailyBibleVerse verse,
  ) async {
    await preferences.setString(_cacheDateKey, todayKey);
    await preferences.setString(_cachePayloadKey, jsonEncode(verse.toCache()));
  }

  Future<DailyBibleVerse> _fetchRandomVerse() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
    try {
      final request = await client
          .getUrl(Uri.https(_apiHost, _apiPath))
          .timeout(const Duration(seconds: 6));
      final response =
          await request.close().timeout(const Duration(seconds: 8));
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('Bible API returned a non-200 response.');
      }

      final body = await utf8.decoder.bind(response).join();
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Unexpected Bible API payload.');
      }

      final translation = decoded['translation'];
      final randomVerse = decoded['random_verse'];
      if (randomVerse is! Map<String, dynamic>) {
        throw const FormatException('Missing verse payload.');
      }

      final book = randomVerse['book']?.toString().trim() ?? '';
      final chapter = randomVerse['chapter']?.toString().trim() ?? '';
      final verse = randomVerse['verse']?.toString().trim() ?? '';
      final text = randomVerse['text']?.toString().trim() ?? '';
      final translationName = translation is Map<String, dynamic>
          ? translation['name']?.toString().trim()
          : null;

      if (book.isEmpty || chapter.isEmpty || verse.isEmpty || text.isEmpty) {
        throw const FormatException('Incomplete verse payload.');
      }

      final reference = '$book $chapter:$verse';
      return DailyBibleVerse(
        reference: reference,
        text: text,
        reflection: _buildReflection(text, reference),
        translation: translationName?.isNotEmpty == true
            ? translationName!
            : 'World English Bible',
        isFromFallback: false,
      );
    } finally {
      client.close(force: true);
    }
  }

  DailyBibleVerse _fallbackForToday(String todayKey) {
    final index = todayKey.codeUnits.fold<int>(0, (sum, value) => sum + value) %
        _fallbackVerses.length;
    return _fallbackVerses[index];
  }

  String _buildReflection(String text, String reference) {
    final lowered = text.toLowerCase();
    final random = math.Random(reference.hashCode);
    if (lowered.contains('love')) {
      return [
        'Let love shape one conversation today, especially the one that needs patience.',
        'Receive this as a reminder that love is something we practice in small choices.',
        'Look for one person who needs gentleness, then let this verse guide your response.',
      ][random.nextInt(3)];
    }
    if (lowered.contains('fear') || lowered.contains('afraid')) {
      return [
        'Fear can be present without being in charge. Take the next step with God beside you.',
        'When worry gets loud, return to this promise before you return to your assumptions.',
        'You do not need perfect courage today; faithful movement is enough.',
      ][random.nextInt(3)];
    }
    if (lowered.contains('peace') || lowered.contains('still')) {
      return [
        'Give yourself one quiet minute today. Stillness can make space for a clearer heart.',
        'Let this verse become a pause before your next reaction or decision.',
        'Peace may begin quietly, with one breath and one thing you choose not to carry alone.',
      ][random.nextInt(3)];
    }
    if (lowered.contains('light') || lowered.contains('shine')) {
      return [
        'Bring a little light into one ordinary moment through attention, honesty, or kindness.',
        'Your good work does not need to be loud to make a difference.',
        'Notice where you can make someone\'s path a little brighter today.',
      ][random.nextInt(3)];
    }
    if (lowered.contains('hope') || lowered.contains('rejoic')) {
      return [
        'Hold on to one hopeful possibility today and let it influence your next small action.',
        'Hope is not denial; it is choosing to keep your heart open while life unfolds.',
        'Write down one reason to keep going, then share that courage with someone you love.',
      ][random.nextInt(3)];
    }
    return [
      'Read this slowly and ask: what would it look like to live one sentence of it today?',
      'Carry one word from this verse into your day and return to it when you need direction.',
      'Let this move from the page into one practical choice before the day is over.',
    ][random.nextInt(3)];
  }

  String _todayKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}

const _fallbackVerses = <DailyBibleVerse>[
  DailyBibleVerse(
    reference: 'John 3:16',
    text:
        'For God so loved the world, that he gave his one and only Son, that whoever believes in him should not perish, but have eternal life.',
    reflection:
        'Love is the center of the story. Let today begin from being loved, not from proving yourself.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 46:10',
    text: 'Be still, and know that I am God.',
    reflection:
        'Stillness is not doing nothing. It is making room to remember who holds the day.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Philippians 4:13',
    text: 'I can do all things through Christ, who strengthens me.',
    reflection:
        'Strength can arrive quietly. Take the next faithful step and let grace meet you there.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Proverbs 3:5',
    text:
        'Trust in Yahweh with all your heart, and do not lean on your own understanding.',
    reflection:
        'You do not need to solve the whole path today. Trust can start with one surrendered step.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Isaiah 41:10',
    text:
        'Do not be afraid, for I am with you. Do not be dismayed, for I am your God.',
    reflection:
        'Fear may visit, but it does not get to lead. You are not walking through today alone.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Matthew 5:16',
    text:
        'Even so, let your light shine before men, that they may see your good works and glorify your Father who is in heaven.',
    reflection:
        'Your small goodness matters. Let kindness be visible without needing applause.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Romans 12:12',
    text:
        'Rejoicing in hope; enduring in troubles; continuing steadfastly in prayer.',
    reflection:
        'Hope, patience, and prayer can hold hands. Choose one of them when the day gets heavy.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 118:24',
    text:
        'This is the day that Yahweh has made. We will rejoice and be glad in it!',
    reflection:
        'Today is not random; it is given. Notice one good thing and let gratitude grow from there.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Jeremiah 29:11',
    text:
        'For I know the thoughts that I think toward you, says Yahweh, thoughts of peace, and not of evil, to give you hope and a future.',
    reflection:
        'You may not see the whole path yet, but you can carry hope into the next faithful step.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 23:1',
    text: 'Yahweh is my shepherd: I shall lack nothing.',
    reflection:
        'Let this picture of gentle care soften the pressure to have everything figured out today.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Matthew 11:28',
    text:
        'Come to me, all you who labor and are heavily burdened, and I will give you rest.',
    reflection:
        'You do not have to carry every burden alone. Make room for rest and honest prayer.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Joshua 1:9',
    text:
        'Be strong and courageous. Do not be afraid, nor be dismayed, for Yahweh your God is with you wherever you go.',
    reflection:
        'Courage can look like showing up while still feeling uncertain. You are not going alone.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: '1 Corinthians 16:14',
    text: 'Let all that you do be done in love.',
    reflection:
        'Before the day gets busy, choose love as the tone for one message, task, or conversation.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 34:18',
    text:
        'Yahweh is near to those who have a broken heart, and saves those who have a crushed spirit.',
    reflection:
        'Pain does not make you distant from God. Bring your honest heart exactly as it is.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Galatians 6:9',
    text:
        'Let us not be weary in doing good, for we will reap in due season if we do not give up.',
    reflection:
        'The good you keep choosing matters, even before you can see its result.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 121:1-2',
    text:
        'I will lift up my eyes to the hills. Where does my help come from? My help comes from Yahweh, who made heaven and earth.',
    reflection:
        'When you feel small in the middle of a problem, remember where your help comes from.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Colossians 3:15',
    text:
        'Let the peace of Christ rule in your hearts, to which also you were called in one body, and be thankful.',
    reflection:
        'Peace can be a guide for your response today. Pair it with one deliberate act of gratitude.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Proverbs 16:3',
    text: 'Commit your works to Yahweh, and your plans will be established.',
    reflection:
        'Offer your plans without needing to control every detail. Let trust shape the way you begin.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Lamentations 3:22-23',
    text:
        'It is because of Yahweh\'s loving kindnesses that we are not consumed, because his compassion doesn\'t fail. They are new every morning.',
    reflection:
        'This morning is not only another page; it is another chance to receive mercy and begin again.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Romans 8:28',
    text:
        'We know that all things work together for good for those who love God, for those who are called according to his purpose.',
    reflection:
        'You may not understand the whole story yet. Keep walking with trust while the pieces come together.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 27:1',
    text:
        'Yahweh is my light and my salvation. Whom shall I fear? Yahweh is the strength of my life. Of whom shall I be afraid?',
    reflection:
        'When uncertainty feels large, remember that fear is not the only voice available to you.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Isaiah 40:31',
    text:
        'But those who wait for Yahweh will renew their strength. They will mount up with wings like eagles.',
    reflection:
        'Waiting is not wasted time. Let patience restore the strength you need for what comes next.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 139:14',
    text: 'I will give thanks to you, for I am fearfully and wonderfully made.',
    reflection:
        'You are not an accident to be corrected. Practice gratitude for the person you are becoming.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Micah 6:8',
    text:
        'He has shown you, man, what is good. What does Yahweh require of you, but to act justly, to love kindness, and to walk humbly with your God?',
    reflection:
        'Let faith become practical today through fairness, kindness, and a humble heart.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 37:5',
    text: 'Commit your way to Yahweh. Trust also in him, and he will do this.',
    reflection:
        'Release one plan into God\'s care, then focus on the faithful action that belongs to you.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Matthew 6:34',
    text:
        'Therefore don\'t be anxious for tomorrow, for tomorrow will be anxious for itself.',
    reflection:
        'Today has enough grace for today. Come back from imagined tomorrows and meet this moment.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 55:22',
    text:
        'Cast your burden on Yahweh and he will sustain you. He will never allow the righteous to be moved.',
    reflection:
        'Name the burden instead of hiding it. You were never meant to carry every weight alone.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'John 14:27',
    text:
        'Peace I leave with you. My peace I give to you; not as the world gives, I give to you.',
    reflection:
        'Look for a peace deeper than perfect circumstances. Receive it one breath at a time.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Hebrews 11:1',
    text:
        'Now faith is assurance of things hoped for, proof of things not seen.',
    reflection:
        'Faith can hold a hope gently before there is evidence in your hands.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Ephesians 4:32',
    text:
        'Be kind to one another, tenderhearted, forgiving each other, just as God also in Christ forgave you.',
    reflection:
        'Choose a softer response today, including toward yourself when you make a mistake.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: 'Psalm 16:11',
    text:
        'You will show me the path of life. In your presence is fullness of joy.',
    reflection:
        'Ask what brings you closer to life, joy, and truth, then take one step in that direction.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
  DailyBibleVerse(
    reference: '2 Corinthians 12:9',
    text:
        'My grace is sufficient for you, for my power is made perfect in weakness.',
    reflection:
        'You do not have to hide every weakness. Grace can meet you exactly where you feel small.',
    translation: 'World English Bible',
    isFromFallback: true,
  ),
];
