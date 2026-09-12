import 'demo_store.dart';

DemoTables createDemoSeed(DateTime now) {
  String ago(int hours) =>
      now.subtract(Duration(hours: hours)).toUtc().toIso8601String();
  String date(DateTime value) => value.toIso8601String().substring(0, 10);
  final dayKey = date(now.toUtc().add(const Duration(hours: 2)));
  final questionDay =
      date(now.hour < 6 ? now.subtract(const Duration(days: 1)) : now);
  DemoRow entry(String id, DemoRow author, int hours, DemoRow fields) => {
        'id': id,
        ...author,
        'room_id': 'main',
        'created_at': ago(hours),
        'updated_at': ago(hours),
        ...fields,
      };
  const alex = DemoStore.profile;
  const sam = DemoStore.partner;
  return {
    'private_chat_messages': [
      entry('chat-1', sam, 25,
          {'message': 'Good morning! Leaving a little sunshine here for you.'}),
      entry('chat-2', alex, 24,
          {'message': 'I found it. Adding this to our cozy wins for today!'}),
      entry('chat-3', sam, 3,
          {'message': 'Garden check later? I think our sunflower is growing.'}),
      entry('chat-4', alex, 2,
          {'message': 'I will bring the picnic blanket this weekend.'}),
      entry('chat-5', sam, 1,
          {'message': 'Deal! I added the picnic to our dates. See you soon.'}),
    ],
    'private_chat_reactions': [
      entry('chat-reaction-1', sam, 2,
          {'message_id': 'chat-4', 'reaction': 'love'})
    ],
    'send_love_letters': [
      entry('letter-1', sam, 4, {
        'message':
            'A tiny reminder: I am proud of how you keep showing up, even on the busy days. Looking forward to our slow weekend together.'
      }),
      entry('letter-2', alex, 30, {
        'message':
            'Thank you for turning an ordinary Tuesday into a good memory. Same cafe, same table, a hundred new things to talk about.'
      }),
      entry('letter-3', sam, 72, {
        'message':
            'My favorite part of our trip was getting lost and finding that little bakery. Here is to more unplanned adventures.'
      }),
    ],
    'send_love_reactions': [
      entry('love-reaction-1', sam, 29,
          {'letter_id': 'letter-2', 'reaction': 'love'})
    ],
    'send_love_comments': [
      entry('love-comment-1', alex, 3,
          {'letter_id': 'letter-1', 'message': 'Counting down to Saturday!'})
    ],
    'thought_posts': [
      entry('thought-1', sam, 5, {
        'body':
            'Small tradition idea: one photo and one thing we are grateful for, every Sunday.'
      }),
      entry('thought-2', alex, 28, {
        'body':
            'Today felt a little busy, but that five-minute check-in made all the difference.'
      }),
      entry('thought-3', sam, 55, {
        'body':
            'Our next adventure does not need a plane ticket. A new walking route counts too.'
      }),
    ],
    'thought_reactions': [
      entry('thought-reaction-1', sam, 27,
          {'thought_id': 'thought-2', 'reaction': 'love'})
    ],
    'thought_comments': [
      entry('thought-comment-1', sam, 26,
          {'thought_id': 'thought-2', 'message': 'Always making time for us.'})
    ],
    'shared_journal_entries': [
      entry('journal-1', sam, 24, {
        'title': 'The little bookshop',
        'body':
            'Rain outside, warm drinks inside. We each picked a book for the other and stayed until closing. A very good ordinary day.',
        'entry_date': date(now.subtract(const Duration(days: 1)))
      }),
      entry('journal-2', alex, 48, {
        'title': 'A recipe worth keeping',
        'body':
            'Our first attempt at homemade pasta was not perfect, but dinner together was. Next time: less flour, more patience.',
        'entry_date': date(now.subtract(const Duration(days: 2)))
      }),
      entry('journal-3', sam, 96, {
        'title': 'Sunset by the water',
        'body':
            'We left our phones in our bags and watched the colors change. I want to remember how peaceful it felt.',
        'entry_date': date(now.subtract(const Duration(days: 4)))
      }),
    ],
    'mood_statuses': [
      entry('mood-1', alex, 1, {'mood': 'calm'}),
      entry('mood-2', sam, 2, {'mood': 'happy'})
    ],
    'daily_question_comments': [
      entry('question-1', sam, 1, {
        'day_key': questionDay,
        'message':
            'Making space to listen to each other, even on an ordinary day.'
      })
    ],
    'daily_duo_answers': [
      entry('duo-1', sam, 1, {'day_key': dayKey, 'option_index': 0})
    ],
    'couple_dates': [
      entry('date-1', alex, 10, {
        'title': 'Park picnic',
        'notes': 'Bring sandwiches, a blanket, and the little speaker.',
        'category': 'date',
        'visibility': 'shared',
        'starts_at': DateTime(now.year, now.month, now.day + 2, 16)
            .toUtc()
            .toIso8601String(),
        'reminder_minutes': null
      }),
      entry('date-2', sam, 20, {
        'title': 'Movie and homemade pizza',
        'notes': 'A cozy evening at home. Sam chooses the movie.',
        'category': 'movie',
        'visibility': 'shared',
        'starts_at': DateTime(now.year, now.month, now.day + 5, 19)
            .toUtc()
            .toIso8601String(),
        'reminder_minutes': null
      }),
      entry('date-3', alex, 48, {
        'title': 'Find a birthday surprise',
        'notes': 'Visit the bookshop after work.',
        'category': 'other',
        'visibility': 'personal',
        'starts_at': DateTime(now.year, now.month, now.day + 7, 17)
            .toUtc()
            .toIso8601String(),
        'reminder_minutes': null
      }),
    ],
    'cozy_garden_state': [
      {
        'id': 'main',
        'plant_type': 'sunflower',
        'growth': 90,
        'current_streak': 3,
        'longest_streak': 5,
        'total_harvests': 2,
        'cycle_started_at': ago(96),
        'last_completed_day':
            date(DateTime.parse(dayKey).subtract(const Duration(days: 1))),
        'last_watered_by': DemoStore.partnerId,
        'watered_at': ago(1)
      }
    ],
    'cozy_garden_actions': [
      entry('water-1', sam, 1, {'day_key': dayKey})
    ],
    'cozy_garden_harvests': [
      {
        'id': 'harvest-1',
        'plant_type': 'sunflower',
        'started_at': ago(300),
        'harvested_at': ago(120),
        'final_growth': 100,
        'streak_at_harvest': 5
      },
      {
        'id': 'harvest-2',
        'plant_type': 'sunflower',
        'started_at': ago(480),
        'harvested_at': ago(310),
        'final_growth': 100,
        'streak_at_harvest': 3
      },
    ],
    'cozy_garden_unlocks': [
      for (final key in [
        'plant:sunflower',
        'plant:sakura',
        'decoration:mushroom',
        'decoration:wooden_sign'
      ])
        {
          'unlock_key': key,
          'unlock_type': key.split(':').first,
          'unlocked_at': ago(120),
          'unlock_source': 'sample_history'
        },
    ],
    'cozy_garden_bonus_events': [],
    'widget_notes': [
      entry('note-1', sam, 2, {
        'storage_path': 'asset:assets/garden/garden_scene.png',
        'caption': 'A garden postcard from Sam (sample artwork)',
      })
    ],
    'photobooth_sessions': [
      for (var i = 0; i < 3; i++)
        entry('album-$i', alex, 24 * (i + 1), {
          'room_name': 'Alex + Sam',
          'created_by': DemoStore.userId,
          'status': 'complete',
          'current_round': 4,
          'total_rounds': 5,
          'participant_frame_style': ['vintage', 'sakura', 'midnight'][i],
        }),
    ],
    'photobooth_photos': [
      for (var i = 0; i < 3; i++)
        for (var round = 0; round < 5; round++)
          for (final author in [alex, sam])
            entry(
                'photo-$i-$round-${author['username']}', author, 24 * (i + 1), {
              'session_id': 'album-$i',
              'round_index': round,
              'storage_path': 'asset:assets/garden/garden_scene.png',
            }),
    ],
  };
}
