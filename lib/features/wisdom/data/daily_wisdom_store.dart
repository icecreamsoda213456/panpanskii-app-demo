class DailyWisdomQuote {
  const DailyWisdomQuote({
    required this.quote,
    required this.author,
    required this.reflection,
  });

  final String quote;
  final String author;
  final String reflection;
}

class DailyWisdomStore {
  DailyWisdomQuote quoteForDate(DateTime date) {
    final dayNumber = DateTime(date.year, date.month, date.day)
        .difference(DateTime(2020, 1, 1))
        .inDays;
    return _dailyWisdomQuotes[dayNumber.abs() % _dailyWisdomQuotes.length];
  }
}

const _dailyWisdomQuotes = <DailyWisdomQuote>[
  DailyWisdomQuote(
    quote: 'Small steps still move you forward.',
    author: 'Panpanskii reminder',
    reflection:
        'You do not have to finish everything today. Choose one gentle next step.',
  ),
  DailyWisdomQuote(
    quote: 'Be patient with the version of you that is still learning.',
    author: 'Daily wisdom',
    reflection:
        'Growth can look quiet. Give yourself room to learn without rushing the process.',
  ),
  DailyWisdomQuote(
    quote: 'Kindness is never wasted.',
    author: 'Daily wisdom',
    reflection:
        'A thoughtful word can stay with someone longer than you realize. Lead with warmth today.',
  ),
  DailyWisdomQuote(
    quote: 'You can begin again, even from a difficult day.',
    author: 'Daily wisdom',
    reflection:
        'Yesterday does not get to decide the shape of today. Start where you are.',
  ),
  DailyWisdomQuote(
    quote: 'Rest is part of the work, not a reward for finishing it.',
    author: 'Daily wisdom',
    reflection:
        'Protect a little quiet time today. A rested heart notices more good things.',
  ),
  DailyWisdomQuote(
    quote: 'What you water with attention will grow.',
    author: 'Daily wisdom',
    reflection:
        'Give your time to the people, habits, and hopes you want to keep close.',
  ),
  DailyWisdomQuote(
    quote: 'Courage can be soft and still be real.',
    author: 'Daily wisdom',
    reflection:
        'You do not need to feel fearless. Showing up gently is already brave.',
  ),
  DailyWisdomQuote(
    quote: 'There is beauty in an ordinary day shared with someone you love.',
    author: 'Daily wisdom',
    reflection: 'Notice one simple moment today and let it be enough.',
  ),
  DailyWisdomQuote(
    quote: 'Your feelings are visitors; listen to them, but let them pass.',
    author: 'Daily wisdom',
    reflection:
        'Name what you feel without letting one difficult moment define you.',
  ),
  DailyWisdomQuote(
    quote: 'Hope is a practice, not just a feeling.',
    author: 'Daily wisdom',
    reflection: 'Choose one hopeful action, even if it is very small.',
  ),
  DailyWisdomQuote(
    quote: 'A grateful heart makes room for more light.',
    author: 'Daily wisdom',
    reflection:
        'Name one thing you appreciate today and share it with your person.',
  ),
  DailyWisdomQuote(
    quote: 'You are allowed to take up space and take your time.',
    author: 'Daily wisdom',
    reflection:
        'Your needs matter too. Make one choice today that respects your own pace.',
  ),
  DailyWisdomQuote(
    quote: 'Love grows where attention lives.',
    author: 'Communal wisdom',
    reflection:
        'Offer one moment of full attention today. Presence often says more than a perfect response.',
  ),
  DailyWisdomQuote(
    quote: 'Being known begins with being honest.',
    author: 'Communal wisdom',
    reflection:
        'Share one true little thing about your day and make room for your person to do the same.',
  ),
  DailyWisdomQuote(
    quote: 'A gentle answer can change the whole conversation.',
    author: 'Communal wisdom',
    reflection:
        'Slow down before replying. A softer tone can help both hearts stay open.',
  ),
  DailyWisdomQuote(
    quote: 'Together does not have to mean identical.',
    author: 'Communal wisdom',
    reflection:
        'Let your differences add color to the relationship instead of treating them as distance.',
  ),
  DailyWisdomQuote(
    quote: 'Reliable love often looks wonderfully ordinary.',
    author: 'Communal wisdom',
    reflection:
        'Notice the repeated acts of care that quietly make everyday life feel safer.',
  ),
  DailyWisdomQuote(
    quote: 'Listen for the feeling beneath the words.',
    author: 'Communal wisdom',
    reflection:
        'Before solving anything, try naming what your person may be feeling and ask if you understood.',
  ),
  DailyWisdomQuote(
    quote: 'A shared laugh can loosen a difficult day.',
    author: 'Communal wisdom',
    reflection:
        'Find one harmless reason to be playful together, even if the day has been heavy.',
  ),
  DailyWisdomQuote(
    quote: 'Care is often clearest in the smallest details.',
    author: 'Communal wisdom',
    reflection:
        'Remember one preference, task, or comfort that matters to your person and act on it.',
  ),
  DailyWisdomQuote(
    quote: 'Closeness needs both warmth and room to breathe.',
    author: 'Communal wisdom',
    reflection:
        'Offer affection without crowding each other. Healthy space can make returning feel sweeter.',
  ),
  DailyWisdomQuote(
    quote: 'Repair is one of love\'s quiet skills.',
    author: 'Communal wisdom',
    reflection:
        'A sincere apology and one changed action can turn a rough moment into deeper trust.',
  ),
  DailyWisdomQuote(
    quote: 'Choose curiosity before assumption.',
    author: 'Communal wisdom',
    reflection:
        'Ask what your person meant instead of filling the silence with the hardest interpretation.',
  ),
  DailyWisdomQuote(
    quote: 'Speak to yourself like someone worth caring for.',
    author: 'Communal wisdom',
    reflection:
        'Replace one harsh inner sentence with words you would lovingly offer your closest person.',
  ),
  DailyWisdomQuote(
    quote: 'You do not need to earn softness.',
    author: 'Communal wisdom',
    reflection:
        'Let yourself receive rest, patience, and care before every task is complete.',
  ),
  DailyWisdomQuote(
    quote: 'Imperfect progress still belongs to you.',
    author: 'Communal wisdom',
    reflection:
        'Notice what moved forward, even if the result is smaller or messier than you imagined.',
  ),
  DailyWisdomQuote(
    quote: 'Your pace is not proof of your worth.',
    author: 'Communal wisdom',
    reflection:
        'Move at the speed that keeps you well enough to remain present for your own life.',
  ),
  DailyWisdomQuote(
    quote: 'A resting heart is still a worthy heart.',
    author: 'Communal wisdom',
    reflection:
        'Give yourself a pause without turning it into another task to perform perfectly.',
  ),
  DailyWisdomQuote(
    quote: 'Mistakes are evidence that you participated.',
    author: 'Communal wisdom',
    reflection:
        'Keep the lesson and release the need to replay every imperfect detail.',
  ),
  DailyWisdomQuote(
    quote: 'Begin with compassion, then decide what needs to change.',
    author: 'Communal wisdom',
    reflection:
        'Understanding yourself clearly is more useful than punishing yourself quickly.',
  ),
  DailyWisdomQuote(
    quote: 'You can be proud and still be growing.',
    author: 'Communal wisdom',
    reflection:
        'Celebrate the person you are while making gentle room for the person you are becoming.',
  ),
  DailyWisdomQuote(
    quote: 'Boundaries are kindness with clear edges.',
    author: 'Communal wisdom',
    reflection:
        'A respectful no can protect the energy needed for your most meaningful yes.',
  ),
  DailyWisdomQuote(
    quote: 'Not every thought deserves your trust.',
    author: 'Communal wisdom',
    reflection:
        'Pause before believing the loudest worry. Look for facts, context, and a kinder possibility.',
  ),
  DailyWisdomQuote(
    quote: 'Give yourself the patience you offer people you love.',
    author: 'Communal wisdom',
    reflection:
        'Let learning take time and speak gently to the unfinished parts of your journey.',
  ),
  DailyWisdomQuote(
    quote: 'Growth rarely announces itself while it is happening.',
    author: 'Communal wisdom',
    reflection:
        'Look back with kindness. You may already handle something better than an earlier version of you could.',
  ),
  DailyWisdomQuote(
    quote: 'Small habits quietly write long stories.',
    author: 'Communal wisdom',
    reflection:
        'Choose one repeatable action that points toward the life you want instead of chasing one perfect day.',
  ),
  DailyWisdomQuote(
    quote: 'Becoming takes repetition.',
    author: 'Communal wisdom',
    reflection:
        'Practice the quality you value in one ordinary moment. Character grows through small returns.',
  ),
  DailyWisdomQuote(
    quote: 'You can change direction without calling the past a waste.',
    author: 'Communal wisdom',
    reflection:
        'Carry forward what you learned and allow a new choice to be an honest form of growth.',
  ),
  DailyWisdomQuote(
    quote: 'Learn slowly enough to keep the lesson.',
    author: 'Communal wisdom',
    reflection:
        'Understanding that lasts is more valuable than rushing to look finished.',
  ),
  DailyWisdomQuote(
    quote: 'Confidence often arrives after the first brave action.',
    author: 'Communal wisdom',
    reflection:
        'Take one manageable step before waiting to feel completely ready.',
  ),
  DailyWisdomQuote(
    quote: 'A good question can open a door that certainty missed.',
    author: 'Communal wisdom',
    reflection:
        'Stay curious about one situation today instead of deciding too quickly what it means.',
  ),
  DailyWisdomQuote(
    quote: 'Keep a little room for the beginner in you.',
    author: 'Communal wisdom',
    reflection:
        'Try something without demanding immediate excellence. Discovery needs permission to be awkward.',
  ),
  DailyWisdomQuote(
    quote: 'Outgrowing something is not a betrayal of who you were.',
    author: 'Communal wisdom',
    reflection:
        'Thank an old habit or dream for what it gave you, then notice whether it still fits.',
  ),
  DailyWisdomQuote(
    quote: 'Discipline feels kinder when it serves your values.',
    author: 'Communal wisdom',
    reflection:
        'Connect one task to the reason it matters instead of relying only on pressure.',
  ),
  DailyWisdomQuote(
    quote: 'Celebrate the evidence that you are becoming.',
    author: 'Communal wisdom',
    reflection:
        'Name one recent choice that reflects the person you hope to be.',
  ),
  DailyWisdomQuote(
    quote: 'Balance is an adjustment, not a fixed destination.',
    author: 'Communal wisdom',
    reflection:
        'Notice which part of life needs a little more care today and shift gently toward it.',
  ),
  DailyWisdomQuote(
    quote: 'Quiet can be deeply productive.',
    author: 'Communal wisdom',
    reflection:
        'Leave a few minutes unfilled and let your thoughts settle without forcing an outcome.',
  ),
  DailyWisdomQuote(
    quote: 'You cannot offer full presence from constant hurry.',
    author: 'Communal wisdom',
    reflection:
        'Slow one transition today so your attention can arrive where your body already is.',
  ),
  DailyWisdomQuote(
    quote: 'Fewer priorities can make a day richer.',
    author: 'Communal wisdom',
    reflection:
        'Choose what truly matters today and let lesser tasks wait without guilt.',
  ),
  DailyWisdomQuote(
    quote: 'The body notices what the calendar ignores.',
    author: 'Communal wisdom',
    reflection:
        'Check your thirst, hunger, tension, and tiredness before adding another demand.',
  ),
  DailyWisdomQuote(
    quote: 'A pause is where wisdom catches up.',
    author: 'Communal wisdom',
    reflection:
        'Take one breath between feeling and reacting. That small space can protect what matters.',
  ),
  DailyWisdomQuote(
    quote: 'Sleep is care you give tomorrow in advance.',
    author: 'Communal wisdom',
    reflection:
        'Prepare one small thing tonight that makes true rest easier to choose.',
  ),
  DailyWisdomQuote(
    quote: 'Leave a little margin around your life.',
    author: 'Communal wisdom',
    reflection:
        'An unscheduled pocket of time can hold rest, surprise, or the conversation you did not expect.',
  ),
  DailyWisdomQuote(
    quote: 'Not every invitation is an assignment.',
    author: 'Communal wisdom',
    reflection:
        'You may appreciate an opportunity without being required to accept it.',
  ),
  DailyWisdomQuote(
    quote: 'Gentle routines can hold you on difficult days.',
    author: 'Communal wisdom',
    reflection:
        'Keep one simple caring ritual that asks little and gives your day a steady shape.',
  ),
  DailyWisdomQuote(
    quote: 'Enough is a peaceful word.',
    author: 'Communal wisdom',
    reflection:
        'Decide what enough looks like for one task today, then allow yourself to stop.',
  ),
  DailyWisdomQuote(
    quote: 'Courage often looks like returning.',
    author: 'Communal wisdom',
    reflection:
        'Come back to one meaningful effort after a setback, even if you return with a smaller step.',
  ),
  DailyWisdomQuote(
    quote: 'Uncertainty leaves room for a kind possibility too.',
    author: 'Communal wisdom',
    reflection:
        'If you do not know what will happen, resist treating the hardest outcome as a fact.',
  ),
  DailyWisdomQuote(
    quote: 'Hope can begin as one tiny practical choice.',
    author: 'Communal wisdom',
    reflection: 'Do one thing that assumes tomorrow is worth preparing for.',
  ),
  DailyWisdomQuote(
    quote: 'The next step does not need to reveal the whole path.',
    author: 'Communal wisdom',
    reflection:
        'Choose the clearest small action and let later decisions wait for later information.',
  ),
  DailyWisdomQuote(
    quote: 'Sometimes bravery is being willing to ask.',
    author: 'Communal wisdom',
    reflection:
        'Request the help, clarity, or company you need instead of carrying every uncertainty alone.',
  ),
  DailyWisdomQuote(
    quote: 'A difficult chapter cannot summarize your whole story.',
    author: 'Communal wisdom',
    reflection:
        'Let today be one page rather than a permanent conclusion about your life.',
  ),
  DailyWisdomQuote(
    quote: 'Keep one light on for possibility.',
    author: 'Communal wisdom',
    reflection:
        'Name one outcome that could go gently, even while you prepare wisely for challenges.',
  ),
  DailyWisdomQuote(
    quote: 'Fear may speak, but it does not need the final word.',
    author: 'Communal wisdom',
    reflection:
        'Hear what fear wants to protect, then let your values help choose the response.',
  ),
  DailyWisdomQuote(
    quote: 'Naming a hard thing can make it more workable.',
    author: 'Communal wisdom',
    reflection:
        'Describe the next challenge clearly and without exaggeration, then identify what is within reach.',
  ),
  DailyWisdomQuote(
    quote: 'Begin before every condition becomes perfect.',
    author: 'Communal wisdom',
    reflection:
        'Use what is available and let the first attempt teach you what preparation could not.',
  ),
  DailyWisdomQuote(
    quote: 'Tomorrow is allowed to feel different from today.',
    author: 'Communal wisdom',
    reflection:
        'Leave room for new energy, new information, and a kinder turn than you can currently imagine.',
  ),
  DailyWisdomQuote(
    quote: 'Gratitude teaches attention where to rest.',
    author: 'Communal wisdom',
    reflection:
        'Choose one good detail and stay with it for a few breaths instead of rushing past.',
  ),
  DailyWisdomQuote(
    quote: 'Joy does not need a special occasion.',
    author: 'Communal wisdom',
    reflection:
        'Use the favorite cup, play the happy song, or enjoy the treat on an ordinary day.',
  ),
  DailyWisdomQuote(
    quote: 'Ordinary moments become precious through attention.',
    author: 'Communal wisdom',
    reflection:
        'Look closely at one familiar part of today as if you were saving it for future you.',
  ),
  DailyWisdomQuote(
    quote: 'Appreciation grows warmer when it is spoken.',
    author: 'Communal wisdom',
    reflection:
        'Tell someone exactly what they did and why it mattered to you.',
  ),
  DailyWisdomQuote(
    quote: 'Notice what is working as carefully as what needs fixing.',
    author: 'Communal wisdom',
    reflection:
        'Name one strength in yourself, your person, or your routine that deserves to continue.',
  ),
  DailyWisdomQuote(
    quote: 'Good news becomes sweeter when it is shared.',
    author: 'Communal wisdom',
    reflection:
        'Bring one small win to someone who will celebrate without making it smaller.',
  ),
  DailyWisdomQuote(
    quote: 'Delight is useful nourishment.',
    author: 'Communal wisdom',
    reflection:
        'Make room for something charming or funny simply because it helps you feel alive.',
  ),
  DailyWisdomQuote(
    quote: 'Favorite rituals turn time into belonging.',
    author: 'Communal wisdom',
    reflection:
        'Repeat one small tradition that reminds both of you this life is shared.',
  ),
  DailyWisdomQuote(
    quote: 'Beauty asks first for attention.',
    author: 'Communal wisdom',
    reflection:
        'Pause for a color, sound, face, or view that would be easy to miss while rushing.',
  ),
  DailyWisdomQuote(
    quote: 'A small completion deserves a real moment of pride.',
    author: 'Communal wisdom',
    reflection:
        'Mark one finished task before immediately replacing it with the next demand.',
  ),
  DailyWisdomQuote(
    quote: 'Laughter is one way a grateful heart breathes.',
    author: 'Communal wisdom',
    reflection:
        'Welcome a little silliness today without asking whether it is productive.',
  ),
  DailyWisdomQuote(
    quote: 'Clarity is a form of care.',
    author: 'Communal wisdom',
    reflection:
        'Say what you mean with warmth instead of asking someone to guess what would help.',
  ),
  DailyWisdomQuote(
    quote: 'Understanding does not require identical opinions.',
    author: 'Communal wisdom',
    reflection:
        'Try to describe the other view fairly before explaining where your own view differs.',
  ),
  DailyWisdomQuote(
    quote: 'One more honest question can prevent a long assumption.',
    author: 'Communal wisdom',
    reflection:
        'When something feels unclear, ask gently rather than building a complete story alone.',
  ),
  DailyWisdomQuote(
    quote: 'An honest conversation can still be tender.',
    author: 'Communal wisdom',
    reflection:
        'Tell the truth in a way that protects dignity, including your own.',
  ),
  DailyWisdomQuote(
    quote: 'An apology becomes trustworthy through changed behavior.',
    author: 'Communal wisdom',
    reflection:
        'Pair sincere words with one specific action that makes the same hurt less likely.',
  ),
  DailyWisdomQuote(
    quote: 'People feel closer when their experience is witnessed.',
    author: 'Communal wisdom',
    reflection:
        'Before offering advice, let someone know that you see why the moment mattered.',
  ),
  DailyWisdomQuote(
    quote: 'Community is built through repeated welcome.',
    author: 'Communal wisdom',
    reflection:
        'Include someone, remember a detail, or make one familiar space feel warmer today.',
  ),
  DailyWisdomQuote(
    quote: 'Generosity can be time, attention, or patience.',
    author: 'Communal wisdom',
    reflection:
        'Give in a way that is sustainable and genuinely useful, even if it costs nothing.',
  ),
  DailyWisdomQuote(
    quote: 'Specific encouragement travels farther.',
    author: 'Communal wisdom',
    reflection:
        'Name the effort or quality you admire instead of offering only a general compliment.',
  ),
  DailyWisdomQuote(
    quote: 'Letting someone finish is a small act of respect.',
    author: 'Communal wisdom',
    reflection: 'Stay with the full thought before preparing your reply.',
  ),
  DailyWisdomQuote(
    quote: 'Belonging grows where people are allowed to be real.',
    author: 'Communal wisdom',
    reflection:
        'Offer a response that makes honesty safer than pretending everything is fine.',
  ),
  DailyWisdomQuote(
    quote: 'Purpose often hides inside what you repeat.',
    author: 'Communal wisdom',
    reflection:
        'Notice which ordinary actions express the values you want your life to hold.',
  ),
  DailyWisdomQuote(
    quote: 'A meaningful life is assembled from ordinary choices.',
    author: 'Communal wisdom',
    reflection:
        'Choose one small action today that future you would recognize as important.',
  ),
  DailyWisdomQuote(
    quote: 'Care for the spaces that care for you.',
    author: 'Communal wisdom',
    reflection:
        'Tend one corner of your room, routine, or relationship that helps you feel grounded.',
  ),
  DailyWisdomQuote(
    quote: 'One thoughtful choice can anchor an entire day.',
    author: 'Communal wisdom',
    reflection:
        'Pick a simple intention and return to it whenever the day becomes noisy.',
  ),
  DailyWisdomQuote(
    quote: 'Keep promises small enough to keep.',
    author: 'Communal wisdom',
    reflection:
        'A modest commitment honored consistently builds more trust than a dramatic promise forgotten.',
  ),
  DailyWisdomQuote(
    quote: 'Spend attention where your values live.',
    author: 'Communal wisdom',
    reflection:
        'Give a few uninterrupted minutes to a person or purpose you say matters.',
  ),
  DailyWisdomQuote(
    quote: 'Home is a feeling built through habits.',
    author: 'Communal wisdom',
    reflection:
        'Create one repeated gesture that makes returning to each other feel safe and familiar.',
  ),
  DailyWisdomQuote(
    quote: 'Plans can guide you, but presence tells you why.',
    author: 'Communal wisdom',
    reflection:
        'Look up from the schedule long enough to notice the life the plan is meant to support.',
  ),
  DailyWisdomQuote(
    quote: 'Practice tomorrow\'s values in today\'s small choices.',
    author: 'Communal wisdom',
    reflection:
        'Act once like the future person you hope to become instead of waiting for a perfect new chapter.',
  ),
  DailyWisdomQuote(
    quote: 'Simplicity can reveal what is already enough.',
    author: 'Communal wisdom',
    reflection:
        'Remove one unnecessary layer and notice whether the essential thing becomes clearer.',
  ),
  DailyWisdomQuote(
    quote: 'End the day by noticing what carried you.',
    author: 'Communal wisdom',
    reflection:
        'Name a person, habit, hope, or small comfort that helped you make it through today.',
  ),
];
