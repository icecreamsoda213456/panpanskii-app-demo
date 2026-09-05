class DailyDuoPrompt {
  const DailyDuoPrompt({
    required this.question,
    required this.options,
  });

  final String question;
  final List<String> options;
}

const dailyDuoLegacyPrompts = <DailyDuoPrompt>[
  DailyDuoPrompt(
    question: 'What would make today feel like a good day?',
    options: ['A quiet day', 'A small adventure', 'Good food', 'Time together'],
  ),
  DailyDuoPrompt(
    question: 'What do you need most right now?',
    options: ['Rest', 'Encouragement', 'A laugh', 'A clear plan'],
  ),
  DailyDuoPrompt(
    question: 'How should we spend a free hour together?',
    options: ['Talk', 'Watch something', 'Go outside', 'Make food'],
  ),
  DailyDuoPrompt(
    question: 'What kind of support would feel best today?',
    options: ['Listen to me', 'Make me laugh', 'Give me space', 'Help me plan'],
  ),
  DailyDuoPrompt(
    question: 'Which little joy should we make time for?',
    options: ['Coffee or tea', 'Music', 'A walk', 'A cozy meal'],
  ),
  DailyDuoPrompt(
    question: 'What helps you reset after a busy day?',
    options: ['Silence', 'A shower', 'A hug', 'A favorite show'],
  ),
  DailyDuoPrompt(
    question: 'What should we celebrate today?',
    options: [
      'Small progress',
      'Our effort',
      'A good moment',
      'Just being here',
    ],
  ),
  DailyDuoPrompt(
    question: 'What would make this week feel lighter?',
    options: [
      'Better sleep',
      'Less pressure',
      'More laughter',
      'More time together',
    ],
  ),
  DailyDuoPrompt(
    question: 'What is the best way to reconnect?',
    options: [
      'A real conversation',
      'A shared meal',
      'A walk',
      'A little surprise',
    ],
  ),
  DailyDuoPrompt(
    question: 'What should we protect more in our routine?',
    options: ['Our rest', 'Our time', 'Our peace', 'Our fun'],
  ),
  DailyDuoPrompt(
    question: 'What would you choose for a cozy night?',
    options: ['A movie', 'A long talk', 'A board game', 'Early sleep'],
  ),
  DailyDuoPrompt(
    question: 'What makes you feel most appreciated?',
    options: ['Kind words', 'Quality time', 'Helpful actions', 'A surprise'],
  ),
  DailyDuoPrompt(
    question: 'Where would you rather spend a free afternoon?',
    options: ['At home', 'In nature', 'Somewhere new', 'With good food'],
  ),
  DailyDuoPrompt(
    question: 'What should we do when one of us feels stressed?',
    options: ['Listen quietly', 'Give a hug', 'Make a plan', 'Give some space'],
  ),
  DailyDuoPrompt(
    question: 'What kind of memory should we create soon?',
    options: ['A food trip', 'A long walk', 'A small adventure', 'A lazy day'],
  ),
  DailyDuoPrompt(
    question: 'What is the best way to start the weekend?',
    options: ['Sleep in', 'Go out', 'Cook together', 'Finish errands'],
  ),
  DailyDuoPrompt(
    question: 'Which little thing can improve a difficult day?',
    options: ['A message', 'A snack', 'A nap', 'A good laugh'],
  ),
  DailyDuoPrompt(
    question: 'What would help us feel closer today?',
    options: [
      'Put phones away',
      'Ask a real question',
      'Share a meal',
      'Go outside',
    ],
  ),
  DailyDuoPrompt(
    question: 'What should our next mini adventure include?',
    options: ['New food', 'A new place', 'A photo', 'A surprise plan'],
  ),
  DailyDuoPrompt(
    question: 'Which daily habit should we build together?',
    options: [
      'Morning check-in',
      'Evening walk',
      'Shared journal',
      'Gratitude pause',
    ],
  ),
  DailyDuoPrompt(
    question: 'What feels most comforting after a long day?',
    options: ['Silence', 'A familiar voice', 'Warm food', 'A soft blanket'],
  ),
  DailyDuoPrompt(
    question: 'What should we make more room for this month?',
    options: ['Rest', 'Play', 'Honest talks', 'New experiences'],
  ),
  DailyDuoPrompt(
    question: 'If we could pause time for one hour, what would we do?',
    options: ['Talk', 'Explore', 'Rest', 'Celebrate'],
  ),
  DailyDuoPrompt(
    question: 'What makes teamwork feel easy for you?',
    options: ['Clear plans', 'Patience', 'Shared effort', 'Encouragement'],
  ),
  DailyDuoPrompt(
    question: 'What should we remember during a disagreement?',
    options: ['We are a team', 'Listen first', 'Take a pause', 'Stay gentle'],
  ),
  DailyDuoPrompt(
    question: 'What kind of day would you replay?',
    options: [
      'A peaceful day',
      'A funny day',
      'An adventurous day',
      'A simple day',
    ],
  ),
  DailyDuoPrompt(
    question: 'What is the sweetest way to reconnect after being busy?',
    options: ['A hug', 'A voice call', 'A shared meal', 'A quiet moment'],
  ),
  DailyDuoPrompt(
    question: 'What should we do more often without overthinking it?',
    options: ['Take photos', 'Try new food', 'Say I love you', 'Take a walk'],
  ),
  DailyDuoPrompt(
    question: 'What kind of encouragement helps you keep going?',
    options: [
      'You can do this',
      'I am here',
      'Let us do it together',
      'Take your time',
    ],
  ),
  DailyDuoPrompt(
    question: 'What would make our home feel warmer?',
    options: ['More music', 'More plants', 'More cooking', 'More laughter'],
  ),
];

final List<DailyDuoPrompt> dailyDuoV2Prompts = _buildDailyDuoV2Prompts();

List<DailyDuoPrompt> _buildDailyDuoV2Prompts() {
  final prompts = <DailyDuoPrompt>[...dailyDuoLegacyPrompts];
  final questions = <String>{};
  for (final prompt in prompts) {
    questions.add(prompt.question);
  }

  // Each pack is one topic written five different ways with one answer set.
  // Previously the packs were appended whole, so five consecutive days shared
  // the same options and near-identical questions -- Daily Duo felt like it
  // kept repeating itself. Build the pack portion by question-slot instead
  // (every pack's first phrasing, then every second phrasing, ...), so
  // consecutive days always land on a different pack: a different topic AND a
  // different answer set. A topic's sibling phrasings come back ~359 days
  // later instead of the very next day.
  for (var slot = 0; slot < 5; slot += 1) {
    for (var index = 0; index < _dailyDuoV2Packs.length; index += 1) {
      final pack = _dailyDuoV2Packs[index];
      assert(pack.id == index + 1);
      assert(pack.questions.length == 5);
      assert(pack.options.length == 4);
      assert(pack.options.toSet().length == 4);
      final question = pack.questions[slot];
      assert(question.endsWith('?'));
      assert(questions.add(question));
      prompts.add(DailyDuoPrompt(question: question, options: pack.options));
    }
  }

  assert(_dailyDuoV2Packs.length == 359);
  assert(prompts.length == 1825);
  return List<DailyDuoPrompt>.unmodifiable(prompts);
}

class _PromptPack {
  const _PromptPack(this.id, this.questions, this.options);

  const _PromptPack.named({
    required this.id,
    required this.questions,
    required this.options,
  });

  final int id;
  final List<String> questions;
  final List<String> options;
}

const _dailyDuoV2Packs = <_PromptPack>[
  // Appreciation and connection: 1-20.
  _PromptPack(
    1,
    [
      'Which small gesture would make you feel especially loved today?',
      'What surprise would brighten an ordinary afternoon for you?',
      'Which kind act should we exchange more often?',
      'What would be the sweetest way to say I am thinking of you?',
      'Which gesture belongs in our regular couple routine?',
    ],
    ['A warm note', 'A long hug', 'Helpful action', 'Focused time'],
  ),
  _PromptPack(
    2,
    [
      'Which quality in us makes you proudest of our relationship?',
      'What strength helps us handle difficult weeks together?',
      'Which trait would you want our future selves to keep?',
      'What part of our teamwork deserves more appreciation?',
      'Which shared strength should we celebrate this month?',
    ],
    ['Our patience', 'Our humor', 'Our courage', 'Our kindness'],
  ),
  _PromptPack(
    3,
    [
      'When do you feel most connected to me?',
      'Which moment makes everything between us feel easy?',
      'What kind of time together fills your heart fastest?',
      'Which shared moment helps you feel truly seen?',
      'When does our bond feel strongest to you?',
    ],
    ['Deep talks', 'Quiet cuddles', 'Shared laughter', 'Doing tasks together'],
  ),
  _PromptPack(
    4,
    [
      'What compliment would feel most meaningful this week?',
      'Which part of you would you like me to notice more?',
      'What kind of praise gives you the biggest confidence boost?',
      'Which compliment would stay with you all day?',
      'What should I celebrate about you more openly?',
    ],
    ['My effort', 'My character', 'My talents', 'My growth'],
  ),
  _PromptPack(
    5,
    [
      'Which shared promise matters most in everyday life?',
      'What commitment keeps a relationship feeling secure?',
      'Which promise should guide us during a busy season?',
      'What do you most want us to keep choosing together?',
      'Which quiet commitment says love most clearly?',
    ],
    ['Stay honest', 'Make time', 'Be gentle', 'Keep growing'],
  ),
  _PromptPack(
    6,
    [
      'What makes you feel safest being fully yourself with me?',
      'Which response helps you open up without hesitation?',
      'What creates the most emotional comfort between us?',
      'Which habit makes our relationship feel like a safe place?',
      'What helps you trust that your feelings are welcome?',
    ],
    ['No judgment', 'Patient listening', 'Warm reassurance', 'Honest sharing'],
  ),
  _PromptPack(
    7,
    [
      'Which ordinary moment secretly feels romantic to you?',
      'What simple part of our routine feels special every time?',
      'Which everyday scene would belong in a movie about us?',
      'What small moment makes couple life feel magical?',
      'Which normal activity becomes sweeter because we do it together?',
    ],
    ['Morning greetings', 'Shared meals', 'Errand trips', 'Bedtime talks'],
  ),
  _PromptPack(
    8,
    [
      'How would you most like us to celebrate our next relationship milestone?',
      'Which anniversary plan would feel most like us?',
      'What kind of celebration would make a milestone memorable?',
      'Which way of marking our story sounds sweetest?',
      'How should we honor a big chapter we reach together?',
    ],
    ['Private dinner', 'Weekend trip', 'Memory album', 'Home celebration'],
  ),
  _PromptPack(
    9,
    [
      'Which word best describes the kind of couple we are becoming?',
      'What feeling do you want people to sense around us?',
      'Which quality should define our next chapter together?',
      'What word belongs on the cover of our love story?',
      'Which shared energy feels most true to us?',
    ],
    ['Steady', 'Playful', 'Brave', 'Tender'],
  ),
  _PromptPack(
    10,
    [
      'What would make you feel chosen in a busy week?',
      'Which action best says that you are a priority?',
      'How can we protect our connection when schedules get full?',
      'What would reassure you that us-time still matters?',
      'Which small plan would help us stay close while busy?',
    ],
    ['Plan a date', 'Send check-ins', 'Share one meal', 'End the day together'],
  ),
  _PromptPack(
    11,
    [
      'Which memory of us always brings an instant smile?',
      'What kind of shared moment do you treasure most?',
      'Which chapter of our story feels especially precious?',
      'What memory would you happily tell again years from now?',
      'Which part of our history deserves its own keepsake?',
    ],
    ['First moments', 'Funny mishaps', 'Quiet support', 'Big adventures'],
  ),
  _PromptPack(
    12,
    [
      'What makes an apology feel sincere to you?',
      'Which response helps repair a small misunderstanding?',
      'What matters most when we need to make things right?',
      'Which part of reconnecting after tension feels most healing?',
      'What shows that an apology comes with real care?',
    ],
    ['Clear words', 'Changed action', 'Patient listening', 'Gentle affection'],
  ),
  _PromptPack(
    13,
    [
      'Which part of our relationship feels most worth protecting?',
      'What shared treasure should never get lost in busy life?',
      'Which piece of us deserves the most daily care?',
      'What should remain at the center of our relationship?',
      'Which bond between us feels most precious?',
    ],
    ['Our trust', 'Our friendship', 'Our playfulness', 'Our honesty'],
  ),
  _PromptPack(
    14,
    [
      'How do you most naturally show love without words?',
      'Which quiet action feels like your personal love signature?',
      'What do you tend to do when you deeply care about someone?',
      'Which wordless gesture comes easiest to you?',
      'How can I best recognize your everyday way of loving?',
    ],
    ['Stay nearby', 'Help practically', 'Offer affection', 'Remember details'],
  ),
  _PromptPack(
    15,
    [
      'What would make our next month feel more connected?',
      'Which shared intention should we choose for the coming weeks?',
      'What relationship habit would be most helpful right now?',
      'Which focus could make our daily bond even stronger?',
      'What should we gently practice together this month?',
    ],
    ['More check-ins', 'More dates', 'More patience', 'More laughter'],
  ),
  _PromptPack(
    16,
    [
      'Which kind of affection feels best in public?',
      'What small public gesture feels comfortable and sweet?',
      'How would you like me to show closeness while we are out?',
      'Which simple gesture says we belong together?',
      'What public affection feels most natural for us?',
    ],
    ['Hold hands', 'Arm around me', 'Quick hug', 'Sweet words'],
  ),
  _PromptPack(
    17,
    [
      'What makes you feel most understood by me?',
      'Which sign tells you that I truly know you?',
      'What kind of attention makes you feel deeply recognized?',
      'Which moment proves that I have learned your heart?',
      'What helps you feel known beyond the surface?',
    ],
    [
      'I remember details',
      'I notice moods',
      'I respect needs',
      'I know dreams'
    ],
  ),
  _PromptPack(
    18,
    [
      'Which relationship ritual would you love us to keep for years?',
      'What recurring tradition could become part of our story?',
      'Which little ritual would make ordinary weeks more meaningful?',
      'What should future us still be doing together?',
      'Which couple tradition sounds worth starting now?',
    ],
    ['Monthly date', 'Annual letter', 'Sunday breakfast', 'Nightly check-in'],
  ),
  _PromptPack(
    19,
    [
      'What part of loving someone feels most beautiful to you?',
      'Which side of partnership brings you the most joy?',
      'What makes sharing life with someone feel worthwhile?',
      'Which part of being a team feels especially meaningful?',
      'What is your favorite gift that a relationship can give?',
    ],
    ['Being known', 'Growing together', 'Sharing joy', 'Having support'],
  ),
  _PromptPack(
    20,
    [
      'Which sentence would you most like to hear from me today?',
      'What reassurance would settle your heart right now?',
      'Which loving reminder would feel especially timely?',
      'What words could make today feel softer?',
      'Which message would you save and reread later?',
    ],
    ['I believe in you', 'I choose you', 'I appreciate you', 'I am here'],
  ),

  // Communication and support: 21-40.
  _PromptPack(
    21,
    [
      'How should I respond when you need to vent?',
      'What helps you feel heard during a frustrating story?',
      'Which kind of listening feels most supportive after a hard day?',
      'What should I offer first when something bothers you?',
      'How can I make space for your feelings most effectively?',
    ],
    ['Just listen', 'Ask questions', 'Offer comfort', 'Help solve it'],
  ),
  _PromptPack(
    22,
    [
      'What is the gentlest way to begin a difficult conversation?',
      'Which opening helps serious talks feel less scary?',
      'How should we signal that a sensitive topic needs care?',
      'What first step keeps an honest conversation calm?',
      'Which approach makes it easier to discuss something important?',
    ],
    ['Ask for time', 'Start with care', 'Write it first', 'Take a walk'],
  ),
  _PromptPack(
    23,
    [
      'What should we do when both of us are overwhelmed?',
      'Which reset would help us during a chaotic evening?',
      'How can we pause before stress turns into tension?',
      'What shared response works best when everything feels like too much?',
      'Which calm-down plan should be our emergency default?',
    ],
    ['Take ten minutes', 'Sit together', 'Handle one task', 'Rest first'],
  ),
  _PromptPack(
    24,
    [
      'How do you prefer to receive advice?',
      'What makes guidance feel caring instead of controlling?',
      'Which style of suggestion is easiest for you to hear?',
      'How should I share an idea when you are unsure?',
      'What kind of advice feels most respectful?',
    ],
    ['Give choices', 'Be direct', 'Ask permission', 'Share an example'],
  ),
  _PromptPack(
    25,
    [
      'What helps you speak honestly when you feel nervous?',
      'Which response makes vulnerable sharing easier?',
      'How can I show that difficult feelings are safe with me?',
      'What creates courage for a very honest conversation?',
      'Which kind of support helps you say what is really on your mind?',
    ],
    ['A calm tone', 'No interruptions', 'Gentle touch', 'Extra time'],
  ),
  _PromptPack(
    26,
    [
      'Which check-in question would serve us best each week?',
      'What should we ask each other before a new week begins?',
      'Which question could prevent small needs from being missed?',
      'What weekly conversation would keep us connected?',
      'Which check-in belongs in our relationship routine?',
    ],
    [
      'How are we?',
      'What do you need?',
      'What felt good?',
      'What can improve?'
    ],
  ),
  _PromptPack(
    27,
    [
      'How should we divide tasks when one person has less energy?',
      'What teamwork approach feels fairest on difficult days?',
      'Which plan helps us handle chores without resentment?',
      'How can we adjust when one of us is carrying more stress?',
      'What should matter most when sharing responsibilities?',
    ],
    ['Trade tasks', 'Do them together', 'Delay nonurgent work', 'Ask directly'],
  ),
  _PromptPack(
    28,
    [
      'What kind of reminder helps without adding pressure?',
      'How should I nudge you about something important?',
      'Which reminder style feels most respectful?',
      'What makes a repeated request easier to receive?',
      'How can we help each other remember plans kindly?',
    ],
    ['Gentle message', 'Shared calendar', 'One clear ask', 'Friendly joke'],
  ),
  _PromptPack(
    29,
    [
      'What helps you recover after saying something the wrong way?',
      'Which repair step matters most after words come out poorly?',
      'How should we reconnect after a clumsy comment?',
      'What makes a communication mistake feel fixable?',
      'Which response turns an awkward moment into understanding?',
    ],
    [
      'Clarify meaning',
      'Own the impact',
      'Apologize quickly',
      'Try again calmly'
    ],
  ),
  _PromptPack(
    30,
    [
      'Which kind of silence feels comfortable between us?',
      'When does being quiet together feel most connected?',
      'What shared quiet moment would you enjoy today?',
      'Which setting makes peaceful silence feel natural?',
      'When would you rather share presence than conversation?',
    ],
    ['During a drive', 'Before sleep', 'Over coffee', 'While outdoors'],
  ),
  _PromptPack(
    31,
    [
      'How can I support you before an important event?',
      'What would help you feel steady before a big moment?',
      'Which kind of encouragement is best before a challenge?',
      'What should I offer when you are preparing for something important?',
      'How can we make your next big day feel less stressful?',
    ],
    [
      'Practice together',
      'Give a pep talk',
      'Handle details',
      'Stay quietly close'
    ],
  ),
  _PromptPack(
    32,
    [
      'What should we do when our plans suddenly change?',
      'Which response helps disappointment pass more easily?',
      'How can we stay on the same team when a plan falls apart?',
      'What would make an unexpected change feel manageable?',
      'Which backup approach suits us best?',
    ],
    [
      'Make a new plan',
      'Laugh about it',
      'Rest instead',
      'Choose spontaneously'
    ],
  ),
  _PromptPack(
    33,
    [
      'Which boundary helps you feel healthiest in a relationship?',
      'What personal space is important for you to protect?',
      'Which kind of independence strengthens our bond?',
      'What should partners respect even when they are very close?',
      'Which boundary makes togetherness feel more balanced?',
    ],
    ['Alone time', 'Private hobbies', 'Friend time', 'Quiet thinking'],
  ),
  _PromptPack(
    34,
    [
      'What helps you feel calm during a disagreement?',
      'Which signal should we use when a conversation gets too heated?',
      'How can we keep a conflict respectful?',
      'What should we prioritize when our opinions differ?',
      'Which agreement would make hard talks safer?',
    ],
    ['Lower voices', 'Pause briefly', 'Hold hands', 'Stick to one topic'],
  ),
  _PromptPack(
    35,
    [
      'How do you want good news celebrated?',
      'What response makes sharing an achievement extra joyful?',
      'Which reaction would make you feel cheered on?',
      'How should I celebrate your next win?',
      'What kind of excitement feels most supportive?',
    ],
    ['Big enthusiasm', 'A special treat', 'Proud words', 'A quiet hug'],
  ),
  _PromptPack(
    36,
    [
      'What is the best way to ask for reassurance?',
      'Which phrase makes an emotional need clear?',
      'How can we request comfort without guessing games?',
      'What kind of honest ask feels easiest to make?',
      'Which request would help us respond to each other faster?',
    ],
    [
      'Can you listen?',
      'Can I have a hug?',
      'Can we talk?',
      'Can you stay close?'
    ],
  ),
  _PromptPack(
    37,
    [
      'What should we talk about before making a big shared decision?',
      'Which question matters most when choosing something together?',
      'What keeps major decisions fair to both people?',
      'Which step prevents rushed choices as a couple?',
      'How should we approach a decision that affects both of us?',
    ],
    ['Our priorities', 'Possible tradeoffs', 'Each concern', 'A backup plan'],
  ),
  _PromptPack(
    38,
    [
      'How can we make texting feel more connected on busy days?',
      'Which message would you enjoy receiving during work?',
      'What kind of digital check-in feels caring without being distracting?',
      'Which tiny message could improve a long day apart?',
      'How should we stay close when there is little time to chat?',
    ],
    ['A sweet photo', 'A voice note', 'One loving line', 'A funny update'],
  ),
  _PromptPack(
    39,
    [
      'Which topic would you like us to understand better about each other?',
      'What part of your inner world deserves a deeper conversation?',
      'Which subject could bring us closer if we explored it?',
      'What would you like me to ask more about?',
      'Which conversation feels worth making time for soon?',
    ],
    ['Our fears', 'Our dreams', 'Our values', 'Our daily needs'],
  ),
  _PromptPack(
    40,
    [
      'What makes feedback easier for you to accept?',
      'How should I raise a small concern with care?',
      'Which approach helps constructive honesty feel loving?',
      'What keeps feedback from feeling like criticism?',
      'How can we help each other improve without hurting confidence?',
    ],
    ['Choose timing', 'Use kind words', 'Be specific', 'Offer support'],
  ),

  // Funny, silly, and playful: 41-60.
  _PromptPack(
    41,
    [
      'If our relationship had a mascot, what would it be?',
      'Which animal best matches our couple energy?',
      'What creature would represent our funniest habits?',
      'Which mascot should appear on our imaginary team flag?',
      'What animal duo feels suspiciously like us?',
    ],
    ['Sleepy cats', 'Happy otters', 'Chaotic ducks', 'Loyal penguins'],
  ),
  _PromptPack(
    42,
    [
      'Which ridiculous competition would you most want to win against me?',
      'What silly tournament should we hold at home?',
      'Which challenge would reveal our true competitive sides?',
      'What harmless contest would make us laugh hardest?',
      'Which championship title belongs in our household?',
    ],
    ['Pillow building', 'Snack stacking', 'Funny faces', 'Sock basketball'],
  ),
  _PromptPack(
    43,
    [
      'If we switched voices for a day, what would be funniest?',
      'Which daily moment would become comedy with swapped voices?',
      'What would you say first using my voice?',
      'Where would our voice swap cause the most confusion?',
      'Which conversation would be impossible to finish seriously?',
    ],
    [
      'Ordering food',
      'Calling a friend',
      'Singing together',
      'Morning greetings'
    ],
  ),
  _PromptPack(
    44,
    [
      'Which strange pet would we be best at raising?',
      'What unusual animal would fit our home energy?',
      'Which imaginary pet would become the spoiled favorite?',
      'What creature would make our daily routine most interesting?',
      'Which pet would create the funniest couple stories?',
    ],
    ['Tiny dragon', 'Talking parrot', 'Mini goat', 'Giant rabbit'],
  ),
  _PromptPack(
    45,
    [
      'If our kitchen became a game show, what round would we dominate?',
      'Which cooking challenge would be funniest for us?',
      'What food contest would reveal our teamwork?',
      'Which kitchen round would create the biggest mess?',
      'What imaginary cooking trophy could we actually win?',
    ],
    [
      'Mystery leftovers',
      'Fastest sandwich',
      'Best pancake art',
      'Blind taste test'
    ],
  ),
  _PromptPack(
    46,
    [
      'Which tiny inconvenience turns you into a dramatic character?',
      'What harmless problem deserves your biggest fake complaint?',
      'Which daily annoyance makes you act like the world has ended?',
      'What small struggle brings out your funniest reaction?',
      'Which inconvenience should get its own dramatic soundtrack?',
    ],
    ['Slow internet', 'Missing charger', 'Wet socks', 'Empty snack bag'],
  ),
  _PromptPack(
    47,
    [
      'If we had a secret handshake, what should it include?',
      'Which move belongs in our official couple greeting?',
      'What would make our handshake impossible to copy?',
      'Which ending should complete our silly greeting ritual?',
      'What gesture would make us laugh every time we meet?',
    ],
    ['Finger snap', 'Tiny dance', 'Double high-five', 'Heart hands'],
  ),
  _PromptPack(
    48,
    [
      'Which role would you play in a very unserious heist movie?',
      'What job would fit you in our imaginary caper team?',
      'Which heist role would create the funniest chaos?',
      'Who would you become in a movie about stealing the last dessert?',
      'Which secret skill would you bring to our pretend mission?',
    ],
    ['The planner', 'The distraction', 'The driver', 'The snack expert'],
  ),
  _PromptPack(
    49,
    [
      'What would our couple warning label say?',
      'Which notice should come with spending a day around us?',
      'What funny sign belongs outside our shared space?',
      'Which label best explains our combined energy?',
      'What disclaimer should appear before our home videos?',
    ],
    [
      'May start dancing',
      'Always needs snacks',
      'Laughs too loudly',
      'Plans may change'
    ],
  ),
  _PromptPack(
    50,
    [
      'Which useless superpower would you happily accept?',
      'What tiny magical ability would improve your daily life?',
      'Which silly power would you show off constantly?',
      'What low-stakes superpower suits your personality?',
      'Which harmless ability would make our routines funnier?',
    ],
    ['Perfect toast', 'Find lost socks', 'Refill drinks', 'Skip every queue'],
  ),
  _PromptPack(
    51,
    [
      'If our couch could talk, what would it reveal?',
      'Which secret has our favorite seat witnessed most often?',
      'What story would the living room furniture tell about us?',
      'Which habit would our couch complain about first?',
      'What compliment would our couch give our relationship?',
    ],
    ['Too many naps', 'Endless shows', 'Great cuddles', 'Constant snacks'],
  ),
  _PromptPack(
    52,
    [
      'Which outfit theme should we wear for a silly date?',
      'What matching look would make the funniest photos?',
      'Which costume rule would turn errands into an adventure?',
      'What clothing theme would challenge our confidence?',
      'Which coordinated style could we secretly pull off?',
    ],
    ['One bright color', 'Retro outfits', 'Fancy clothes', 'Matching pajamas'],
  ),
  _PromptPack(
    53,
    [
      'If one household object became haunted, which would be funniest?',
      'What object would make the least frightening ghost?',
      'Which haunted item would cause harmless daily chaos?',
      'What spooky household companion could we tolerate?',
      'Which object would deliver the funniest supernatural messages?',
    ],
    ['The toaster', 'A desk lamp', 'The broom', 'A throw pillow'],
  ),
  _PromptPack(
    54,
    [
      'Which sound effect should play whenever you enter a room?',
      'What audio cue best matches your everyday energy?',
      'Which noise would announce your arrival most accurately?',
      'What soundtrack detail should follow you for a day?',
      'Which sound would make your entrances impossible to ignore?',
    ],
    ['Tiny applause', 'Dramatic drums', 'Cartoon sparkle', 'Happy whistle'],
  ),
  _PromptPack(
    55,
    [
      'What would we name a boat we definitely do not own?',
      'Which name belongs on our imaginary yacht?',
      'What boat name captures our couple humor?',
      'Which title would look funniest on a tiny canoe?',
      'What should our dream vessel be called?',
    ],
    ['The Cozy Chaos', 'Snack Aboard', 'Two of Us', 'Maybe Tomorrow'],
  ),
  _PromptPack(
    56,
    [
      'Which dance move should become our signature?',
      'What move would make our kitchen dance breaks memorable?',
      'Which dance could we perform with absolutely no skill?',
      'What should we do when our favorite song suddenly plays?',
      'Which move belongs in every celebration together?',
    ],
    ['The slow spin', 'The shoulder wiggle', 'The robot', 'Wild freestyle'],
  ),
  _PromptPack(
    57,
    [
      'If we opened a ridiculous business, what would we sell?',
      'Which silly shop could we run surprisingly well?',
      'What imaginary business matches our combined talents?',
      'Which store would attract the most unusual customers?',
      'What product would make us questionable entrepreneurs?',
    ],
    ['Custom excuses', 'Fancy sandwiches', 'Pet hats', 'Nap appointments'],
  ),
  _PromptPack(
    58,
    [
      'Which fictional rule should our home adopt for one day?',
      'What temporary house law would create the most fun?',
      'Which rule would turn an ordinary evening into a game?',
      'What silly policy should everyone at home follow?',
      'Which one-day rule deserves an official announcement?',
    ],
    [
      'Only sing replies',
      'Wear a blanket cape',
      'Dessert comes first',
      'No walking normally'
    ],
  ),
  _PromptPack(
    59,
    [
      'What should we put in a time capsule purely to confuse people?',
      'Which object would make future historians ask questions?',
      'What silly item deserves to represent our era?',
      'Which keepsake would become funnier after fifty years?',
      'What would make our time capsule delightfully mysterious?',
    ],
    [
      'A weird receipt',
      'One lonely sock',
      'A snack wrapper',
      'An inside-joke note'
    ],
  ),
  _PromptPack(
    60,
    [
      'Which everyday task deserves an epic movie montage?',
      'What boring activity should get dramatic music?',
      'Which chore would look heroic in slow motion?',
      'What routine task could become our action scene?',
      'Which normal moment deserves cinematic editing?',
    ],
    ['Washing dishes', 'Buying groceries', 'Folding clothes', 'Making the bed'],
  ),
  // Cozy moments and daily life: 61-80.
  _PromptPack(
    61,
    [
      'What would make the coziest start to a slow morning?',
      'Which morning plan would help us ease into the day?',
      'How should we spend the first hour of a free day?',
      'Which simple ritual would make waking up together sweeter?',
      'What belongs in our ideal unhurried morning?',
    ],
    ['Breakfast in bed', 'Coffee by a window', 'A quiet walk', 'Extra cuddles'],
  ),
  _PromptPack(
    62,
    [
      'Which rainy-day activity sounds best for us?',
      'How should we enjoy an afternoon when the weather keeps us inside?',
      'What would turn a gray day into a cozy memory?',
      'Which indoor plan fits the sound of rain?',
      'What should we reach for during our next rainy weekend?',
    ],
    ['Bake something', 'Watch movies', 'Play games', 'Read together'],
  ),
  _PromptPack(
    63,
    [
      'What should our perfect bedtime routine include?',
      'Which nighttime habit would help us end the day gently?',
      'What would make evenings feel calmer together?',
      'Which ritual could improve our sleep and connection?',
      'How should we close an especially busy day?',
    ],
    [
      'Share highlights',
      'Stretch quietly',
      'Listen to music',
      'Cuddle without phones'
    ],
  ),
  _PromptPack(
    64,
    [
      'Which household chore is least unpleasant when we do it together?',
      'What task could become decent couple time?',
      'Which chore should always be a two-person mission?',
      'What home job feels lighter with company?',
      'Which task could use a shared playlist and teamwork?',
    ],
    [
      'Cooking cleanup',
      'Laundry folding',
      'Room organizing',
      'Grocery planning'
    ],
  ),
  _PromptPack(
    65,
    [
      'What kind of break would help us reset this afternoon?',
      'Which pause would bring the most energy back?',
      'How should we spend fifteen free minutes together?',
      'What quick reset could improve the rest of our day?',
      'Which mini-break sounds most refreshing right now?',
    ],
    ['Fresh air', 'A short nap', 'Tea and talk', 'One funny video'],
  ),
  _PromptPack(
    66,
    [
      'Which sound makes a home feel instantly cozier?',
      'What background sound belongs in our shared space?',
      'Which audio atmosphere would make tonight more peaceful?',
      'What should be playing during a quiet evening at home?',
      'Which familiar sound gives you the strongest home feeling?',
    ],
    ['Soft music', 'Rain sounds', 'Cooking noises', 'Comfortable silence'],
  ),
  _PromptPack(
    67,
    [
      'What would improve our usual grocery trip?',
      'Which twist could turn errands into a tiny date?',
      'How should we make shopping together more enjoyable?',
      'What rule would add fun to our next grocery run?',
      'Which errand upgrade sounds most like us?',
    ],
    [
      'Pick a surprise snack',
      'Use a shared list',
      'Try one new item',
      'Get a treat after'
    ],
  ),
  _PromptPack(
    68,
    [
      'Which corner of a home matters most for feeling relaxed?',
      'What space would you make extra comfortable first?',
      'Where should a shared home invest its coziest details?',
      'Which room should feel like our main retreat?',
      'What home area deserves the softest lighting and best pillows?',
    ],
    ['The bedroom', 'The living room', 'The kitchen', 'A small reading nook'],
  ),
  _PromptPack(
    69,
    [
      'What would make a regular weekday evening feel special?',
      'Which small plan could rescue a boring Tuesday?',
      'How should we add a little joy to an ordinary night?',
      'What easy activity could become a midweek tradition?',
      'Which weekday treat would you look forward to most?',
    ],
    ['Favorite takeout', 'Sunset walk', 'Mini game night', 'Dessert and music'],
  ),
  _PromptPack(
    70,
    [
      'Which kind of lighting feels coziest at home?',
      'What glow would set the best mood for a quiet night?',
      'Which light belongs in our dream living space?',
      'How should we illuminate a peaceful evening together?',
      'What lighting would make our home feel warmest?',
    ],
    ['Warm lamps', 'Fairy lights', 'Candlelight', 'Morning sunshine'],
  ),
  _PromptPack(
    71,
    [
      'What is your favorite way to share space while doing separate things?',
      'Which parallel activity feels quietly connected?',
      'How can we enjoy togetherness without needing the same task?',
      'Which side-by-side moment sounds most peaceful?',
      'What independent activity still feels like quality time nearby?',
    ],
    [
      'Read beside each other',
      'Work with music',
      'Do separate hobbies',
      'Relax on one couch'
    ],
  ),
  _PromptPack(
    72,
    [
      'Which simple item makes a room feel more welcoming?',
      'What detail would you add first to a cozy apartment?',
      'Which home touch creates the most warmth?',
      'What small decoration improves a shared space fastest?',
      'Which detail makes you want to stay home longer?',
    ],
    ['Soft blankets', 'Green plants', 'Framed photos', 'A good lamp'],
  ),
  _PromptPack(
    73,
    [
      'How should we handle a completely lazy day?',
      'What plan best honors a day with zero ambition?',
      'Which low-energy schedule sounds most satisfying?',
      'What would make doing almost nothing feel perfect?',
      'How should we spend a day when rest is the only goal?',
    ],
    ['Stay in pajamas', 'Order everything', 'Nap freely', 'Move to the couch'],
  ),
  _PromptPack(
    74,
    [
      'What should we do with an unexpected free evening?',
      'Which spontaneous plan suits a surprise opening in our schedule?',
      'How would you use three bonus hours together?',
      'Which option would make an unplanned night memorable?',
      'What should win when our plans suddenly disappear?',
    ],
    [
      'Go somewhere nearby',
      'Cook a new meal',
      'Have a home date',
      'Rest without guilt'
    ],
  ),
  _PromptPack(
    75,
    [
      'Which smell makes a place feel like home?',
      'What scent would you want in our shared kitchen?',
      'Which aroma creates the coziest memory for you?',
      'What should our dream home smell like on a good day?',
      'Which familiar scent helps you relax fastest?',
    ],
    ['Fresh coffee', 'Clean laundry', 'Baked bread', 'Rainy air'],
  ),
  _PromptPack(
    76,
    [
      'What is the best way to spend time during a power outage?',
      'Which no-electricity plan could become a lovely memory?',
      'How would we keep ourselves entertained without screens?',
      'What should we do if the lights go out tonight?',
      'Which quiet activity fits an evening by flashlight?',
    ],
    ['Tell stories', 'Play cards', 'Watch the sky', 'Eat all the snacks'],
  ),
  _PromptPack(
    77,
    [
      'Which daily moment deserves more of our attention?',
      'What routine part of the day could feel less rushed?',
      'Which ordinary moment should we slow down and enjoy?',
      'Where could we add ten minutes of real connection?',
      'Which part of our schedule holds hidden quality time?',
    ],
    ['Breakfast', 'Travel time', 'Dinner', 'Before sleep'],
  ),
  _PromptPack(
    78,
    [
      'What would make our next cleaning day more fun?',
      'Which reward could motivate a serious home reset?',
      'How should we turn tidying into a team event?',
      'What addition would make chores feel less dull?',
      'Which cleaning-day rule should we adopt?',
    ],
    ['Loud playlist', 'Snack breaks', 'Race the timer', 'Reward meal'],
  ),
  _PromptPack(
    79,
    [
      'Which kind of blanket-sharing arrangement is fairest?',
      'What should happen when one person steals the covers?',
      'Which sleep solution would preserve nighttime peace?',
      'How should a cozy couple settle the blanket debate?',
      'What bedding plan sounds most comfortable for us?',
    ],
    [
      'One giant blanket',
      'Two separate blankets',
      'Take turns stealing',
      'Add an extra blanket'
    ],
  ),
  _PromptPack(
    80,
    [
      'What would make Sunday evening feel less heavy?',
      'Which ritual could create a gentler end to the weekend?',
      'How should we prepare for Monday without losing our peace?',
      'What Sunday-night plan would help the new week start well?',
      'Which habit could make the weekend goodbye feel softer?',
    ],
    [
      'Plan one good thing',
      'Prepare together',
      'Have an early dinner',
      'Watch something cozy'
    ],
  ),

  // Food and drinks: 81-100.
  _PromptPack(
    81,
    [
      'Which breakfast would you choose for a special morning together?',
      'What should we cook when we want breakfast to feel like a date?',
      'Which morning meal would be worth waking up early for?',
      'What breakfast belongs on our shared favorites list?',
      'Which dish would make a sleepy morning instantly better?',
    ],
    ['Fluffy pancakes', 'Savory rice meal', 'Eggs and toast', 'Fresh pastries'],
  ),
  _PromptPack(
    82,
    [
      'Which comfort food would you bring me after a rough day?',
      'What meal feels most like a warm hug?',
      'Which dish should we keep as an emergency mood-lifter?',
      'What food would make a stressful evening gentler?',
      'Which cozy meal should enter our regular rotation?',
    ],
    ['Hot soup', 'Creamy pasta', 'Rice and favorites', 'Grilled sandwiches'],
  ),
  _PromptPack(
    83,
    [
      'What dessert should we learn to make together?',
      'Which sweet challenge would be most fun in our kitchen?',
      'What homemade dessert would impress our future guests?',
      'Which treat should become our couple specialty?',
      'What dessert would produce the best taste-testing session?',
    ],
    ['Cheesecake', 'Chocolate cookies', 'Fruit tart', 'Ice cream'],
  ),
  _PromptPack(
    84,
    [
      'Which street food crawl sounds most exciting?',
      'What snack should start a walking food date?',
      'Which street-food category would you happily sample all afternoon?',
      'What quick bite deserves a place on our food adventure list?',
      'Which food-stall stop would be hardest to skip?',
    ],
    ['Grilled snacks', 'Fried favorites', 'Sweet treats', 'Noodle bowls'],
  ),
  _PromptPack(
    85,
    [
      'What drink best matches a long conversation?',
      'Which beverage belongs beside our next deep talk?',
      'What should we sip during a quiet catch-up?',
      'Which drink creates the best conversation mood?',
      'What would you order for an unhurried cafe date?',
    ],
    ['Hot coffee', 'Milk tea', 'Fresh juice', 'Warm chocolate'],
  ),
  _PromptPack(
    86,
    [
      'Which cuisine should we explore on our next dinner date?',
      'What food culture would you like to taste more deeply?',
      'Which menu would make a fun themed night at home?',
      'What cuisine should inspire our next cooking experiment?',
      'Which flavor journey sounds best this month?',
    ],
    ['Japanese', 'Italian', 'Korean', 'Mexican'],
  ),
  _PromptPack(
    87,
    [
      'What is the best way to choose from a huge menu?',
      'Which ordering strategy should we use at a new restaurant?',
      'How can we avoid regretting our food choices?',
      'What approach makes restaurant decisions more fun?',
      'Which menu rule sounds most sensible for us?',
    ],
    [
      'Share several dishes',
      'Ask the server',
      'Pick house specials',
      'Choose for each other'
    ],
  ),
  _PromptPack(
    88,
    [
      'Which picnic food is absolutely essential?',
      'What should take the most space in our picnic basket?',
      'Which item would make an outdoor meal complete?',
      'What food belongs at our dream park picnic?',
      'Which picnic category would you plan first?',
    ],
    ['Good sandwiches', 'Fresh fruit', 'Crunchy snacks', 'Something sweet'],
  ),
  _PromptPack(
    89,
    [
      'What midnight snack would you gladly share?',
      'Which late-night bite is worth leaving bed for?',
      'What snack should be stocked for after-hours cravings?',
      'Which food fits a quiet midnight kitchen visit?',
      'What should we split during a very late movie?',
    ],
    ['Instant noodles', 'Toast and spread', 'Cold leftovers', 'Chips and dip'],
  ),
  _PromptPack(
    90,
    [
      'Which flavor combination sounds surprisingly good?',
      'What unusual pairing would you be brave enough to try?',
      'Which sweet-and-savory mix could win you over?',
      'What strange snack deserves one honest taste test?',
      'Which flavor experiment should we attempt together?',
    ],
    [
      'Cheese and honey',
      'Chocolate and chili',
      'Fruit and salt',
      'Fries and ice cream'
    ],
  ),
  _PromptPack(
    91,
    [
      'What should we cook when the refrigerator looks nearly empty?',
      'Which simple meal saves the day with limited ingredients?',
      'What is our best backup dinner when plans fail?',
      'Which low-effort dish should every couple know?',
      'What meal can rescue a hungry, tired evening?',
    ],
    ['Egg fried rice', 'Quick pasta', 'Loaded toast', 'Creative omelet'],
  ),
  _PromptPack(
    92,
    [
      'Which food smell would tempt you from another room?',
      'What aroma makes waiting for dinner hardest?',
      'Which cooking scent creates instant hunger?',
      'What smell should fill our kitchen on a celebration day?',
      'Which delicious aroma is impossible for you to ignore?',
    ],
    ['Garlic sizzling', 'Bread baking', 'Meat grilling', 'Chocolate melting'],
  ),
  _PromptPack(
    93,
    [
      'What restaurant atmosphere makes a date feel special?',
      'Which setting would you choose for a memorable dinner?',
      'What dining mood helps you enjoy a meal most?',
      'Which restaurant style feels most romantic to you?',
      'Where would conversation flow best over dinner?',
    ],
    [
      'Cozy and quiet',
      'Lively and casual',
      'Outdoor and breezy',
      'Elegant and dim'
    ],
  ),
  _PromptPack(
    94,
    [
      'Which ingredient would you never want on your pizza?',
      'What topping could ruin an otherwise perfect slice?',
      'Which pizza addition would require serious negotiation?',
      'What ingredient belongs far away from our pizza order?',
      'Which topping would you remove before taking a bite?',
    ],
    ['Pineapple', 'Olives', 'Anchovies', 'Too much onion'],
  ),
  _PromptPack(
    95,
    [
      'Which food gift would make you happiest?',
      'What edible surprise would feel especially thoughtful?',
      'Which treat would you love to receive for no reason?',
      'What food delivery would instantly improve your mood?',
      'Which delicious present says I know you well?',
    ],
    ['Favorite pastry', 'Snack box', 'Home-cooked meal', 'Fancy fruit'],
  ),
  _PromptPack(
    96,
    [
      'What should be the first recipe in our couple cookbook?',
      'Which dish best represents our shared taste?',
      'What meal deserves to become our signature recipe?',
      'Which food memory should inspire a written recipe?',
      'What would belong on page one of our kitchen story?',
    ],
    [
      'Comfort breakfast',
      'Favorite dinner',
      'Celebration dessert',
      'Family recipe'
    ],
  ),
  _PromptPack(
    97,
    [
      'Which cafe detail matters most for a good date?',
      'What makes a coffee-shop visit worth lingering over?',
      'Which feature would define our perfect neighborhood cafe?',
      'What would make us return to the same cafe often?',
      'Which cafe quality improves conversation the most?',
    ],
    ['Great drinks', 'Comfortable seats', 'Quiet music', 'Tasty pastries'],
  ),
  _PromptPack(
    98,
    [
      'What meal would you choose for a celebration at home?',
      'Which dinner makes an ordinary table feel festive?',
      'What should we serve after reaching a shared goal?',
      'Which homemade feast would mark a happy occasion?',
      'What celebration menu would feel most satisfying?',
    ],
    [
      'Favorite takeout spread',
      'Homemade pasta',
      'Grill night',
      'Breakfast for dinner'
    ],
  ),
  _PromptPack(
    99,
    [
      'Which food texture do you enjoy most?',
      'What kind of bite makes a snack especially satisfying?',
      'Which texture would guide your ideal comfort meal?',
      'What mouthfeel makes you return for another serving?',
      'Which texture wins when flavor choices are equal?',
    ],
    ['Extra crispy', 'Soft and fluffy', 'Rich and creamy', 'Fresh and chewy'],
  ),
  _PromptPack(
    100,
    [
      'What should we order when neither of us can decide?',
      'Which fallback food works for almost any mood?',
      'What reliable meal could settle our next dinner debate?',
      'Which choice is safest when hunger has ruined decision-making?',
      'What universal favorite should be our default order?',
    ],
    ['Pizza', 'Burgers', 'Noodles', 'Rice bowls'],
  ),
  // Travel and adventures: 101-120.
  _PromptPack(
    101,
    [
      'Which landscape would you most like to wake up beside?',
      'What view should greet us on a dream vacation morning?',
      'Which natural setting would make you forget your phone?',
      'Where would a quiet sunrise feel most unforgettable?',
      'Which destination view belongs on our travel wish list?',
    ],
    ['Ocean horizon', 'Mountain valley', 'Forest lake', 'City skyline'],
  ),
  _PromptPack(
    102,
    [
      'What style of trip fits us best right now?',
      'Which vacation pace would leave us happiest?',
      'How should our next getaway balance plans and freedom?',
      'What travel rhythm sounds most enjoyable together?',
      'Which itinerary style would prevent vacation stress?',
    ],
    [
      'Fully planned',
      'Mostly spontaneous',
      'One plan per day',
      'Total relaxation'
    ],
  ),
  _PromptPack(
    103,
    [
      'Which road-trip role would you rather take?',
      'What job would you claim during a long drive?',
      'Which responsibility suits you best on the open road?',
      'How would you contribute to our road-trip team?',
      'Which role would make the journey smoother?',
    ],
    ['Drive', 'Navigate', 'Choose music', 'Manage snacks'],
  ),
  _PromptPack(
    104,
    [
      'What should we do first after arriving somewhere new?',
      'Which arrival ritual helps you settle into a destination?',
      'How should we begin our first hour in a new city?',
      'What is the best way to get oriented on a trip?',
      'Which first activity starts a vacation well?',
    ],
    ['Walk nearby', 'Find local food', 'Rest at the hotel', 'Visit a landmark'],
  ),
  _PromptPack(
    105,
    [
      'Which travel souvenir is most worth bringing home?',
      'What keepsake best captures a place we visited?',
      'Which item would help a trip live in our memory?',
      'What should we collect from future adventures?',
      'Which souvenir would you enjoy finding together?',
    ],
    ['Local artwork', 'A small magnet', 'Food to share', 'Printed photos'],
  ),
  _PromptPack(
    106,
    [
      'What kind of beach day sounds ideal?',
      'Which seaside plan would make you happiest?',
      'How should we spend a full day by the water?',
      'What belongs in our perfect coastal escape?',
      'Which beach activity would you choose first?',
    ],
    ['Swim all day', 'Read in shade', 'Walk the shore', 'Try water sports'],
  ),
  _PromptPack(
    107,
    [
      'Which mountain activity would you most enjoy together?',
      'What should we do during a cool highland getaway?',
      'Which elevated adventure fits our energy?',
      'How would you spend a day surrounded by mountains?',
      'What mountain memory should we create someday?',
    ],
    ['Scenic hike', 'Cabin rest', 'Viewpoint picnic', 'Cable-car ride'],
  ),
  _PromptPack(
    108,
    [
      'What is the most important item to pack for comfort?',
      'Which travel essential would you double-check before leaving?',
      'What forgotten item could affect your whole trip?',
      'Which thing earns the safest place in your luggage?',
      'What should always be ready in our travel bag?',
    ],
    ['Comfortable shoes', 'Phone charger', 'Favorite jacket', 'Basic medicine'],
  ),
  _PromptPack(
    109,
    [
      'Which kind of city would you most like to explore?',
      'What urban destination sounds exciting for a couple trip?',
      'Which city atmosphere would keep us wandering all day?',
      'What kind of streets would you enjoy getting lost in?',
      'Which city personality matches your travel mood?',
    ],
    [
      'Historic and quiet',
      'Modern and lively',
      'Artistic and colorful',
      'Coastal and relaxed'
    ],
  ),
  _PromptPack(
    110,
    [
      'What would make a long airport wait easier?',
      'Which activity could turn a delay into decent couple time?',
      'How should we pass three unexpected hours at a terminal?',
      'What travel-delay plan would keep us cheerful?',
      'Which airport pastime sounds least boring?',
    ],
    [
      'Find good food',
      'Play phone games',
      'People-watch',
      'Take turns napping'
    ],
  ),
  _PromptPack(
    111,
    [
      'Which kind of local experience matters most while traveling?',
      'What helps you feel that you truly visited a place?',
      'Which activity reveals the heart of a destination?',
      'What should we prioritize beyond famous attractions?',
      'Which local connection would make a trip richer?',
    ],
    [
      'Eat local dishes',
      'Talk with residents',
      'Visit a market',
      'Learn some history'
    ],
  ),
  _PromptPack(
    112,
    [
      'How early would you wake up for a travel experience?',
      'Which morning adventure is worth losing sleep for?',
      'What could convince you to leave a hotel before sunrise?',
      'Which early activity belongs on a special trip?',
      'What dawn experience would feel worth the alarm?',
    ],
    ['Sunrise view', 'Wildlife tour', 'Empty landmarks', 'Breakfast market'],
  ),
  _PromptPack(
    113,
    [
      'Which transportation would make a journey most memorable?',
      'How would you like to travel between beautiful places?',
      'Which slow journey sounds romantic rather than inconvenient?',
      'What mode of travel would become part of the adventure?',
      'Which ride deserves a place on our bucket list?',
    ],
    ['Scenic train', 'Ferry boat', 'Camper van', 'Motorbike'],
  ),
  _PromptPack(
    114,
    [
      'What should we do if we get lost while traveling?',
      'Which response would keep a wrong turn from becoming stressful?',
      'How could we turn bad directions into an adventure?',
      'What is the best couple strategy when the map fails?',
      'Which lost-traveler plan sounds most like us?',
    ],
    ['Ask someone', 'Use offline maps', 'Explore anyway', 'Stop for food'],
  ),
  _PromptPack(
    115,
    [
      'Which place would make the best first international trip together?',
      'What kind of country would feel welcoming for our first big journey?',
      'Which destination style should begin our global adventures?',
      'Where would you want to use our passports together first?',
      'Which international setting sounds easiest to enjoy as a pair?',
    ],
    [
      'A food capital',
      'A tropical island',
      'A historic city',
      'A nature escape'
    ],
  ),
  _PromptPack(
    116,
    [
      'What kind of accommodation would make a trip special?',
      'Where would you most enjoy returning after a day of exploring?',
      'Which place to stay feels like part of the vacation?',
      'What lodging style best fits a romantic getaway?',
      'Which travel home base would you choose?',
    ],
    ['Boutique hotel', 'Cozy cabin', 'Beach cottage', 'City apartment'],
  ),
  _PromptPack(
    117,
    [
      'Which adventure would push us slightly outside our comfort zone?',
      'What new experience could make us feel brave together?',
      'Which activity sounds scary enough to be exciting?',
      'What shared challenge could become a proud memory?',
      'Which bold plan might be worth trying once?',
    ],
    ['Zip line', 'Night hike', 'Surf lesson', 'High viewpoint'],
  ),
  _PromptPack(
    118,
    [
      'What travel photo would you most want framed at home?',
      'Which vacation image would capture us best?',
      'What moment should a future trip photograph carefully?',
      'Which scene would become an ideal couple portrait?',
      'What travel picture would you keep visible for years?',
    ],
    [
      'Sunset silhouette',
      'Candid laughter',
      'Landmark portrait',
      'Quiet landscape'
    ],
  ),
  _PromptPack(
    119,
    [
      'Which short escape sounds possible this weekend?',
      'What nearby adventure could feel like a real vacation?',
      'How should we satisfy travel cravings without going far?',
      'Which local getaway would refresh us most?',
      'What mini-trip deserves a place on our calendar?',
    ],
    ['Nearby town', 'Nature park', 'Hotel staycation', 'Long scenic drive'],
  ),
  _PromptPack(
    120,
    [
      'What is the best ending to a full day of travel?',
      'How should we wind down after exploring from morning to night?',
      'Which final activity completes a vacation day?',
      'What would help us remember the best part before sleeping?',
      'How should we close an adventurous day together?',
    ],
    ['Late dinner', 'Quiet walk', 'Review photos', 'Rest immediately'],
  ),

  // Music, movies, books, and games: 121-140.
  _PromptPack(
    121,
    [
      'Which song type belongs at the start of our shared playlist?',
      'What sound should define a musical collection about us?',
      'Which track mood would introduce our couple story?',
      'How should an us-themed playlist begin?',
      'Which musical energy feels like our opening scene?',
    ],
    ['Soft acoustic', 'Happy pop', 'Classic love song', 'Upbeat dance'],
  ),
  _PromptPack(
    122,
    [
      'What kind of movie night sounds best tonight?',
      'Which film mood fits a relaxed evening together?',
      'What genre would you choose if snacks were already ready?',
      'Which movie experience should we plan next?',
      'What screen story would match our current energy?',
    ],
    ['Warm comedy', 'Big adventure', 'Clever mystery', 'Animated favorite'],
  ),
  _PromptPack(
    123,
    [
      'Which karaoke song style would you perform with confidence?',
      'What kind of duet could convince you to grab a microphone?',
      'Which song would make our karaoke night memorable?',
      'What performance would earn our loudest applause?',
      'Which musical choice could turn us into a temporary stage duo?',
    ],
    ['Power ballad', 'Funny throwback', 'Romantic duet', 'Fast pop hit'],
  ),
  _PromptPack(
    124,
    [
      'Which fictional world would you visit for one week?',
      'Where would you most enjoy having a temporary adventure?',
      'Which story universe sounds safest and most fun together?',
      'What imagined world deserves a couple vacation?',
      'Which fictional setting would you explore first?',
    ],
    ['A magic school', 'A space city', 'A cozy village', 'A superhero world'],
  ),
  _PromptPack(
    125,
    [
      'What makes a game night satisfying for you?',
      'Which gaming experience creates the best couple mood?',
      'What should we prioritize when choosing a game together?',
      'Which kind of challenge keeps game night fun?',
      'What game quality would make you ask for another round?',
    ],
    ['Teamwork', 'Friendly competition', 'Funny chaos', 'A good story'],
  ),
  _PromptPack(
    126,
    [
      'Which book would be most fun to read at the same time?',
      'What type of story should become our tiny two-person book club?',
      'Which genre would create the best discussions?',
      'What book mood fits shared reading before bed?',
      'Which kind of novel should we choose together?',
    ],
    ['Romantic comedy', 'Mystery', 'Fantasy adventure', 'Inspiring memoir'],
  ),
  _PromptPack(
    127,
    [
      'Which movie snack deserves the center spot?',
      'What treat is required before the opening scene?',
      'Which snack should we share during our next film?',
      'What food makes home cinema feel complete?',
      'Which movie-night bite would disappear first?',
    ],
    ['Buttered popcorn', 'Chocolate', 'Crunchy chips', 'Ice cream'],
  ),
  _PromptPack(
    128,
    [
      'What makes you replay a song many times?',
      'Which quality turns a track into an obsession?',
      'What part of a song usually captures you first?',
      'Which musical detail keeps a song in your head?',
      'What makes a track earn a permanent playlist spot?',
    ],
    ['Meaningful lyrics', 'Strong beat', 'Beautiful voice', 'A vivid memory'],
  ),
  _PromptPack(
    129,
    [
      'Which character role would you choose in a fantasy quest?',
      'What job suits you in an adventuring party?',
      'Which heroic skill would you bring to our fictional team?',
      'Who would you become if our day turned into a role-playing game?',
      'Which quest position matches your personality?',
    ],
    ['Brave warrior', 'Wise healer', 'Clever mage', 'Sneaky scout'],
  ),
  _PromptPack(
    130,
    [
      'What kind of documentary would hold your attention all evening?',
      'Which real-world topic would you happily explore on screen?',
      'What documentary subject should we watch together?',
      'Which true story category could start a long conversation?',
      'What educational viewing would still feel entertaining?',
    ],
    ['Wild nature', 'Great food', 'Human history', 'Space science'],
  ),
  _PromptPack(
    131,
    [
      'Which concert setting sounds most enjoyable?',
      'Where would live music feel most memorable?',
      'What type of venue fits your ideal music date?',
      'Which performance atmosphere would you choose?',
      'Where should we hear a favorite artist someday?',
    ],
    ['Huge arena', 'Small cafe', 'Outdoor festival', 'Intimate theater'],
  ),
  _PromptPack(
    132,
    [
      'What should we do after finishing an excellent series?',
      'Which reaction best handles the end of a favorite show?',
      'How should we fill the emptiness after a great finale?',
      'What is the proper next step after our latest binge-watch?',
      'Which post-series ritual sounds most satisfying?',
    ],
    [
      'Discuss every detail',
      'Find fan theories',
      'Rewatch favorites',
      'Start something new'
    ],
  ),
  _PromptPack(
    133,
    [
      'Which classic game would you teach future family members?',
      'What timeless game deserves to stay in every home?',
      'Which simple game creates the best shared memories?',
      'What old favorite should we keep for rainy days?',
      'Which game could entertain different generations?',
    ],
    ['Card games', 'Chess or checkers', 'Word games', 'Building blocks'],
  ),
  _PromptPack(
    134,
    [
      'What makes a fictional couple enjoyable to watch?',
      'Which quality creates the best on-screen romance?',
      'What kind of relationship story keeps you invested?',
      'Which trait makes fictional chemistry believable?',
      'What should a good love story show most clearly?',
    ],
    ['Playful banter', 'Deep loyalty', 'Slow growth', 'Shared adventure'],
  ),
  _PromptPack(
    135,
    [
      'Which instrument would you most like to learn?',
      'What musical skill would be fun to practice together?',
      'Which instrument could become a relaxing hobby?',
      'What would you choose if lessons started tomorrow?',
      'Which sound would you enjoy creating yourself?',
    ],
    ['Piano', 'Guitar', 'Drums', 'Violin'],
  ),
  _PromptPack(
    136,
    [
      'What type of ending do you prefer in a story?',
      'Which finale leaves you most satisfied?',
      'How should a memorable movie close?',
      'Which story ending stays with you in a good way?',
      'What final note makes a book worth recommending?',
    ],
    ['Completely happy', 'Hopeful and open', 'Clever surprise', 'Bittersweet'],
  ),
  _PromptPack(
    137,
    [
      'Which cooperative video-game task would you enjoy most?',
      'What virtual mission sounds fun as a two-person team?',
      'Which game world activity would test our coordination?',
      'What digital adventure should we complete together?',
      'Which co-op challenge fits our combined skills?',
    ],
    ['Build a home', 'Solve puzzles', 'Explore a world', 'Defeat a boss'],
  ),
  _PromptPack(
    138,
    [
      'Which movie location would you love to see in real life?',
      'What screen setting deserves a real-world visit?',
      'Which cinematic place would make an exciting trip?',
      'Where would you recreate a famous scene together?',
      'Which film-inspired destination belongs on our list?',
    ],
    ['A grand castle', 'A busy city', 'A wild island', 'A quiet village'],
  ),
  _PromptPack(
    139,
    [
      'What kind of podcast would make a long drive better?',
      'Which audio show could keep us entertained on a trip?',
      'What topic would spark the best car conversations?',
      'Which podcast mood belongs on our next journey?',
      'What should play when music needs a break?',
    ],
    [
      'Funny stories',
      'True mysteries',
      'Relationship chats',
      'Interesting facts'
    ],
  ),
  _PromptPack(
    140,
    [
      'Which creative fandom activity would you try once?',
      'What fan experience sounds surprisingly fun?',
      'Which way of celebrating a favorite story appeals to you?',
      'What themed activity could make a memorable date?',
      'Which fandom plan would bring out our playful side?',
    ],
    [
      'Wear costumes',
      'Attend a convention',
      'Make fan art',
      'Host a themed night'
    ],
  ),
  _PromptPack.named(
    id: 141,
    questions: <String>[
      'Which childhood game would be the most fun for us to play together?',
      'What kind of childhood game would bring out our playful side?',
      'Which old-school game would make us laugh the most?',
      'What childhood activity should we recreate on a carefree afternoon?',
      'Which playful throwback would suit us best?',
    ],
    options: <String>[
      'Hide-and-seek',
      'Board games',
      'Pretend play',
      'Outdoor games',
    ],
  ),
  _PromptPack.named(
    id: 142,
    questions: <String>[
      'Which school-day memory would you most enjoy sharing stories about?',
      'What kind of school memory feels the most nostalgic to you?',
      'Which part of school life would be funniest for us to compare?',
      'What school-day moment would you happily revisit for one hour?',
      'Which school memory would reveal the most about younger us?',
    ],
    options: <String>[
      'Field trips',
      'Lunch breaks',
      'School programs',
      'Quiet class moments',
    ],
  ),
  _PromptPack.named(
    id: 143,
    questions: <String>[
      'Which childhood snack would make the sweetest surprise for us?',
      'What nostalgic treat should we share during a movie night?',
      'Which old favorite would taste best on a cozy afternoon?',
      'What childhood snack would you happily bring back forever?',
      'Which simple treat would make us feel like kids again?',
    ],
    options: <String>[
      'Cookies and milk',
      'Frozen treats',
      'Chips and juice',
      'Sweet bread',
    ],
  ),
  _PromptPack.named(
    id: 144,
    questions: <String>[
      'Which childhood tradition would you most like us to start together?',
      'What kind of family tradition feels warmest to you?',
      'Which tradition would make our future home feel especially cozy?',
      'What repeated little ritual would you look forward to most?',
      'Which tradition would create the happiest yearly memories?',
    ],
    options: <String>[
      'Holiday cooking',
      'Birthday rituals',
      'Weekend outings',
      'Evening storytelling',
    ],
  ),
  _PromptPack.named(
    id: 145,
    questions: <String>[
      'Which kind of childhood treasure would you show me first?',
      'What childhood keepsake would tell me the best story about you?',
      'Which old favorite would you be happiest to find again?',
      'What little piece of your childhood would you want us to keep?',
      'Which nostalgic item would make you smile immediately?',
    ],
    options: <String>[
      'A favorite toy',
      'An old drawing',
      'A storybook',
      'A tiny souvenir',
    ],
  ),
  _PromptPack.named(
    id: 146,
    questions: <String>[
      'Which childhood setting feels the most magical in your memories?',
      'Where would younger you have happily spent an entire day?',
      'Which nostalgic place would you most like to visit with me?',
      'What childhood setting would make the best backdrop for our adventure?',
      'Which place from growing up still feels comforting to imagine?',
    ],
    options: <String>[
      'A playground',
      'A grandparent home',
      'A favorite shop',
      'A neighborhood street',
    ],
  ),
  _PromptPack.named(
    id: 147,
    questions: <String>[
      'What kind of childhood story would you most want to hear from me?',
      'Which younger-us tale would be the most fun to trade?',
      'What memory category would help us know each other better?',
      'Which childhood story would probably make us laugh hardest?',
      'What part of growing up would you love for us to compare?',
    ],
    options: <String>[
      'A silly mistake',
      'A proud moment',
      'A secret hobby',
      'A tiny adventure',
    ],
  ),
  _PromptPack.named(
    id: 148,
    questions: <String>[
      'Which kind of childhood show would be most fun to watch together now?',
      'What nostalgic screen favorite should get a cozy rerun night?',
      'Which childhood entertainment would bring back the biggest smile?',
      'What throwback watch would make the cutest date?',
      'Which old favorite would you introduce to me first?',
    ],
    options: <String>[
      'A funny cartoon',
      'A fantasy series',
      'A family movie',
      'A music show',
    ],
  ),
  _PromptPack.named(
    id: 149,
    questions: <String>[
      'Which younger version of us would have become friends fastest?',
      'At what age do you think we would have been the funniest pair?',
      'Which chapter of growing up would be cutest for us to revisit?',
      'When would younger us have had the best little adventure?',
      'Which age would reveal the most surprising side of us?',
    ],
    options: <String>[
      'Early childhood',
      'Grade school',
      'Teen years',
      'Young adulthood',
    ],
  ),
  _PromptPack.named(
    id: 150,
    questions: <String>[
      'Which childhood creative activity should we try on a quiet day?',
      'What nostalgic craft would be the most charming date?',
      'Which playful project would let our younger selves shine?',
      'What childhood hobby would be fun to rediscover together?',
      'Which creative throwback would leave us with the best keepsake?',
    ],
    options: <String>[
      'Finger painting',
      'Paper crafts',
      'Building blocks',
      'Making bracelets',
    ],
  ),
  _PromptPack.named(
    id: 151,
    questions: <String>[
      'Which childhood weather memory feels most vivid to you?',
      'What kind of weather made ordinary days feel special growing up?',
      'Which weather-day memory would you like to recreate with me?',
      'What childhood forecast sounds like the coziest shared story?',
      'Which kind of day brought out your most playful side?',
    ],
    options: <String>[
      'Rainy afternoons',
      'Sunny mornings',
      'Windy evenings',
      'Cool cloudy days',
    ],
  ),
  _PromptPack.named(
    id: 152,
    questions: <String>[
      'Which childhood celebration would you most enjoy recreating?',
      'What kind of celebration made younger you happiest?',
      'Which nostalgic party detail should appear at our next celebration?',
      'What childhood festivity would make a playful date theme?',
      'Which celebration memory would you love to tell me about?',
    ],
    options: <String>[
      'A themed birthday',
      'A school fair',
      'A family reunion',
      'A neighborhood party',
    ],
  ),
  _PromptPack.named(
    id: 153,
    questions: <String>[
      'Which childhood collection would have fascinated both of us?',
      'What tiny treasures would younger us have loved gathering?',
      'Which collection would make the cutest display in our home?',
      'What nostalgic hobby would we have enjoyed comparing?',
      'Which little collection sounds most like a shared childhood quest?',
    ],
    options: <String>[
      'Stickers',
      'Pretty stones',
      'Toy figures',
      'Postcards',
    ],
  ),
  _PromptPack.named(
    id: 154,
    questions: <String>[
      'Which childhood dream job would be most fun to try for a day?',
      'What younger-us career would make the funniest matching costumes?',
      'Which childhood ambition would lead us on the best pretend adventure?',
      'What dream role would reveal our most imaginative side?',
      'Which make-believe job should we turn into a playful date?',
    ],
    options: <String>[
      'Space explorer',
      'Chef',
      'Artist',
      'Animal caretaker',
    ],
  ),
  _PromptPack.named(
    id: 155,
    questions: <String>[
      'What kind of childhood compliment would have meant the most to you?',
      'Which words would younger you have loved hearing more often?',
      'What encouragement would you send back to your younger self?',
      'Which reminder would have made growing up feel gentler?',
      'What message should we give our younger selves together?',
    ],
    options: <String>[
      'You are creative',
      'You are brave',
      'You are loved',
      'You are enough',
    ],
  ),
  _PromptPack.named(
    id: 156,
    questions: <String>[
      'Which childhood morning would you most like to relive?',
      'What kind of younger-days morning felt full of possibility?',
      'Which nostalgic morning plan sounds sweetest to share?',
      'What early-day memory would make you feel carefree again?',
      'Which childhood start to the day would suit us best?',
    ],
    options: <String>[
      'Cartoons and cereal',
      'An early outing',
      'Sleeping in',
      'Helping in the kitchen',
    ],
  ),
  _PromptPack.named(
    id: 157,
    questions: <String>[
      'Which childhood bedtime ritual would feel coziest to bring back?',
      'What nighttime memory from growing up feels most comforting?',
      'Which old bedtime habit would make our evening extra gentle?',
      'What nostalgic night ritual should inspire our next cozy night?',
      'Which childhood wind-down sounds sweetest to share?',
    ],
    options: <String>[
      'A bedtime story',
      'A quiet song',
      'A warm drink',
      'A goodnight chat',
    ],
  ),
  _PromptPack.named(
    id: 158,
    questions: <String>[
      'Which childhood skill would you most enjoy teaching me?',
      'What younger-days talent would be fun for us to practice?',
      'Which simple skill would make the cutest mini lesson?',
      'What childhood ability would you proudly demonstrate first?',
      'Which old skill should become our next shared challenge?',
    ],
    options: <String>[
      'Riding a bike',
      'Drawing cartoons',
      'Making a snack',
      'Playing a game',
    ],
  ),
  _PromptPack.named(
    id: 159,
    questions: <String>[
      'Which kind of old photo would you most want us to look through?',
      'What childhood album page would tell the funniest story?',
      'Which photo memory would you happily recreate as a couple?',
      'What younger-you snapshot would you show me first?',
      'Which nostalgic picture theme would make us smile most?',
    ],
    options: <String>[
      'Funny outfits',
      'Family trips',
      'School days',
      'Everyday moments',
    ],
  ),
  _PromptPack.named(
    id: 160,
    questions: <String>[
      'Which lesson from childhood do you value most today?',
      'What early lesson would you want us to carry into our future?',
      'Which childhood value feels most important in our relationship?',
      'What simple lesson from growing up still guides you?',
      'Which value would you want our home to reflect every day?',
    ],
    options: <String>[
      'Be kind',
      'Stay curious',
      'Keep trying',
      'Share generously',
    ],
  ),
  _PromptPack.named(
    id: 161,
    questions: <String>[
      'Which shared dream would you be most excited to plan together?',
      'What future goal would feel especially meaningful as a team?',
      'Which dream would give us the happiest project to work toward?',
      'What shared milestone would you love to celebrate one day?',
      'Which future plan feels most exciting to imagine tonight?',
    ],
    options: <String>[
      'A cozy home',
      'A big adventure',
      'A creative project',
      'A peaceful routine',
    ],
  ),
  _PromptPack.named(
    id: 162,
    questions: <String>[
      'What kind of future morning would you love for us to wake up to?',
      'Which everyday future scene feels most comforting to imagine?',
      'What shared morning rhythm would make life feel lovely?',
      'Which future start to the day sounds most like us?',
      'What morning detail belongs in our happiest future?',
    ],
    options: <String>[
      'Coffee and chatting',
      'A slow breakfast',
      'An early walk',
      'Music while getting ready',
    ],
  ),
  _PromptPack.named(
    id: 163,
    questions: <String>[
      'Which kind of place would you most like us to call home someday?',
      'What future neighborhood would fit our personalities best?',
      'Which home setting sounds most peaceful for our shared life?',
      'Where can you most easily picture our cozy future?',
      'Which surroundings would make our everyday life feel special?',
    ],
    options: <String>[
      'A lively city',
      'A quiet suburb',
      'Near the sea',
      'Close to nature',
    ],
  ),
  _PromptPack.named(
    id: 164,
    questions: <String>[
      'Which future home feature would make you happiest?',
      'What space would you be most excited to create together?',
      'Which cozy home detail deserves a place in our dream plan?',
      'What room would become our favorite shared corner?',
      'Which home feature would best support our everyday joy?',
    ],
    options: <String>[
      'A sunny kitchen',
      'A reading nook',
      'A little garden',
      'A movie corner',
    ],
  ),
  _PromptPack.named(
    id: 165,
    questions: <String>[
      'Which future celebration would you most enjoy planning together?',
      'What milestone party would feel sweetest to host?',
      'Which celebration would let our favorite people share our joy?',
      'What future occasion deserves our most thoughtful little details?',
      'Which happy milestone would make us the most excited?',
    ],
    options: <String>[
      'An anniversary',
      'A home milestone',
      'A project launch',
      'A reunion trip',
    ],
  ),
  _PromptPack.named(
    id: 166,
    questions: <String>[
      'What new skill would you most like us to learn side by side?',
      'Which future hobby would be rewarding to practice together?',
      'What shared learning goal sounds the most fun?',
      'Which skill would give us the best stories while improving?',
      'What would you happily be a beginner at with me?',
    ],
    options: <String>[
      'A new language',
      'Cooking a cuisine',
      'Making art',
      'A dance style',
    ],
  ),
  _PromptPack.named(
    id: 167,
    questions: <String>[
      'Which future adventure belongs highest on our shared list?',
      'What experience would make an unforgettable couple milestone?',
      'Which big outing would you love us to save and plan for?',
      'What future adventure would stretch us in a happy way?',
      'Which dream experience would you choose for us first?',
    ],
    options: <String>[
      'A scenic road trip',
      'A faraway flight',
      'A nature escape',
      'A cultural festival',
    ],
  ),
  _PromptPack.named(
    id: 168,
    questions: <String>[
      'What kind of future weekend rhythm would feel best to you?',
      'Which shared weekend habit would keep our life balanced?',
      'What future Saturday sounds most satisfying?',
      'Which weekend pattern would you love us to protect?',
      'What kind of weekend would help us feel closest?',
    ],
    options: <String>[
      'Rest and recharge',
      'Explore somewhere',
      'Finish a project',
      'Visit loved ones',
    ],
  ),
  _PromptPack.named(
    id: 169,
    questions: <String>[
      'Which personal dream would you most want my support with?',
      'What future goal would feel easier with us cheering each other on?',
      'Which kind of growth would you love to pursue next?',
      'What personal milestone would make you especially proud?',
      'Which dream deserves more space in your future?',
    ],
    options: <String>[
      'Creative confidence',
      'Career progress',
      'Better wellbeing',
      'A new life skill',
    ],
  ),
  _PromptPack.named(
    id: 170,
    questions: <String>[
      'How would you most like us to record our future adventures?',
      'Which memory-keeping habit should our future selves thank us for?',
      'What would be the sweetest way to preserve our shared years?',
      'Which keepsake could become a treasured couple tradition?',
      'How should we collect the little moments ahead?',
    ],
    options: <String>[
      'Photo albums',
      'Short videos',
      'A shared journal',
      'Tiny souvenirs',
    ],
  ),
  _PromptPack.named(
    id: 171,
    questions: <String>[
      'Which value should guide our future decisions most often?',
      'What quality would you want at the center of our shared life?',
      'Which principle should our future home always protect?',
      'What value would help us build a life we both love?',
      'Which shared priority feels most important for the years ahead?',
    ],
    options: <String>[
      'Kindness',
      'Curiosity',
      'Stability',
      'Playfulness',
    ],
  ),
  _PromptPack.named(
    id: 172,
    questions: <String>[
      'Which future tradition should we begin sooner rather than later?',
      'What recurring plan would give us something lovely to anticipate?',
      'Which ritual could become part of our shared story?',
      'What future tradition would keep our connection feeling fresh?',
      'Which repeated celebration sounds most like us?',
    ],
    options: <String>[
      'Monthly date day',
      'Yearly getaway',
      'Seasonal photo',
      'Weekly cozy night',
    ],
  ),
  _PromptPack.named(
    id: 173,
    questions: <String>[
      'What kind of impact would you love for us to make together?',
      'Which shared contribution would feel most worthwhile?',
      'How would you like our future life to brighten other lives?',
      'Which kind of giving would be meaningful for us as a pair?',
      'What positive mark would you be proud for us to leave?',
    ],
    options: <String>[
      'Help our community',
      'Support loved ones',
      'Create something useful',
      'Care for the planet',
    ],
  ),
  _PromptPack.named(
    id: 174,
    questions: <String>[
      'Which future evening sounds the most peaceful to you?',
      'What end-of-day scene would make our home feel happiest?',
      'Which evening rhythm would you enjoy sharing for years?',
      'What quiet future moment can you picture most clearly?',
      'Which nightly routine would help us reconnect?',
    ],
    options: <String>[
      'Cooking together',
      'Watching a favorite',
      'Talking on the balcony',
      'Reading side by side',
    ],
  ),
  _PromptPack.named(
    id: 175,
    questions: <String>[
      'Which practical goal would you most like us to master together?',
      'What shared life skill would make our future smoother?',
      'Which kind of planning would feel most rewarding to improve?',
      'What practical milestone deserves a cheerful team effort?',
      'Which shared goal would give us more freedom later?',
    ],
    options: <String>[
      'Saving consistently',
      'Planning meals',
      'Organizing our space',
      'Managing our time',
    ],
  ),
  _PromptPack.named(
    id: 176,
    questions: <String>[
      'What do you hope never changes about us as time passes?',
      'Which part of our connection should our future selves protect?',
      'What quality of us would you carry through every life chapter?',
      'Which shared spark should stay with us for years?',
      'What part of today belongs in our happiest future?',
    ],
    options: <String>[
      'Our silly humor',
      'Our honest talks',
      'Our gentle care',
      'Our curiosity',
    ],
  ),
  _PromptPack.named(
    id: 177,
    questions: <String>[
      'Which future season of life are you most curious to experience together?',
      'What next chapter feels especially exciting to imagine?',
      'Which shared phase would bring out our best teamwork?',
      'What kind of future chapter would surprise us most?',
      'Which season ahead would you happily peek at for one minute?',
    ],
    options: <String>[
      'Building our routines',
      'Growing our dreams',
      'Exploring new places',
      'Enjoying a slower pace',
    ],
  ),
  _PromptPack.named(
    id: 178,
    questions: <String>[
      'What would make a future ordinary day feel successful to you?',
      'Which simple sign would tell you our shared life is going well?',
      'What everyday achievement would make you feel content?',
      'Which small future win matters more than it might seem?',
      'What would make us end a normal day feeling proud?',
    ],
    options: <String>[
      'We made time to talk',
      'We helped each other',
      'We laughed together',
      'We rested without guilt',
    ],
  ),
  _PromptPack.named(
    id: 179,
    questions: <String>[
      'Which future surprise would you love for us to discover together?',
      'What unexpected life bonus would delight you most?',
      'Which happy twist would make our shared story extra charming?',
      'What future discovery would you want to experience by my side?',
      'Which pleasant surprise sounds most exciting for us?',
    ],
    options: <String>[
      'A hidden talent',
      'A favorite new place',
      'A shared hobby',
      'A lovely tradition',
    ],
  ),
  _PromptPack.named(
    id: 180,
    questions: <String>[
      'What message would you most like our future selves to remember?',
      'Which reminder should we carry into every new chapter?',
      'What promise to ourselves would keep the future feeling warm?',
      'Which sentence belongs in a note to older us?',
      'What truth about us should time never let us forget?',
    ],
    options: <String>[
      'Choose each other daily',
      'Keep making memories',
      'Be gentle while growing',
      'Celebrate the small things',
    ],
  ),
  _PromptPack.named(
    id: 181,
    questions: <String>[
      'Which simple at-home date would feel best tonight?',
      'What low-key plan would make our evening feel special?',
      'Which home date would help us unwind together?',
      'What easy shared activity sounds sweetest after a long day?',
      'Which cozy plan would you choose without leaving home?',
    ],
    options: <String>[
      'Cook something new',
      'Have a movie night',
      'Play a game',
      'Make a blanket nest',
    ],
  ),
  _PromptPack.named(
    id: 182,
    questions: <String>[
      'Which small outing would make the nicest spontaneous date?',
      'What nearby plan would brighten an ordinary afternoon?',
      'Which easy adventure should we take with almost no planning?',
      'What little trip would feel refreshing today?',
      'Which casual date sounds most fun right now?',
    ],
    options: <String>[
      'Cafe visit',
      'Park stroll',
      'Bookstore browse',
      'Dessert run',
    ],
  ),
  _PromptPack.named(
    id: 183,
    questions: <String>[
      'Which home task would be most enjoyable as a team?',
      'What chore could we turn into the best mini date?',
      'Which shared task would feel satisfying to finish together?',
      'What household mission should get a fun soundtrack?',
      'Which practical activity would show off our teamwork?',
    ],
    options: <String>[
      'Cook dinner',
      'Organize a corner',
      'Wash and fold',
      'Decorate a space',
    ],
  ),
  _PromptPack.named(
    id: 184,
    questions: <String>[
      'Which weekend breakfast would make you happiest?',
      'What morning meal belongs in our ideal slow weekend?',
      'Which breakfast would tempt us out of bed first?',
      'What cozy weekend plate should we share soon?',
      'Which morning treat would start our date perfectly?',
    ],
    options: <String>[
      'Pancakes',
      'Eggs and toast',
      'Warm pastries',
      'A rice breakfast',
    ],
  ),
  _PromptPack.named(
    id: 185,
    questions: <String>[
      'Which room would you most enjoy refreshing together?',
      'What part of home would be the most fun to make cozier?',
      'Which space deserves our next little makeover?',
      'What room would best show our combined style?',
      'Which corner should become our next shared project?',
    ],
    options: <String>[
      'Bedroom',
      'Kitchen',
      'Living area',
      'Balcony or garden',
    ],
  ),
  _PromptPack.named(
    id: 186,
    questions: <String>[
      'Which soundtrack fits an unhurried day at home?',
      'What kind of music should fill our coziest afternoon?',
      'Which listening mood would make home feel extra warm?',
      'What sound belongs behind a peaceful day together?',
      'Which music vibe would suit our shared space today?',
    ],
    options: <String>[
      'Soft acoustic',
      'Cheerful pop',
      'Old favorites',
      'Calm instrumentals',
    ],
  ),
  _PromptPack.named(
    id: 187,
    questions: <String>[
      'Which tiny home luxury would you appreciate most today?',
      'What simple comfort would make tonight feel indulgent?',
      'Which little upgrade would create the coziest mood?',
      'What everyday treat would help you fully relax?',
      'Which small comfort should we prepare for each other?',
    ],
    options: <String>[
      'Fresh sheets',
      'A favorite drink',
      'Soft lighting',
      'A long warm shower',
    ],
  ),
  _PromptPack.named(
    id: 188,
    questions: <String>[
      'Which weekend pace sounds best for us this time?',
      'What kind of two-day break would leave you happiest?',
      'Which weekend energy are you craving most?',
      'What balance would make our next weekend feel complete?',
      'Which weekend style would fit our mood right now?',
    ],
    options: <String>[
      'Fully restful',
      'Mostly adventurous',
      'Productive then cozy',
      'A little of everything',
    ],
  ),
  _PromptPack.named(
    id: 189,
    questions: <String>[
      'Which no-cost date would you happily repeat often?',
      'What free little plan could still feel romantic?',
      'Which simple date proves fun does not need a budget?',
      'What easy shared moment would be priceless to you?',
      'Which free activity sounds most connecting?',
    ],
    options: <String>[
      'Take a long walk',
      'Watch the sunset',
      'Share old stories',
      'Make a home picnic',
    ],
  ),
  _PromptPack.named(
    id: 190,
    questions: <String>[
      'Which indoor weather-day activity would you choose first?',
      'What plan would make staying inside feel like a treat?',
      'Which cozy activity is perfect when plans get rained out?',
      'What indoor date would keep us happily occupied?',
      'Which at-home idea would rescue a gloomy afternoon?',
    ],
    options: <String>[
      'Bake something',
      'Build a puzzle',
      'Watch a series',
      'Make a craft',
    ],
  ),
  _PromptPack.named(
    id: 191,
    questions: <String>[
      'Which everyday errand would be cutest as a mini date?',
      'What ordinary trip becomes more fun when we go together?',
      'Which errand could turn into an unexpected adventure?',
      'What practical outing would you happily share with me?',
      'Which small task should include a treat afterward?',
    ],
    options: <String>[
      'Grocery shopping',
      'Market browsing',
      'Picking up supplies',
      'A quick bank trip',
    ],
  ),
  _PromptPack.named(
    id: 192,
    questions: <String>[
      'Which home scent would make our space feel most inviting?',
      'What fragrance belongs in a perfectly cozy room?',
      'Which scent would help you relax the fastest?',
      'What home aroma would you want to greet us at the door?',
      'Which fragrance matches our cozy style?',
    ],
    options: <String>[
      'Fresh laundry',
      'Warm vanilla',
      'Clean citrus',
      'Rainy air',
    ],
  ),
  _PromptPack.named(
    id: 193,
    questions: <String>[
      'Which tiny date surprise would brighten your whole day?',
      'What simple gesture could turn an ordinary evening special?',
      'Which small surprise would feel most thoughtful?',
      'What unexpected date detail would make you grin?',
      'Which little plan would be sweetest to come home to?',
    ],
    options: <String>[
      'A favorite snack',
      'A handwritten note',
      'A planned walk',
      'A chosen movie',
    ],
  ),
  _PromptPack.named(
    id: 194,
    questions: <String>[
      'Which corner of home should always stay clutter-free?',
      'What tidy space would make daily life feel calmer?',
      'Which area is most satisfying to see freshly organized?',
      'What home zone deserves a quick team reset?',
      'Which clear surface would give us the biggest mood boost?',
    ],
    options: <String>[
      'The bedside area',
      'The kitchen counter',
      'The dining table',
      'The entryway',
    ],
  ),
  _PromptPack.named(
    id: 195,
    questions: <String>[
      'Which casual evening drink would you pick for our chat?',
      'What sip belongs beside a long cozy conversation?',
      'Which drink would complete a relaxed night at home?',
      'What would you pour for our next catch-up date?',
      'Which shared drink moment sounds most comforting?',
    ],
    options: <String>[
      'Hot chocolate',
      'Tea',
      'Iced coffee',
      'Fresh juice',
    ],
  ),
  _PromptPack.named(
    id: 196,
    questions: <String>[
      'Which kind of home lighting makes you feel coziest?',
      'What lighting would set the best mood for our evening?',
      'Which glow makes a room feel instantly warmer?',
      'What light would you choose for a quiet date at home?',
      'Which lighting style belongs in our ideal cozy corner?',
    ],
    options: <String>[
      'Warm lamps',
      'String lights',
      'Soft candles',
      'Natural sunset light',
    ],
  ),
  _PromptPack.named(
    id: 197,
    questions: <String>[
      'Which Sunday activity would reset us best for the week?',
      'What end-of-weekend ritual would help us feel ready?',
      'Which Sunday plan balances comfort and preparation?',
      'What shared reset would make Monday feel gentler?',
      'Which weekly wind-down should become our habit?',
    ],
    options: <String>[
      'Plan meals',
      'Take a slow walk',
      'Tidy together',
      'Rest with a movie',
    ],
  ),
  _PromptPack.named(
    id: 198,
    questions: <String>[
      'Which small date would be best after a busy week?',
      'What simple plan would help us reconnect fastest?',
      'Which low-pressure date fits a tired but happy mood?',
      'What easy outing would feel like a breath of fresh air?',
      'Which end-of-week treat would you choose for us?',
    ],
    options: <String>[
      'Late-night snacks',
      'A quiet cafe',
      'A scenic drive',
      'Takeout at home',
    ],
  ),
  _PromptPack.named(
    id: 199,
    questions: <String>[
      'Which shared home habit would make mornings smoother?',
      'What tiny routine could improve our daily teamwork?',
      'Which practical habit would save us the most stress?',
      'What simple system would make home life easier?',
      'Which everyday habit should we gently build together?',
    ],
    options: <String>[
      'Prepare the night before',
      'Keep a shared list',
      'Do quick tidy-ups',
      'Plan the day together',
    ],
  ),
  _PromptPack.named(
    id: 200,
    questions: <String>[
      'Which ordinary home moment feels quietly romantic to you?',
      'What simple shared scene makes a place feel like ours?',
      'Which everyday moment would you never want to take for granted?',
      'What peaceful home memory do you want more of?',
      'Which little slice of daily life makes love feel most real?',
    ],
    options: <String>[
      'Cooking side by side',
      'Falling asleep nearby',
      'Laughing over nothing',
      'Doing separate things together',
    ],
  ),
  _PromptPack.named(
    id: 201,
    questions: <String>[
      'Which quality best describes how you approach a new experience?',
      'What side of your personality appears first on an adventure?',
      'Which trait guides you when plans suddenly change?',
      'How do you usually enter an unfamiliar situation?',
      'Which energy do you bring to something you have never tried?',
    ],
    options: <String>[
      'Curious',
      'Careful',
      'Excited',
      'Calm',
    ],
  ),
  _PromptPack.named(
    id: 202,
    questions: <String>[
      'Which role do you naturally take when we make plans?',
      'What planning style feels most like you?',
      'Which part of organizing an outing suits you best?',
      'How do you usually help a shared plan come together?',
      'Which planning contribution would you happily own?',
    ],
    options: <String>[
      'Idea generator',
      'Detail checker',
      'Cheerful follower',
      'Flexible helper',
    ],
  ),
  _PromptPack.named(
    id: 203,
    questions: <String>[
      'Which kind of compliment feels most like the real you?',
      'What quality would you be happiest for others to notice?',
      'Which description matches the person you try to be?',
      'What trait would make you proud to be known for?',
      'Which personal strength feels most central to you?',
    ],
    options: <String>[
      'Thoughtful',
      'Funny',
      'Reliable',
      'Creative',
    ],
  ),
  _PromptPack.named(
    id: 204,
    questions: <String>[
      'Which pace feels most natural on a free day?',
      'How would you instinctively spend an unscheduled afternoon?',
      'Which rhythm best matches your relaxed self?',
      'What free-day energy suits your personality?',
      'Which pace helps you feel most like yourself?',
    ],
    options: <String>[
      'Slow and cozy',
      'Busy and curious',
      'Spontaneous',
      'Gently productive',
    ],
  ),
  _PromptPack.named(
    id: 205,
    questions: <String>[
      'Which kind of surprise suits you best?',
      'What unexpected gesture would match your personality?',
      'Which surprise style would feel most enjoyable?',
      'How much mystery do you prefer in a happy surprise?',
      'Which kind of spontaneous treat would you welcome most?',
    ],
    options: <String>[
      'Small and sweet',
      'Carefully planned',
      'Completely unexpected',
      'Let me choose',
    ],
  ),
  _PromptPack.named(
    id: 206,
    questions: <String>[
      'Which time of day brings out your best energy?',
      'When do you feel most naturally yourself?',
      'Which part of the day best matches your personality?',
      'When would you schedule your favorite activity?',
      'Which daily window tends to feel most pleasant?',
    ],
    options: <String>[
      'Early morning',
      'Late morning',
      'Golden afternoon',
      'Quiet night',
    ],
  ),
  _PromptPack.named(
    id: 207,
    questions: <String>[
      'Which type of conversation do you naturally enjoy most?',
      'What kind of chat makes time disappear for you?',
      'Which conversation mood brings out your favorite side?',
      'What topic style keeps you happily talking?',
      'Which kind of exchange feels most connecting?',
    ],
    options: <String>[
      'Deep reflections',
      'Silly observations',
      'Future ideas',
      'Everyday stories',
    ],
  ),
  _PromptPack.named(
    id: 208,
    questions: <String>[
      'Which way of deciding feels most natural to you?',
      'What guides you first when choices are equally good?',
      'Which decision style sounds most like your usual approach?',
      'How do you break a tie between fun options?',
      'What do you trust most while making a small choice?',
    ],
    options: <String>[
      'My first instinct',
      'A thoughtful list',
      'A quick discussion',
      'Whatever feels fun',
    ],
  ),
  _PromptPack.named(
    id: 209,
    questions: <String>[
      'Which social setting helps you feel most comfortable?',
      'Where does your personality come out most easily?',
      'Which kind of gathering would you choose for a relaxed night?',
      'What social atmosphere gives you the best energy?',
      'Which setting makes connecting with people feel natural?',
    ],
    options: <String>[
      'One-on-one time',
      'A tiny group',
      'A lively gathering',
      'A familiar crowd',
    ],
  ),
  _PromptPack.named(
    id: 210,
    questions: <String>[
      'Which little challenge sounds most satisfying?',
      'What type of puzzle best matches how your mind works?',
      'Which activity would keep you happily focused?',
      'What playful challenge would you choose first?',
      'Which brainy pastime suits your personality?',
    ],
    options: <String>[
      'Word puzzle',
      'Logic game',
      'Creative riddle',
      'Visual search',
    ],
  ),
  _PromptPack.named(
    id: 211,
    questions: <String>[
      'Which way of showing excitement feels most like you?',
      'How does your happiest energy usually appear?',
      'Which reaction gives away that you are delighted?',
      'What do you naturally do when something wonderful happens?',
      'Which joyful habit would I recognize instantly?',
    ],
    options: <String>[
      'Talk a lot',
      'Smile quietly',
      'Move around',
      'Share it immediately',
    ],
  ),
  _PromptPack.named(
    id: 212,
    questions: <String>[
      'Which kind of keepsake are you most likely to treasure?',
      'What small item would your sentimental side save?',
      'Which memory object feels most meaningful to you?',
      'What would you keep in a little box of favorite moments?',
      'Which keepsake best matches your nostalgic side?',
    ],
    options: <String>[
      'A handwritten note',
      'A printed photo',
      'A ticket stub',
      'A tiny gift',
    ],
  ),
  _PromptPack.named(
    id: 213,
    questions: <String>[
      'Which weather best matches your personality today?',
      'What forecast feels most like your current energy?',
      'Which kind of sky reflects your mood right now?',
      'What weather would your personality be this morning?',
      'Which atmosphere fits your present vibe?',
    ],
    options: <String>[
      'Bright sunshine',
      'Gentle rain',
      'Playful breeze',
      'Cozy clouds',
    ],
  ),
  _PromptPack.named(
    id: 214,
    questions: <String>[
      'Which kind of gift do you most enjoy choosing for someone?',
      'What gift style lets your personality shine?',
      'Which present would you have the most fun preparing?',
      'How do you prefer to make a gift feel personal?',
      'Which giving style feels most satisfying?',
    ],
    options: <String>[
      'Something useful',
      'Something handmade',
      'A shared experience',
      'A thoughtful surprise',
    ],
  ),
  _PromptPack.named(
    id: 215,
    questions: <String>[
      'Which kind of learner are you when trying something new?',
      'How do you prefer to understand a new skill?',
      'Which learning style keeps you most engaged?',
      'What approach helps a lesson stick for you?',
      'Which method would you choose for our next shared hobby?',
    ],
    options: <String>[
      'Watch a demo',
      'Read the steps',
      'Try it immediately',
      'Learn with a partner',
    ],
  ),
  _PromptPack.named(
    id: 216,
    questions: <String>[
      'Which kind of humor makes you laugh most reliably?',
      'What comedy style best matches your playful side?',
      'Which joke energy would win you over fastest?',
      'What kind of funny moment do you enjoy most?',
      'Which humor style belongs in our shared comedy show?',
    ],
    options: <String>[
      'Clever wordplay',
      'Silly nonsense',
      'Funny stories',
      'Unexpected reactions',
    ],
  ),
  _PromptPack.named(
    id: 217,
    questions: <String>[
      'Which personal strength appears most when someone needs you?',
      'What quality do you naturally offer to people you care about?',
      'Which supportive role feels most like you?',
      'How do you tend to show up for a loved one?',
      'Which caring strength would your closest people recognize?',
    ],
    options: <String>[
      'I listen',
      'I solve things',
      'I encourage',
      'I stay nearby',
    ],
  ),
  _PromptPack.named(
    id: 218,
    questions: <String>[
      'Which kind of environment helps you focus best?',
      'Where would you choose to finish an important little project?',
      'What setting brings out your most productive self?',
      'Which background helps your mind settle into a task?',
      'Where does concentration feel easiest for you?',
    ],
    options: <String>[
      'Total quiet',
      'Soft music',
      'A lively cafe',
      'Outdoors',
    ],
  ),
  _PromptPack.named(
    id: 219,
    questions: <String>[
      'Which spontaneous choice would feel most natural to you?',
      'What unplanned activity could easily win you over?',
      'Which sudden idea would you be quickest to say yes to?',
      'What last-minute plan best suits your adventurous side?',
      'Which surprise detour would tempt you most?',
    ],
    options: <String>[
      'Try a new restaurant',
      'Take a scenic ride',
      'Visit a local event',
      'Stay in and improvise',
    ],
  ),
  _PromptPack.named(
    id: 220,
    questions: <String>[
      'Which personal motto best fits your current chapter?',
      'What reminder would guide your choices today?',
      'Which phrase matches the way you want to live lately?',
      'What simple motto would help you through this week?',
      'Which thought deserves a place on your daily note?',
    ],
    options: <String>[
      'Stay curious',
      'Choose kindness',
      'Take it gently',
      'Make it memorable',
    ],
  ),
  _PromptPack.named(
    id: 221,
    questions: <String>[
      'If we found a free afternoon portal, where should it take us?',
      'Which instant getaway would you choose for us today?',
      'If travel took one second, where would our mini date happen?',
      'Which setting would be the best surprise destination right now?',
      'If distance disappeared for a day, where should we go first?',
    ],
    options: <String>[
      'A quiet beach',
      'A mountain cabin',
      'A bright city',
      'A flower field',
    ],
  ),
  _PromptPack.named(
    id: 222,
    questions: <String>[
      'If our relationship had a magical helper, what should it do?',
      'Which tiny superpower would make our days more delightful?',
      'If we could add one gentle magic trick to daily life, which one?',
      'Which enchanted convenience would you choose for our home?',
      'What harmless magic would make us smile most often?',
    ],
    options: <String>[
      'Pause cozy moments',
      'Summon favorite snacks',
      'Clean rooms instantly',
      'Translate every mood',
    ],
  ),
  _PromptPack.named(
    id: 223,
    questions: <String>[
      'If we opened a tiny shop together, what would it sell?',
      'Which little business would be the most fun for us to run?',
      'What imaginary storefront best matches our combined energy?',
      'Which shop would let us create the sweetest atmosphere?',
      'If we became cheerful shopkeepers, what would be on our sign?',
    ],
    options: <String>[
      'Books and coffee',
      'Flowers and gifts',
      'Desserts',
      'Art and crafts',
    ],
  ),
  _PromptPack.named(
    id: 224,
    questions: <String>[
      'If we could live inside one story setting for a weekend, which one?',
      'Which imaginary world would make our best short vacation?',
      'Where should our storybook couple adventure begin?',
      'Which fictional setting would you explore with me first?',
      'If a book opened into a doorway, which scene should be behind it?',
    ],
    options: <String>[
      'An enchanted forest',
      'A floating city',
      'A cozy village',
      'A seaside kingdom',
    ],
  ),
  _PromptPack.named(
    id: 225,
    questions: <String>[
      'If we had to enter a friendly talent show, what should our act be?',
      'Which duo performance would be funniest for us to prepare?',
      'What talent-show act could we make charming together?',
      'Which stage challenge would you brave with me?',
      'If the spotlight found us, what would we perform?',
    ],
    options: <String>[
      'A duet',
      'A comedy sketch',
      'A dance',
      'A cooking demo',
    ],
  ),
  _PromptPack.named(
    id: 226,
    questions: <String>[
      'If we could borrow one dream vehicle for a day, which one?',
      'Which unusual ride should carry us on an imaginary date?',
      'What magical transportation would make the best adventure?',
      'If roads and rules did not matter, how should we travel?',
      'Which fantasy vehicle would you want us to share?',
    ],
    options: <String>[
      'A tiny airship',
      'A vintage train',
      'A colorful boat',
      'A cozy camper',
    ],
  ),
  _PromptPack.named(
    id: 227,
    questions: <String>[
      'If one meal could appear perfectly prepared, which should we summon?',
      'What magical dinner delivery would delight us tonight?',
      'If the table filled itself, what cuisine should arrive?',
      'Which instant feast would make our evening best?',
      'If cooking took no effort today, what should we share?',
    ],
    options: <String>[
      'Comfort-food classics',
      'A noodle feast',
      'A breakfast spread',
      'A dessert buffet',
    ],
  ),
  _PromptPack.named(
    id: 228,
    questions: <String>[
      'If our day became a movie genre, which would you pick?',
      'What kind of film should today feel like for us?',
      'If cameras followed our next date, what genre would they capture?',
      'Which movie mood best suits our current chapter?',
      'What genre would make our ordinary day more entertaining?',
    ],
    options: <String>[
      'Cozy comedy',
      'Gentle adventure',
      'Sweet romance',
      'Playful mystery',
    ],
  ),
  _PromptPack.named(
    id: 229,
    questions: <String>[
      'If we could master one activity overnight, which should it be?',
      'Which instant skill would create the best dates for us?',
      'What ability would you download for our next weekend?',
      'If practice happened magically, what should we become good at?',
      'Which shared talent would be most exciting to wake up with?',
    ],
    options: <String>[
      'Dancing',
      'Photography',
      'Cooking',
      'Playing music',
    ],
  ),
  _PromptPack.named(
    id: 230,
    questions: <String>[
      'If our home had one secret room, what should be inside?',
      'Which hidden space would make our dream home more magical?',
      'What room should appear behind a mysterious little door?',
      'If we discovered extra space at home, how should we use it?',
      'Which secret corner would become our favorite?',
    ],
    options: <String>[
      'A tiny cinema',
      'A reading room',
      'An indoor garden',
      'A game room',
    ],
  ),
  _PromptPack.named(
    id: 231,
    questions: <String>[
      'If we could replay one kind of moment, which would you choose?',
      'What happy scene deserves a magical replay button?',
      'Which little memory would be sweetest to experience twice?',
      'If today offered one instant encore, what should return?',
      'Which type of moment would you gladly repeat with me?',
    ],
    options: <String>[
      'A shared laugh',
      'A peaceful hug',
      'A great meal',
      'A beautiful view',
    ],
  ),
  _PromptPack.named(
    id: 232,
    questions: <String>[
      'If we hosted a themed evening, which world should take over?',
      'What playful theme would make our home date unforgettable?',
      'Which imaginary event should we decorate for?',
      'If costumes were required tonight, what theme would you choose?',
      'Which themed night would bring out our most creative side?',
    ],
    options: <String>[
      'Retro diner',
      'Moonlit picnic',
      'Cozy fantasy',
      'Tropical holiday',
    ],
  ),
  _PromptPack.named(
    id: 233,
    questions: <String>[
      'If we could receive one message from future us, what should it contain?',
      'Which update would you most want older us to send back?',
      'What future note would make you smile today?',
      'If tomorrow could reassure us about one thing, what should it be?',
      'Which postcard from our future would you open first?',
    ],
    options: <String>[
      'A favorite memory',
      'A dream achieved',
      'A funny story',
      'A gentle reminder',
    ],
  ),
  _PromptPack.named(
    id: 234,
    questions: <String>[
      'If we invented a holiday just for us, how should we spend it?',
      'What activity belongs at the center of our imaginary celebration?',
      'Which tradition should define our made-up couple holiday?',
      'If calendars gave us a special day, what would we do?',
      'How should our personal holiday be celebrated every year?',
    ],
    options: <String>[
      'Revisit a favorite place',
      'Try something new',
      'Stay cozy all day',
      'Exchange tiny surprises',
    ],
  ),
  _PromptPack.named(
    id: 235,
    questions: <String>[
      'If our favorite snack became a landmark, what would we build?',
      'Which silly food-shaped place would be most fun to visit?',
      'What edible-looking attraction belongs in our imaginary town?',
      'If dessert inspired a building, which one should it be?',
      'Which playful food monument would make the best photo?',
    ],
    options: <String>[
      'A cookie cottage',
      'An ice-cream tower',
      'A noodle bridge',
      'A pancake castle',
    ],
  ),
  _PromptPack.named(
    id: 236,
    questions: <String>[
      'If we could control one part of the weather, what would we choose?',
      'Which weather button would improve our dates most?',
      'If today had a custom forecast, what should it be?',
      'Which bit of weather magic would create the nicest atmosphere?',
      'What forecast would you summon for our perfect afternoon?',
    ],
    options: <String>[
      'A golden sunset',
      'Gentle cool rain',
      'A soft breeze',
      'Clear starry skies',
    ],
  ),
  _PromptPack.named(
    id: 237,
    questions: <String>[
      'If we wrote a tiny book together, what should it be about?',
      'Which story would be the most fun for us to create?',
      'What shared book project best suits our imagination?',
      'If we became co-authors for a weekend, what would we make?',
      'Which kind of book would hold the most of our personality?',
    ],
    options: <String>[
      'Our funny memories',
      'A cozy fantasy',
      'A food adventure',
      'A book of kind notes',
    ],
  ),
  _PromptPack.named(
    id: 238,
    questions: <String>[
      'If our couple energy were a tiny cafe, what would it serve?',
      'Which menu best represents our relationship mood?',
      'What specialty belongs in a cafe inspired by us?',
      'If we designed one signature treat, what should it be?',
      'Which cafe offering would make our imaginary place famous?',
    ],
    options: <String>[
      'Comfort drinks',
      'Cute pastries',
      'Big breakfasts',
      'Surprise desserts',
    ],
  ),
  _PromptPack.named(
    id: 239,
    questions: <String>[
      'If we won a day with no responsibilities, what should come first?',
      'Which freedom-day plan would make us happiest?',
      'If every task disappeared until tomorrow, how should we celebrate?',
      'What would we do with a completely open day?',
      'Which carefree choice deserves our imaginary day off?',
    ],
    options: <String>[
      'Sleep and cuddle',
      'Go somewhere new',
      'Eat favorite foods',
      'Create something together',
    ],
  ),
  _PromptPack.named(
    id: 240,
    questions: <String>[
      'If we could add one charming feature to our neighborhood, which one?',
      'What imaginary local spot would improve our everyday life?',
      'Which place should appear within walking distance of home?',
      'If we could design one neighborhood corner, what would it be?',
      'Which nearby addition would give us the best mini dates?',
    ],
    options: <String>[
      'A pocket garden',
      'A late-night cafe',
      'A tiny cinema',
      'A weekend market',
    ],
  ),
  _PromptPack.named(
    id: 241,
    questions: <String>[
      'Which everyday thing are you most grateful we can share?',
      'What ordinary part of us feels especially precious today?',
      'Which simple shared comfort deserves extra appreciation?',
      'What part of daily life with me are you thankful for?',
      'Which little together-moment would you never want to overlook?',
    ],
    options: <String>[
      'Our conversations',
      'Our shared meals',
      'Our quiet company',
      'Our silly moments',
    ],
  ),
  _PromptPack.named(
    id: 242,
    questions: <String>[
      'Which kind gesture from me tends to stay with you longest?',
      'What form of everyday care do you appreciate most?',
      'Which small act makes you feel especially considered?',
      'What thoughtful habit deserves a little celebration?',
      'Which caring detail makes your day feel lighter?',
    ],
    options: <String>[
      'Checking in',
      'Remembering details',
      'Helping with a task',
      'Making time for me',
    ],
  ),
  _PromptPack.named(
    id: 243,
    questions: <String>[
      'Which recent kind of win should we celebrate more often?',
      'What small success deserves a cheerful little reward?',
      'Which everyday achievement should never go unnoticed?',
      'What type of progress deserves our proudest high-five?',
      'Which small victory would you happily toast together?',
    ],
    options: <String>[
      'Finishing a hard task',
      'Keeping a good habit',
      'Trying something new',
      'Handling a busy day',
    ],
  ),
  _PromptPack.named(
    id: 244,
    questions: <String>[
      'Which quality in our relationship are you most grateful for?',
      'What strength of ours feels especially valuable?',
      'Which part of our bond makes you feel fortunate?',
      'What shared quality helps us through ordinary days?',
      'Which relationship strength would you celebrate today?',
    ],
    options: <String>[
      'We can be honest',
      'We make each other laugh',
      'We keep showing up',
      'We grow together',
    ],
  ),
  _PromptPack.named(
    id: 245,
    questions: <String>[
      'Which person in our shared world deserves a thank-you soon?',
      'Who would you most like us to appreciate together?',
      'Which kind of supporter should receive a thoughtful message?',
      'Who has helped make our journey a little brighter?',
      'Which loved one deserves a small gratitude gesture from us?',
    ],
    options: <String>[
      'A family member',
      'A close friend',
      'A helpful mentor',
      'A kind neighbor',
    ],
  ),
  _PromptPack.named(
    id: 246,
    questions: <String>[
      'Which memory are you especially thankful we made?',
      'What kind of shared moment feels more valuable with time?',
      'Which memory category would fill our gratitude jar fastest?',
      'What past moment still gives you a warm feeling?',
      'Which part of our story are you happiest to have lived?',
    ],
    options: <String>[
      'A first together',
      'A funny mishap',
      'A peaceful day',
      'A challenge we handled',
    ],
  ),
  _PromptPack.named(
    id: 247,
    questions: <String>[
      'How should we celebrate an unexpectedly good day?',
      'Which tiny reward fits a day that went really well?',
      'What cheerful ritual should follow a happy surprise?',
      'How would you mark a little piece of good news?',
      'Which simple celebration sounds best right now?',
    ],
    options: <String>[
      'Get dessert',
      'Take a happy photo',
      'Play favorite music',
      'Plan a cozy evening',
    ],
  ),
  _PromptPack.named(
    id: 248,
    questions: <String>[
      'Which part of your present life feels most worth appreciating?',
      'What area of life would you place first in a gratitude note?',
      'Which current blessing brings you the most quiet joy?',
      'What part of today feels especially meaningful?',
      'Which everyday gift are you most aware of lately?',
    ],
    options: <String>[
      'People I love',
      'A safe place',
      'Room to grow',
      'Small daily comforts',
    ],
  ),
  _PromptPack.named(
    id: 249,
    questions: <String>[
      'Which compliment would you most enjoy celebrating about us?',
      'What positive description of our relationship feels most accurate?',
      'Which strength would you proudly put on our imaginary award?',
      'What makes our pair deserve a little applause?',
      'Which couple quality should get a gold star today?',
    ],
    options: <String>[
      'Best teamwork',
      'Warmest support',
      'Funniest duo',
      'Most creative dates',
    ],
  ),
  _PromptPack.named(
    id: 250,
    questions: <String>[
      'Which milestone deserves a handwritten note to each other?',
      'What kind of achievement should we record with thoughtful words?',
      'Which celebration would feel richer with a personal letter?',
      'What milestone should leave behind more than a photo?',
      'Which special day calls for a keepsake message?',
    ],
    options: <String>[
      'An anniversary',
      'A shared goal',
      'A personal success',
      'A fresh beginning',
    ],
  ),
  _PromptPack.named(
    id: 251,
    questions: <String>[
      'Which everyday sound are you unexpectedly grateful for?',
      'What familiar sound makes life feel comforting?',
      'Which bit of daily background noise would you miss?',
      'What sound quietly tells you that things are okay?',
      'Which ordinary sound gives you a sense of home?',
    ],
    options: <String>[
      'A loved one laughing',
      'Rain outside',
      'Food cooking',
      'Favorite music nearby',
    ],
  ),
  _PromptPack.named(
    id: 252,
    questions: <String>[
      'Which form of progress are you proudest of us for making?',
      'What kind of growth deserves our gratitude today?',
      'Which shared improvement feels most meaningful?',
      'What progress shows how far we have come together?',
      'Which part of our growth should we pause to appreciate?',
    ],
    options: <String>[
      'Communicating better',
      'Building routines',
      'Trying new things',
      'Supporting each other',
    ],
  ),
  _PromptPack.named(
    id: 253,
    questions: <String>[
      'Which celebration detail makes an occasion feel special to you?',
      'What little touch turns a milestone into a memory?',
      'Which festive detail would you plan first?',
      'What belongs at every meaningful celebration?',
      'Which element gives a happy event the most heart?',
    ],
    options: <String>[
      'A favorite meal',
      'Thoughtful decorations',
      'A shared playlist',
      'Personal messages',
    ],
  ),
  _PromptPack.named(
    id: 254,
    questions: <String>[
      'Which ability of yours are you grateful to have developed?',
      'What personal strength do you appreciate more as time passes?',
      'Which skill helps you enjoy life more fully?',
      'What part of yourself deserves a grateful nod today?',
      'Which strength has served you especially well?',
    ],
    options: <String>[
      'Patience',
      'Creativity',
      'Adaptability',
      'Warmth',
    ],
  ),
  _PromptPack.named(
    id: 255,
    questions: <String>[
      'Which shared convenience are you glad exists in our lives?',
      'What modern helper makes together-time easier?',
      'Which everyday tool deserves more appreciation?',
      'What useful thing quietly improves our daily connection?',
      'Which convenience would be hardest to give up for a week?',
    ],
    options: <String>[
      'Instant messaging',
      'Maps and directions',
      'Food delivery',
      'Photo sharing',
    ],
  ),
  _PromptPack.named(
    id: 256,
    questions: <String>[
      'Which kind of day should end with a mini celebration?',
      'What ordinary occasion deserves its own cheerful ritual?',
      'Which day would feel better with a tiny reward at the end?',
      'What routine achievement should we make more festive?',
      'Which everyday finish line deserves a treat?',
    ],
    options: <String>[
      'A productive day',
      'A difficult day',
      'A caring day',
      'A surprisingly fun day',
    ],
  ),
  _PromptPack.named(
    id: 257,
    questions: <String>[
      'Which natural detail are you most grateful to notice?',
      'What small part of nature improves your mood fastest?',
      'Which outdoor sight feels like a quiet gift?',
      'What piece of nature would you pause to appreciate today?',
      'Which simple natural beauty makes an ordinary day better?',
    ],
    options: <String>[
      'Colorful skies',
      'Green leaves',
      'Moving water',
      'Tiny flowers',
    ],
  ),
  _PromptPack.named(
    id: 258,
    questions: <String>[
      'Which kind of support are you thankful we can give each other?',
      'What shared support makes challenges feel more manageable?',
      'Which form of encouragement strengthens our team most?',
      'What do you value about having someone beside you?',
      'Which supportive habit deserves our appreciation?',
    ],
    options: <String>[
      'Listening patiently',
      'Offering perspective',
      'Sharing the load',
      'Celebrating progress',
    ],
  ),
  _PromptPack.named(
    id: 259,
    questions: <String>[
      'Which surprise good thing would you celebrate immediately?',
      'What happy update would call for an instant treat?',
      'Which unexpected win would make you do a little dance?',
      'What kind of news would brighten our entire week?',
      'Which pleasant surprise deserves the loudest cheer?',
    ],
    options: <String>[
      'Extra free time',
      'A goal completed',
      'A lovely invitation',
      'A thoughtful message',
    ],
  ),
  _PromptPack.named(
    id: 260,
    questions: <String>[
      'Which gratitude habit would you most like us to try?',
      'What simple practice could help us notice more good things?',
      'Which thankful ritual would fit naturally into our routine?',
      'How should we make appreciation more visible in our days?',
      'Which gratitude practice sounds most enjoyable together?',
    ],
    options: <String>[
      'A weekly note',
      'A gratitude jar',
      'One good thing nightly',
      'Thank-you messages',
    ],
  ),
  _PromptPack.named(
    id: 261,
    questions: <String>[
      'Which photo theme would be most fun for us to try next?',
      'What kind of couple picture should we plan soon?',
      'Which photo idea would capture our energy best?',
      'What mini photo challenge sounds most playful?',
      'Which picture style belongs in our next shared album?',
    ],
    options: <String>[
      'Cozy candid',
      'Color-coordinated',
      'Funny poses',
      'Outdoor portrait',
    ],
  ),
  _PromptPack.named(
    id: 262,
    questions: <String>[
      'Which everyday moment deserves more photos?',
      'What ordinary scene would future us be happy we captured?',
      'Which little part of our routine belongs in an album?',
      'What normal moment could become a treasured picture?',
      'Which slice of daily life should we photograph more often?',
    ],
    options: <String>[
      'Shared meals',
      'Lazy mornings',
      'Small outings',
      'Making things together',
    ],
  ),
  _PromptPack.named(
    id: 263,
    questions: <String>[
      'Which creative project would make the sweetest keepsake?',
      'What should we make together to remember this chapter?',
      'Which handmade item would feel most personal?',
      'What creative date could leave us with something lasting?',
      'Which shared craft would you proudly keep?',
    ],
    options: <String>[
      'A scrapbook',
      'A painted canvas',
      'A memory box',
      'A tiny photo book',
    ],
  ),
  _PromptPack.named(
    id: 264,
    questions: <String>[
      'Which color palette best represents us today?',
      'What set of colors would you use for a picture of our mood?',
      'Which palette belongs on our imaginary couple poster?',
      'What color story fits our current chapter?',
      'Which group of shades feels most like our shared energy?',
    ],
    options: <String>[
      'Soft pastels',
      'Bright tropicals',
      'Earthy greens',
      'Bold jewel tones',
    ],
  ),
  _PromptPack.named(
    id: 265,
    questions: <String>[
      'Which kind of candid photo do you love most?',
      'What unposed moment makes the best picture?',
      'Which candid scene feels most genuine to you?',
      'What natural expression would you want a camera to catch?',
      'Which spontaneous photo would make you smile later?',
    ],
    options: <String>[
      'Laughing together',
      'Focused on a task',
      'Looking at the view',
      'Sharing a snack',
    ],
  ),
  _PromptPack.named(
    id: 266,
    questions: <String>[
      'Which artistic date would you be most excited to try?',
      'What creative outing could inspire both of us?',
      'Which art-centered plan sounds like the best date?',
      'What kind of creative place should we visit together?',
      'Which artistic activity would make a memorable afternoon?',
    ],
    options: <String>[
      'Museum visit',
      'Pottery class',
      'Photo walk',
      'Live performance',
    ],
  ),
  _PromptPack.named(
    id: 267,
    questions: <String>[
      'Which photo location would give us the nicest natural backdrop?',
      'Where should we take our next favorite outdoor picture?',
      'Which setting would make a lovely couple portrait?',
      'What background fits a relaxed photo date?',
      'Which place would bring the best light and mood?',
    ],
    options: <String>[
      'A leafy park',
      'A colorful street',
      'A quiet beach',
      'A cozy cafe',
    ],
  ),
  _PromptPack.named(
    id: 268,
    questions: <String>[
      'Which kind of playlist would you most enjoy making together?',
      'What shared music collection should we curate next?',
      'Which playlist theme would tell the best story about us?',
      'What group of songs deserves its own couple playlist?',
      'Which listening project sounds most fun to build?',
    ],
    options: <String>[
      'Songs from our memories',
      'Cozy evening tracks',
      'Road-trip favorites',
      'Happy dance songs',
    ],
  ),
  _PromptPack.named(
    id: 269,
    questions: <String>[
      'Which creative challenge would make us laugh most?',
      'What playful art contest should we try at home?',
      'Which tiny competition would bring out our imagination?',
      'What creative prompt would make a fun couple challenge?',
      'Which silly making activity should have a friendly winner?',
    ],
    options: <String>[
      'Draw each other',
      'Decorate cupcakes',
      'Build with paper',
      'Style funny outfits',
    ],
  ),
  _PromptPack.named(
    id: 270,
    questions: <String>[
      'Which memory would be most fun to recreate in a photo?',
      'What past moment deserves a playful then-and-now picture?',
      'Which old scene should we restage together?',
      'What kind of memory would make the cutest photo remake?',
      'Which throwback picture idea would delight future us?',
    ],
    options: <String>[
      'Our first outing',
      'A funny pose',
      'A favorite meal',
      'A holiday moment',
    ],
  ),
  _PromptPack.named(
    id: 271,
    questions: <String>[
      'Which handmade gift would you most enjoy creating together?',
      'What small craft could we make for someone we love?',
      'Which creative present would feel especially thoughtful?',
      'What shared project would make the sweetest gift?',
      'Which handmade surprise should we try producing as a team?',
    ],
    options: <String>[
      'A decorated card',
      'A baked treat',
      'A framed photo',
      'A small painted item',
    ],
  ),
  _PromptPack.named(
    id: 272,
    questions: <String>[
      'Which visual detail catches your eye first in a beautiful place?',
      'What do you naturally notice when taking a photo?',
      'Which part of a scene inspires your creative side most?',
      'What visual element makes you stop and look longer?',
      'Which detail would guide your perfect picture?',
    ],
    options: <String>[
      'Light and shadows',
      'Colors',
      'Tiny details',
      'People and expressions',
    ],
  ),
  _PromptPack.named(
    id: 273,
    questions: <String>[
      'Which kind of couple video would be most fun to make?',
      'What short video idea would capture our personality?',
      'Which moving-memory project should we try someday?',
      'What playful clip would future us enjoy watching?',
      'Which video format sounds easiest and most charming?',
    ],
    options: <String>[
      'A day-in-our-life',
      'A food review',
      'A travel montage',
      'A silly challenge',
    ],
  ),
  _PromptPack.named(
    id: 274,
    questions: <String>[
      'Which creative space would you want in our dream home?',
      'What making corner would encourage us to try new projects?',
      'Which artistic area would get the most use from us?',
      'What creative nook belongs in our shared space?',
      'Which room setup would inspire the best hobbies?',
    ],
    options: <String>[
      'An art desk',
      'A music corner',
      'A photo wall',
      'A craft cabinet',
    ],
  ),
  _PromptPack.named(
    id: 275,
    questions: <String>[
      'Which kind of story should accompany our favorite photos?',
      'What caption style would make an album feel most personal?',
      'Which words belong beneath our shared memories?',
      'How should we describe a meaningful photo years later?',
      'Which album note would be most enjoyable to write?',
    ],
    options: <String>[
      'A funny detail',
      'How we felt',
      'What happened next',
      'A short love note',
    ],
  ),
  _PromptPack.named(
    id: 276,
    questions: <String>[
      'Which creative medium would you like to explore with me?',
      'What art form sounds most approachable for a shared beginner date?',
      'Which kind of making would help us express ourselves?',
      'What creative skill should we experiment with next?',
      'Which medium would give us the most interesting results?',
    ],
    options: <String>[
      'Watercolor',
      'Clay',
      'Digital drawing',
      'Collage',
    ],
  ),
  _PromptPack.named(
    id: 277,
    questions: <String>[
      'Which tiny detail makes a photo feel more romantic?',
      'What subtle element gives a couple picture extra warmth?',
      'Which visual touch would make our photo feel special?',
      'What detail should we include in a meaningful portrait?',
      'Which small choice creates the sweetest photo mood?',
    ],
    options: <String>[
      'Holding hands',
      'A shared glance',
      'Soft natural light',
      'A familiar place',
    ],
  ),
  _PromptPack.named(
    id: 278,
    questions: <String>[
      'Which memory display would you most like at home?',
      'How should we show a few of our favorite moments?',
      'Which photo arrangement would make our space feel personal?',
      'What kind of display would you enjoy updating together?',
      'Which memory corner best fits our home style?',
    ],
    options: <String>[
      'A gallery wall',
      'A rotating frame',
      'A corkboard',
      'A shelf of albums',
    ],
  ),
  _PromptPack.named(
    id: 279,
    questions: <String>[
      'Which creative tradition should we repeat every year?',
      'What annual project would beautifully track our story?',
      'Which making ritual could become a favorite anniversary habit?',
      'What yearly keepsake would be worth the effort?',
      'Which creative routine would help us notice how we grow?',
    ],
    options: <String>[
      'A yearly portrait',
      'A highlight video',
      'A shared illustration',
      'A memory scrapbook page',
    ],
  ),
  _PromptPack.named(
    id: 280,
    questions: <String>[
      'Which kind of inspiration would you collect on a shared mood board?',
      'What topic deserves a visual board made by both of us?',
      'Which dream would be fun to explore through pictures?',
      'What shared idea should we turn into a collage?',
      'Which mood-board theme would spark the best conversation?',
    ],
    options: <String>[
      'Future travels',
      'A cozy home',
      'Date ideas',
      'Creative goals',
    ],
  ),
  _PromptPack.named(
    id: 281,
    questions: <String>[
      'Which small habit would make your days feel gentler?',
      'What simple routine could improve your everyday wellbeing?',
      'Which tiny change would give you more breathing room?',
      'What healthy habit feels realistic to build next?',
      'Which daily practice would help you feel more balanced?',
    ],
    options: <String>[
      'Drink more water',
      'Take short walks',
      'Rest on time',
      'Pause without screens',
    ],
  ),
  _PromptPack.named(
    id: 282,
    questions: <String>[
      'Which kind of encouragement helps you try again?',
      'What reminder supports you best when progress feels slow?',
      'Which message would help you keep moving gently?',
      'What kind thought makes a difficult task feel possible?',
      'Which encouragement would you want on a challenging day?',
    ],
    options: <String>[
      'Small steps still count',
      'You can take your time',
      'I believe in you',
      'We can figure it out',
    ],
  ),
  _PromptPack.named(
    id: 283,
    questions: <String>[
      'Which way of recharging works best after a full day?',
      'What helps your energy return most naturally?',
      'Which quiet reset leaves you feeling refreshed?',
      'What kind of break does your mind appreciate most?',
      'Which wind-down would you choose when you need recovery?',
    ],
    options: <String>[
      'A good nap',
      'Alone time',
      'Gentle conversation',
      'A favorite hobby',
    ],
  ),
  _PromptPack.named(
    id: 284,
    questions: <String>[
      'Which personal quality would you most like to strengthen?',
      'What kind of inner growth feels useful right now?',
      'Which trait would help you navigate this chapter?',
      'What personal skill deserves gentle practice?',
      'Which quality would you be proud to develop further?',
    ],
    options: <String>[
      'Patience',
      'Confidence',
      'Consistency',
      'Openness',
    ],
  ),
  _PromptPack.named(
    id: 285,
    questions: <String>[
      'Which shared wellness habit would be nicest to build together?',
      'What healthy routine could feel more fun as a pair?',
      'Which caring habit would support both of our days?',
      'What wellbeing goal would benefit from teamwork?',
      'Which gentle routine should we encourage in each other?',
    ],
    options: <String>[
      'Regular walks',
      'Better sleep',
      'Balanced meals',
      'Quiet check-ins',
    ],
  ),
  _PromptPack.named(
    id: 286,
    questions: <String>[
      'Which kind of break helps you return to a task refreshed?',
      'What short pause works best when your focus fades?',
      'Which mini reset would you choose during a busy day?',
      'What brief activity helps clear your head?',
      'Which break style keeps your day moving comfortably?',
    ],
    options: <String>[
      'Stretch and breathe',
      'Get a snack',
      'Step outside',
      'Listen to one song',
    ],
  ),
  _PromptPack.named(
    id: 287,
    questions: <String>[
      'Which kind of progress motivates you most?',
      'What sign of improvement makes you want to continue?',
      'Which small result gives you the biggest boost?',
      'What kind of progress feels most rewarding to notice?',
      'Which win helps you trust the process?',
    ],
    options: <String>[
      'A visible result',
      'A steady streak',
      'Positive feedback',
      'Feeling more capable',
    ],
  ),
  _PromptPack.named(
    id: 288,
    questions: <String>[
      'Which peaceful activity would you like more time for?',
      'What quiet pastime would make your week feel softer?',
      'Which calming activity deserves a place in your routine?',
      'What gentle hobby would help you slow down?',
      'Which peaceful moment would you happily schedule?',
    ],
    options: <String>[
      'Reading',
      'Gardening',
      'Sketching',
      'Listening to music',
    ],
  ),
  _PromptPack.named(
    id: 289,
    questions: <String>[
      'Which boundary helps you protect your energy best?',
      'What simple limit makes everyday life feel healthier?',
      'Which kind of boundary would give you more balance?',
      'What personal rule helps you stay present?',
      'Which gentle boundary deserves more consistency?',
    ],
    options: <String>[
      'Time to rest',
      'Fewer notifications',
      'A clear work ending',
      'Space to think',
    ],
  ),
  _PromptPack.named(
    id: 290,
    questions: <String>[
      'Which morning habit gives you the best start?',
      'What early routine most improves your mood?',
      'Which small morning action helps you feel ready?',
      'What start-of-day practice would you like to keep?',
      'Which morning reset makes the rest of the day easier?',
    ],
    options: <String>[
      'Drink water',
      'Open the curtains',
      'Plan one priority',
      'Move a little',
    ],
  ),
  _PromptPack.named(
    id: 291,
    questions: <String>[
      'Which kind of support helps you build a new habit?',
      'What encouragement makes consistency feel easier?',
      'Which support style would help you reach a gentle goal?',
      'How can a partner best cheer on your progress?',
      'Which form of accountability feels kindest to you?',
    ],
    options: <String>[
      'Friendly reminders',
      'Join me sometimes',
      'Celebrate small wins',
      'Ask how it is going',
    ],
  ),
  _PromptPack.named(
    id: 292,
    questions: <String>[
      'Which evening habit helps you sleep more peacefully?',
      'What bedtime routine best tells your mind to slow down?',
      'Which nighttime practice would improve your rest?',
      'What gentle habit belongs in your ideal evening?',
      'Which wind-down step would be easiest to keep?',
    ],
    options: <String>[
      'Dim the lights',
      'Put the phone away',
      'Take a warm shower',
      'Read something calm',
    ],
  ),
  _PromptPack.named(
    id: 293,
    questions: <String>[
      'Which kind of new experience helps you grow most?',
      'What gentle challenge would stretch you in a good way?',
      'Which unfamiliar activity would build your confidence?',
      'What growth experience would you willingly try?',
      'Which challenge sounds both useful and enjoyable?',
    ],
    options: <String>[
      'Learn publicly',
      'Travel somewhere new',
      'Lead a small project',
      'Meet new people',
    ],
  ),
  _PromptPack.named(
    id: 294,
    questions: <String>[
      'Which reminder helps you be kinder to yourself?',
      'What thought makes room for a gentler inner voice?',
      'Which message would you keep for an imperfect day?',
      'What self-kindness reminder feels most useful?',
      'Which sentence would help you release unnecessary pressure?',
    ],
    options: <String>[
      'Rest is productive too',
      'Nobody gets it perfect',
      'My effort matters',
      'Tomorrow is another chance',
    ],
  ),
  _PromptPack.named(
    id: 295,
    questions: <String>[
      'Which kind of movement feels most enjoyable to you?',
      'What active break would you actually look forward to?',
      'Which movement would make wellbeing feel playful?',
      'What gentle activity could become a pleasant habit?',
      'Which way of moving would lift your mood fastest?',
    ],
    options: <String>[
      'A relaxed walk',
      'Dancing at home',
      'Stretching',
      'An easy bike ride',
    ],
  ),
  _PromptPack.named(
    id: 296,
    questions: <String>[
      'Which mental reset works best when a day feels crowded?',
      'What helps you find a little calm amid many tasks?',
      'Which simple practice clears some headspace?',
      'What reset would you choose before continuing a busy day?',
      'Which calming action helps you return to the present?',
    ],
    options: <String>[
      'Write a short list',
      'Take slow breaths',
      'Tidy one small area',
      'Talk it through',
    ],
  ),
  _PromptPack.named(
    id: 297,
    questions: <String>[
      'Which area of life would you most enjoy simplifying?',
      'What could become easier with a little less complexity?',
      'Which everyday area deserves a simpler system?',
      'What part of your routine would benefit from fewer choices?',
      'Which kind of simplicity would bring the most relief?',
    ],
    options: <String>[
      'Daily schedule',
      'Home organization',
      'Meal planning',
      'Digital clutter',
    ],
  ),
  _PromptPack.named(
    id: 298,
    questions: <String>[
      'Which sign tells you that you truly need a break?',
      'What clue helps you notice when your energy is low?',
      'Which signal should remind you to slow down?',
      'What usually tells you it is time to recharge?',
      'Which early sign would you like to respect more?',
    ],
    options: <String>[
      'I lose focus',
      'I get unusually quiet',
      'Everything feels rushed',
      'Small tasks feel heavy',
    ],
  ),
  _PromptPack.named(
    id: 299,
    questions: <String>[
      'Which shared check-in question feels most caring?',
      'What should we ask each other more regularly?',
      'Which question creates space for an honest little update?',
      'What gentle check-in would help us stay connected?',
      'Which caring question would improve a busy day?',
    ],
    options: <String>[
      'How is your energy?',
      'What do you need today?',
      'What felt good lately?',
      'How can I help?',
    ],
  ),
  _PromptPack.named(
    id: 300,
    questions: <String>[
      'Which part of personal growth do you find most rewarding?',
      'What kind of change makes the effort feel worthwhile?',
      'Which sign of growth brings you the most satisfaction?',
      'What outcome makes you proud of your progress?',
      'Which result shows that inner work is paying off?',
    ],
    options: <String>[
      'More calm',
      'Better choices',
      'Greater confidence',
      'Stronger connections',
    ],
  ),
  _PromptPack.named(
    id: 301,
    questions: <String>[
      'Which season-like mood would make the nicest date today?',
      'What seasonal atmosphere are you craving most?',
      'Which kind of day would create the coziest plan for us?',
      'What seasonal feeling best matches your current mood?',
      'Which atmosphere should inspire our next date?',
    ],
    options: <String>[
      'Fresh spring morning',
      'Bright summer day',
      'Golden autumn evening',
      'Cool winter night',
    ],
  ),
  _PromptPack.named(
    id: 302,
    questions: <String>[
      'Which outdoor view helps you feel most peaceful?',
      'What natural scene would you happily sit beside for an hour?',
      'Which landscape would quiet your thoughts fastest?',
      'What view would make the best calm date backdrop?',
      'Which piece of nature would you choose for a restful escape?',
    ],
    options: <String>[
      'A wide ocean',
      'Green hills',
      'Tall trees',
      'A quiet lake',
    ],
  ),
  _PromptPack.named(
    id: 303,
    questions: <String>[
      'Which rainy-day plan sounds most comforting?',
      'What should we do while rain taps against the windows?',
      'Which cozy activity best matches a gray afternoon?',
      'How would you turn a wet day into a lovely date?',
      'Which rain-friendly plan would you choose for us?',
    ],
    options: <String>[
      'Watch a movie',
      'Cook warm food',
      'Take a careful walk',
      'Nap and listen',
    ],
  ),
  _PromptPack.named(
    id: 304,
    questions: <String>[
      'Which flower would you most enjoy seeing fill a garden?',
      'What bloom would create the loveliest date setting?',
      'Which flower color would brighten our shared space?',
      'What kind of blossom would you happily photograph?',
      'Which flower belongs in an imaginary garden made for us?',
    ],
    options: <String>[
      'Sunflowers',
      'Roses',
      'Daisies',
      'Lavender',
    ],
  ),
  _PromptPack.named(
    id: 305,
    questions: <String>[
      'Which time outdoors would give us the prettiest light?',
      'When should we take a slow nature walk together?',
      'Which outdoor hour feels most magical to you?',
      'What time of day would make a simple view unforgettable?',
      'Which natural light would you choose for our next photo?',
    ],
    options: <String>[
      'Soft sunrise',
      'Bright midday',
      'Golden hour',
      'Starry night',
    ],
  ),
  _PromptPack.named(
    id: 306,
    questions: <String>[
      'Which nature sound would you play while relaxing?',
      'What outdoor sound creates the calmest atmosphere?',
      'Which natural soundtrack would help you unwind?',
      'What sound from nature would make home feel peaceful?',
      'Which gentle background noise would you choose tonight?',
    ],
    options: <String>[
      'Ocean waves',
      'Falling rain',
      'Rustling leaves',
      'A flowing stream',
    ],
  ),
  _PromptPack.named(
    id: 307,
    questions: <String>[
      'Which warm-weather treat would complete our day?',
      'What refreshing snack belongs on a sunny date?',
      'Which cool treat would you pick after an outdoor walk?',
      'What summer-style bite would make us happiest?',
      'Which sunny-day treat should we share?',
    ],
    options: <String>[
      'Fresh fruit',
      'Ice cream',
      'Iced drinks',
      'A cold dessert',
    ],
  ),
  _PromptPack.named(
    id: 308,
    questions: <String>[
      'Which cool-weather comfort sounds best for us?',
      'What would make a chilly evening feel especially cozy?',
      'Which warm detail belongs in our ideal cold-day date?',
      'How should we enjoy a pleasantly cool night?',
      'Which comfort would you reach for when the air turns crisp?',
    ],
    options: <String>[
      'A warm blanket',
      'A hot drink',
      'A comforting meal',
      'A long cuddle',
    ],
  ),
  _PromptPack.named(
    id: 309,
    questions: <String>[
      'Which outdoor picnic setting would you choose?',
      'Where should we spread a blanket for a peaceful meal?',
      'Which picnic spot would create the best afternoon?',
      'What natural setting makes eating outside most appealing?',
      'Which location belongs in our next picnic plan?',
    ],
    options: <String>[
      'Under a big tree',
      'Beside the water',
      'In a flower garden',
      'On a hilltop',
    ],
  ),
  _PromptPack.named(
    id: 310,
    questions: <String>[
      'Which tiny outdoor discovery would delight you most?',
      'What little nature find would make you stop during a walk?',
      'Which small detail would you excitedly point out to me?',
      'What natural surprise would brighten our outing?',
      'Which quiet discovery deserves a closer look?',
    ],
    options: <String>[
      'A perfect leaf',
      'A tiny flower',
      'A colorful stone',
      'A beautiful cloud',
    ],
  ),
  _PromptPack.named(
    id: 311,
    questions: <String>[
      'Which sunrise plan would be worth waking up early for?',
      'What morning activity should accompany a beautiful sunrise?',
      'Which early outing would make the sleepy start worthwhile?',
      'How would you most enjoy watching the day begin?',
      'Which sunrise date sounds sweetest?',
    ],
    options: <String>[
      'Beach breakfast',
      'Hilltop coffee',
      'A quiet drive',
      'A balcony cuddle',
    ],
  ),
  _PromptPack.named(
    id: 312,
    questions: <String>[
      'Which sunset plan feels most romantic?',
      'How should we spend the last golden light of the day?',
      'Which evening setting would make a sunset extra memorable?',
      'What should we bring to a sunset date?',
      'Which golden-hour moment would you choose for us?',
    ],
    options: <String>[
      'Walk hand in hand',
      'Share a snack',
      'Take photos',
      'Sit and talk',
    ],
  ),
  _PromptPack.named(
    id: 313,
    questions: <String>[
      'Which kind of garden would you most like to explore?',
      'What garden setting would make the loveliest slow date?',
      'Which planted space would inspire your curiosity?',
      'Where would you happily wander among leaves and flowers?',
      'Which garden style feels most magical to you?',
    ],
    options: <String>[
      'A tropical garden',
      'A rose garden',
      'A vegetable garden',
      'A wildflower garden',
    ],
  ),
  _PromptPack.named(
    id: 314,
    questions: <String>[
      'Which starry-night activity would you enjoy most?',
      'What should we do beneath a clear night sky?',
      'Which nighttime plan would make the stars feel special?',
      'How would you spend a peaceful evening outdoors with me?',
      'Which starlit date belongs on our list?',
    ],
    options: <String>[
      'Find constellations',
      'Share stories',
      'Listen to music',
      'Make quiet wishes',
    ],
  ),
  _PromptPack.named(
    id: 315,
    questions: <String>[
      'Which nature-inspired color would you use in a cozy room?',
      'What outdoor shade would make a home space feel calm?',
      'Which natural color best suits our shared style?',
      'What earthy tone would you happily decorate with?',
      'Which color from nature feels most comforting?',
    ],
    options: <String>[
      'Leaf green',
      'Ocean blue',
      'Sunset pink',
      'Cloud white',
    ],
  ),
  _PromptPack.named(
    id: 316,
    questions: <String>[
      'Which mild outdoor adventure sounds most enjoyable?',
      'What nature activity would be easy and refreshing?',
      'Which outing would give us a gentle sense of adventure?',
      'What outdoor plan balances movement and relaxation?',
      'Which nature date would you choose for a free morning?',
    ],
    options: <String>[
      'A forest trail',
      'A paddle ride',
      'A scenic bike path',
      'A garden walk',
    ],
  ),
  _PromptPack.named(
    id: 317,
    questions: <String>[
      'Which seasonal tradition would you most like us to create?',
      'What yearly nature ritual sounds charming?',
      'Which outdoor tradition could mark the passing seasons?',
      'What recurring seasonal date would you anticipate?',
      'Which yearly activity belongs in our couple calendar?',
    ],
    options: <String>[
      'Plant something',
      'Take a seasonal photo',
      'Visit a favorite view',
      'Cook seasonal food',
    ],
  ),
  _PromptPack.named(
    id: 318,
    questions: <String>[
      'Which kind of sky do you find most beautiful?',
      'What sky would make you pause and take a picture?',
      'Which overhead view creates the strongest mood for you?',
      'What kind of sky belongs above our perfect date?',
      'Which sky scene would you most enjoy watching together?',
    ],
    options: <String>[
      'Soft pink clouds',
      'Clear bright blue',
      'Dramatic storm clouds',
      'Deep starry black',
    ],
  ),
  _PromptPack.named(
    id: 319,
    questions: <String>[
      'Which eco-friendly habit would be easiest for us to share?',
      'What small earth-friendly action fits our routine best?',
      'Which green habit could become a satisfying team effort?',
      'How could we care for our surroundings in a simple way?',
      'Which sustainable practice sounds most realistic for us?',
    ],
    options: <String>[
      'Carry reusable items',
      'Waste less food',
      'Grow a few plants',
      'Walk short distances',
    ],
  ),
  _PromptPack.named(
    id: 320,
    questions: <String>[
      'Which nature moment would make you feel most present?',
      'What outdoor experience helps the rest of the world feel quiet?',
      'Which natural scene would invite you to slow down?',
      'What moment outside would help you fully notice today?',
      'Which peaceful encounter with nature sounds best?',
    ],
    options: <String>[
      'Watching waves',
      'Feeling a breeze',
      'Listening to rain',
      'Seeing the first light',
    ],
  ),
  _PromptPack.named(
    id: 321,
    questions: <String>[
      'Which part of a busy day would you most like help with?',
      'What kind of support makes a packed schedule easier?',
      'Which daily pressure could teamwork lighten most?',
      'What task would feel better with a little assistance?',
      'Which busy-day burden should we share when possible?',
    ],
    options: <String>[
      'Planning priorities',
      'Preparing food',
      'Running errands',
      'Remembering breaks',
    ],
  ),
  _PromptPack.named(
    id: 322,
    questions: <String>[
      'Which workday check-in would feel most encouraging?',
      'What short message would improve a busy afternoon?',
      'Which little note would help you feel supported while working?',
      'What kind of check-in would make you smile during the day?',
      'Which message belongs in a thoughtful work break?',
    ],
    options: <String>[
      'You have got this',
      'Remember to eat',
      'Thinking of you',
      'Proud of your effort',
    ],
  ),
  _PromptPack.named(
    id: 323,
    questions: <String>[
      'Which start-of-day habit helps you feel organized?',
      'What routine keeps a full day from feeling scattered?',
      'Which morning step gives your schedule the most structure?',
      'What planning habit makes work feel more manageable?',
      'Which early action helps you begin with clarity?',
    ],
    options: <String>[
      'Choose three priorities',
      'Check the calendar',
      'Prepare the workspace',
      'Start with an easy task',
    ],
  ),
  _PromptPack.named(
    id: 324,
    questions: <String>[
      'Which kind of workspace would help you feel happiest?',
      'What desk atmosphere brings out your best focus?',
      'Which work setting would make long tasks more pleasant?',
      'What environment would you design for a productive day?',
      'Which workspace detail matters most to your mood?',
    ],
    options: <String>[
      'Bright and tidy',
      'Cozy and personal',
      'Quiet and minimal',
      'Lively and social',
    ],
  ),
  _PromptPack.named(
    id: 325,
    questions: <String>[
      'Which kind of task do you prefer to finish first?',
      'What work item would you tackle at the start of the day?',
      'Which task order best matches your productivity style?',
      'What type of job gets your freshest attention?',
      'Which first task makes the rest of your list feel easier?',
    ],
    options: <String>[
      'The hardest one',
      'The quickest one',
      'The most creative one',
      'The most urgent one',
    ],
  ),
  _PromptPack.named(
    id: 326,
    questions: <String>[
      'Which after-work ritual helps you shift into home mode?',
      'What signals that the busy part of your day is over?',
      'Which transition would help you leave work thoughts behind?',
      'What end-of-day habit makes relaxation easier?',
      'Which little ritual should begin our evening?',
    ],
    options: <String>[
      'Change into comfy clothes',
      'Take a short walk',
      'Share the day',
      'Play relaxing music',
    ],
  ),
  _PromptPack.named(
    id: 327,
    questions: <String>[
      'Which routine task would be more fun with a playful twist?',
      'What repeated chore deserves a little entertainment?',
      'Which everyday job could use music or a game?',
      'What routine should we make less boring together?',
      'Which task would benefit most from cheerful teamwork?',
    ],
    options: <String>[
      'Cleaning',
      'Meal prep',
      'Commuting',
      'Organizing files',
    ],
  ),
  _PromptPack.named(
    id: 328,
    questions: <String>[
      'Which lunch-break plan would refresh you most?',
      'What midday pause would improve your workday?',
      'Which quick break sounds best between tasks?',
      'How would you spend a genuinely restful lunch hour?',
      'Which midday reset would help your afternoon?',
    ],
    options: <String>[
      'Eat away from screens',
      'Take a short walk',
      'Chat with someone',
      'Rest quietly',
    ],
  ),
  _PromptPack.named(
    id: 329,
    questions: <String>[
      'Which shared planning tool would be most useful for us?',
      'What system could keep our routines coordinated?',
      'Which organizing habit would make teamwork smoother?',
      'What shared tool would help us remember everyday plans?',
      'Which planning method best fits our life together?',
    ],
    options: <String>[
      'A shared calendar',
      'A simple checklist',
      'A weekly chat',
      'A note on the fridge',
    ],
  ),
  _PromptPack.named(
    id: 330,
    questions: <String>[
      'Which kind of productive date sounds most satisfying?',
      'What useful activity could still feel like quality time?',
      'Which goal-oriented plan would you enjoy doing together?',
      'What productive outing could double as a date?',
      'Which shared task would leave us happy and accomplished?',
    ],
    options: <String>[
      'Shop for the week',
      'Plan a future trip',
      'Refresh a room',
      'Learn a useful skill',
    ],
  ),
  _PromptPack.named(
    id: 331,
    questions: <String>[
      'Which sign tells you a workday went well?',
      'What result makes you feel satisfied at the end of a busy day?',
      'Which measure of a good day matters most to you?',
      'What would make you close your tasks feeling content?',
      'Which outcome gives you the strongest sense of progress?',
    ],
    options: <String>[
      'Important work moved',
      'I helped someone',
      'I learned something',
      'I kept my balance',
    ],
  ),
  _PromptPack.named(
    id: 332,
    questions: <String>[
      'Which repetitive decision would you most like to simplify?',
      'What daily choice takes more energy than it should?',
      'Which routine decision could use an easy default?',
      'What recurring choice would you happily automate?',
      'Which tiny decision deserves a simpler system?',
    ],
    options: <String>[
      'What to eat',
      'What to wear',
      'When to do chores',
      'What task comes first',
    ],
  ),
  _PromptPack.named(
    id: 333,
    questions: <String>[
      'Which kind of work accomplishment would you most enjoy celebrating?',
      'What professional win deserves a special dinner?',
      'Which career moment would make you feel especially proud?',
      'What work milestone should never pass without a cheer?',
      'Which achievement would you want us to mark together?',
    ],
    options: <String>[
      'Completing a big project',
      'Learning a new skill',
      'Receiving kind feedback',
      'Reaching a personal goal',
    ],
  ),
  _PromptPack.named(
    id: 334,
    questions: <String>[
      'Which day-planning style feels best to you?',
      'How much structure helps your routine run comfortably?',
      'Which schedule approach matches your natural rhythm?',
      'What kind of plan keeps you focused without feeling trapped?',
      'Which daily structure would you choose most often?',
    ],
    options: <String>[
      'Detailed schedule',
      'A few key blocks',
      'One main priority',
      'Mostly spontaneous',
    ],
  ),
  _PromptPack.named(
    id: 335,
    questions: <String>[
      'Which small morning favor would help you most?',
      'What thoughtful gesture could make your start easier?',
      'Which bit of practical care would improve a busy morning?',
      'What little help would you appreciate before the day begins?',
      'Which morning kindness would feel most supportive?',
    ],
    options: <String>[
      'Prepare a drink',
      'Pack a snack',
      'Send a reminder',
      'Offer a warm hug',
    ],
  ),
  _PromptPack.named(
    id: 336,
    questions: <String>[
      'Which home routine should feel calmer for us?',
      'What daily transition could use a gentler rhythm?',
      'Which recurring part of the day deserves less rushing?',
      'What home routine would benefit from better teamwork?',
      'Which everyday moment should we make more peaceful?',
    ],
    options: <String>[
      'Getting ready',
      'Preparing dinner',
      'Cleaning up',
      'Getting ready for bed',
    ],
  ),
  _PromptPack.named(
    id: 337,
    questions: <String>[
      'Which kind of background sound helps you work?',
      'What audio would you choose for a focused task?',
      'Which soundtrack makes routine work more enjoyable?',
      'What would you play during a productive afternoon?',
      'Which sound environment fits your work style?',
    ],
    options: <String>[
      'Instrumental music',
      'Nature sounds',
      'A familiar playlist',
      'Complete silence',
    ],
  ),
  _PromptPack.named(
    id: 338,
    questions: <String>[
      'Which end-of-week question would help us reconnect?',
      'What should we ask each other before a new week starts?',
      'Which weekly reflection would strengthen our teamwork?',
      'What question could improve our shared routine?',
      'Which simple review belongs in a calm weekend chat?',
    ],
    options: <String>[
      'What worked well?',
      'What felt difficult?',
      'What do we need next?',
      'What should we celebrate?',
    ],
  ),
  _PromptPack.named(
    id: 339,
    questions: <String>[
      'Which little efficiency would give us more quality time?',
      'What routine improvement could create extra room for us?',
      'Which practical shortcut would make evenings less rushed?',
      'What small system could protect more together-time?',
      'Which change would help daily tasks finish more smoothly?',
    ],
    options: <String>[
      'Prepare meals ahead',
      'Share a chore list',
      'Set simple reminders',
      'Keep essentials organized',
    ],
  ),
  _PromptPack.named(
    id: 340,
    questions: <String>[
      'Which part of an ordinary weekday can feel most special together?',
      'What weekday moment should we protect from becoming automatic?',
      'Which simple routine can still feel like quality time?',
      'What daily pause helps a regular day feel meaningful?',
      'Which weekday connection point matters most to you?',
    ],
    options: <String>[
      'A morning greeting',
      'A midday message',
      'Dinner together',
      'A bedtime talk',
    ],
  ),
  _PromptPack.named(
    id: 341,
    questions: <String>[
      'Which gentle gesture helps you feel closest to me?',
      'What small sign of affection reaches you most easily?',
      'Which caring action creates the warmest connection?',
      'What simple gesture makes together-time feel extra loving?',
      'Which quiet expression of care means the most to you?',
    ],
    options: <String>[
      'A long hug',
      'A thoughtful message',
      'Undivided attention',
      'Help with something',
    ],
  ),
  _PromptPack.named(
    id: 342,
    questions: <String>[
      'Which kind of quality time makes you feel most connected?',
      'What shared time would fill your connection cup today?',
      'Which together-moment helps you feel fully present with me?',
      'What kind of date creates the deepest sense of closeness?',
      'Which way of spending time together feels most meaningful?',
    ],
    options: <String>[
      'A long conversation',
      'A shared activity',
      'A quiet cuddle',
      'A little adventure',
    ],
  ),
  _PromptPack.named(
    id: 343,
    questions: <String>[
      'Which kind of loving words brighten you most?',
      'What verbal reminder would feel sweetest today?',
      'Which message of care stays with you longest?',
      'What words make you feel especially valued?',
      'Which kind of affirmation would you most like to hear?',
    ],
    options: <String>[
      'I appreciate you',
      'I believe in you',
      'I love being with you',
      'I am proud of you',
    ],
  ),
  _PromptPack.named(
    id: 344,
    questions: <String>[
      'Which helpful action feels most loving on a busy day?',
      'What practical gesture would make you feel cared for?',
      'Which act of support would lighten your day most?',
      'What kind of help communicates love best to you?',
      'Which thoughtful task would you appreciate today?',
    ],
    options: <String>[
      'Prepare something',
      'Handle one task',
      'Offer a ride',
      'Organize a plan',
    ],
  ),
  _PromptPack.named(
    id: 345,
    questions: <String>[
      'Which tiny gift would feel most meaningful?',
      'What small surprise would show that I know you well?',
      'Which thoughtful token would you treasure most?',
      'What little present would brighten an ordinary day?',
      'Which gift style feels warmest without needing an occasion?',
    ],
    options: <String>[
      'A favorite snack',
      'A handwritten note',
      'A printed photo',
      'A useful little item',
    ],
  ),
  _PromptPack.named(
    id: 346,
    questions: <String>[
      'Which kind of physical affection feels coziest?',
      'What affectionate moment helps you relax near me?',
      'Which gentle closeness feels most comforting?',
      'What simple affectionate gesture fits a quiet day?',
      'Which kind of closeness makes you feel most at home?',
    ],
    options: <String>[
      'Holding hands',
      'A warm hug',
      'Leaning together',
      'A forehead kiss',
    ],
  ),
  _PromptPack.named(
    id: 347,
    questions: <String>[
      'Which check-in helps you feel most understood?',
      'What kind of question opens the best conversation for you?',
      'Which gentle prompt makes sharing feel easiest?',
      'What check-in would help us connect today?',
      'Which question shows the most thoughtful attention?',
    ],
    options: <String>[
      'How are you really?',
      'What is on your mind?',
      'What felt good today?',
      'What do you need?',
    ],
  ),
  _PromptPack.named(
    id: 348,
    questions: <String>[
      'How do you most enjoy having your wins celebrated?',
      'Which reaction makes a happy achievement feel even better?',
      'What celebration style helps you feel fully supported?',
      'Which response would make your good news shine?',
      'How should we cheer each other on after a success?',
    ],
    options: <String>[
      'An excited message',
      'A favorite treat',
      'A proud hug',
      'A little date',
    ],
  ),
  _PromptPack.named(
    id: 349,
    questions: <String>[
      'Which sign makes you feel especially known by me?',
      'What shows you that I pay attention to who you are?',
      'Which thoughtful detail creates a sense of being understood?',
      'What kind of remembering makes you feel seen?',
      'Which familiar gesture says I know you well?',
    ],
    options: <String>[
      'Remembering preferences',
      'Noticing my mood',
      'Knowing my stories',
      'Anticipating a need',
    ],
  ),
  _PromptPack.named(
    id: 350,
    questions: <String>[
      'Which approach helps us handle a small disagreement gently?',
      'What response keeps a difficult conversation caring?',
      'Which habit helps us find our way back to teamwork?',
      'What would make a tense moment feel more manageable?',
      'Which communication choice best protects our connection?',
    ],
    options: <String>[
      'Pause and breathe',
      'Listen without rushing',
      'Name the shared goal',
      'Return with kind words',
    ],
  ),
  _PromptPack.named(
    id: 351,
    questions: <String>[
      'Which behavior builds the strongest sense of trust for you?',
      'What dependable action helps a relationship feel secure?',
      'Which steady habit makes teamwork easier to trust?',
      'What quality helps you feel safe being fully yourself?',
      'Which form of consistency matters most in a partnership?',
    ],
    options: <String>[
      'Keeping promises',
      'Speaking honestly',
      'Showing up',
      'Respecting boundaries',
    ],
  ),
  _PromptPack.named(
    id: 352,
    questions: <String>[
      'Which part of our teamwork feels strongest?',
      'What kind of shared challenge brings out our best partnership?',
      'Which team skill are you happiest we have?',
      'What makes us effective when we work side by side?',
      'Which shared strength helps us accomplish things together?',
    ],
    options: <String>[
      'We divide tasks well',
      'We share ideas',
      'We encourage effort',
      'We stay flexible',
    ],
  ),
  _PromptPack.named(
    id: 353,
    questions: <String>[
      'Which playful connection habit should we do more often?',
      'What silly little ritual makes our bond feel lively?',
      'Which fun behavior keeps everyday love from feeling routine?',
      'What playful moment would you welcome today?',
      'Which kind of shared silliness feels most like us?',
    ],
    options: <String>[
      'Make up nicknames',
      'Send funny photos',
      'Invent tiny games',
      'Dance for one song',
    ],
  ),
  _PromptPack.named(
    id: 354,
    questions: <String>[
      'Which reassurance feels most comforting during uncertainty?',
      'What reminder helps you feel supported when plans are unclear?',
      'Which steady message would calm a worried moment?',
      'What kind of reassurance would you want from me?',
      'Which words best communicate that we are a team?',
    ],
    options: <String>[
      'I am here',
      'We will take it slowly',
      'Your feelings matter',
      'We will face it together',
    ],
  ),
  _PromptPack.named(
    id: 355,
    questions: <String>[
      'Which part of my everyday care would you most like acknowledged?',
      'What kind of appreciation would feel meaningful today?',
      'Which effort in a relationship deserves more recognition?',
      'What caring contribution should partners thank each other for?',
      'Which quiet effort would you most appreciate being noticed?',
    ],
    options: <String>[
      'Emotional support',
      'Practical help',
      'Making time',
      'Keeping things fun',
    ],
  ),
  _PromptPack.named(
    id: 356,
    questions: <String>[
      'Which connection ritual would you like us to protect?',
      'What recurring moment helps a relationship stay close?',
      'Which small ritual belongs in even our busiest weeks?',
      'What habit would keep us emotionally in step?',
      'Which regular connection point feels most valuable?',
    ],
    options: <String>[
      'Morning greetings',
      'Daily check-ins',
      'Weekly dates',
      'Goodnight talks',
    ],
  ),
  _PromptPack.named(
    id: 357,
    questions: <String>[
      'Which date style makes it easiest for us to reconnect?',
      'What kind of outing gives us the best quality conversation?',
      'Which date atmosphere helps you feel closest?',
      'What shared plan would bring our attention back to each other?',
      'Which date would best refresh our bond?',
    ],
    options: <String>[
      'A quiet meal',
      'A long walk',
      'A creative activity',
      'A cozy night in',
    ],
  ),
  _PromptPack.named(
    id: 358,
    questions: <String>[
      'Which feeling should our shared home give us most?',
      'What emotional quality belongs at the heart of our space?',
      'Which atmosphere would make home feel most loving?',
      'What should we always be able to find when we come home?',
      'Which feeling would define our ideal everyday home?',
    ],
    options: <String>[
      'Warm welcome',
      'Peaceful safety',
      'Playful energy',
      'Room to be ourselves',
    ],
  ),
  _PromptPack.named(
    id: 359,
    questions: <String>[
      'Which intention would you choose for our relationship today?',
      'What small focus could make today better for both of us?',
      'Which shared intention feels most valuable right now?',
      'What should guide the way we care for each other today?',
      'Which gentle goal would you set for us this morning?',
    ],
    options: <String>[
      'Listen with care',
      'Make time to laugh',
      'Help without counting',
      'Notice the good',
    ],
  ),
];
