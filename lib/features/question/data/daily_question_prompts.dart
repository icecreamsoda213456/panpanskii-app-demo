const int dailyQuestionPromptCount = 1825;

final List<String> dailyQuestionPrompts = _buildDailyQuestionPrompts();

List<String> _buildDailyQuestionPrompts() {
  assert(_reflectionTopics.length == 73);
  assert(_reflectionAngles.length == 25);

  final prompts = List<String>.generate(dailyQuestionPromptCount, (index) {
    final topic = _reflectionTopics[index % _reflectionTopics.length];
    final angle = _reflectionAngles[index % _reflectionAngles.length];
    return angle.replaceFirst('{topic}', topic);
  }, growable: false);

  assert(prompts.every((prompt) => prompt.endsWith('?')));
  assert(prompts.toSet().length == dailyQuestionPromptCount);
  return List<String>.unmodifiable(prompts);
}

const _reflectionTopics = <String>[
  'emotional closeness',
  'feeling safe together',
  'honest communication',
  'patient listening',
  'mutual trust',
  'shared laughter',
  'quiet companionship',
  'quality time',
  'thoughtful support',
  'feeling appreciated',
  'feeling understood',
  'personal space',
  'healthy boundaries',
  'forgiveness',
  'gratitude',
  'curiosity',
  'courage',
  'meaningful rest',
  'hope',
  'everyday kindness',
  'self-respect',
  'confidence',
  'creativity',
  'consistency',
  'resilience',
  'life balance',
  'a sense of purpose',
  'simple joy',
  'inner peace',
  'gentle adventure',
  'spontaneity',
  'stability',
  'teamwork',
  'shared responsibility',
  'growing together',
  'learning from mistakes',
  'celebrating progress',
  'meaningful traditions',
  'everyday romance',
  'friendship within love',
  'comfortable silence',
  'caring check-ins',
  'gentle communication during tension',
  'healthy repair',
  'asking for help',
  'giving reassurance',
  'receiving affection',
  'shared dreams',
  'individual dreams',
  'planning our future',
  'a welcoming home',
  'family connection',
  'lasting friendship',
  'community',
  'generosity',
  'nostalgia',
  'childhood wonder',
  'making memories',
  'trying new things',
  'travel dreams',
  'food traditions',
  'music in daily life',
  'a shared sense of humor',
  'time in nature',
  'physical wellbeing',
  'emotional wellbeing',
  'steady energy',
  'focused attention',
  'digital balance',
  'responsible planning',
  'shared rituals',
  'mindful choices',
  'gentle growth',
];

const _reflectionAngles = <String>[
  'What does the idea of {topic} mean to you right now?',
  'When have you felt the value of {topic} most strongly?',
  'In what way can {topic} shape how we care for each other?',
  'What small action could nurture {topic}?',
  'What would you like me to understand about {topic}?',
  'How has your view of {topic} changed over time?',
  'Which memory best captures {topic} for you?',
  'What helps create {topic} in everyday life?',
  'What tends to strengthen {topic}?',
  'How could {topic} improve an ordinary day?',
  'What is one gentle way we can honor {topic} this week?',
  'Who or what taught you something valuable about {topic}?',
  'Which everyday moment makes you appreciate {topic}?',
  'How could {topic} shape our ideal weekend?',
  'How can we make room for {topic} when life gets busy?',
  'What do you hope {topic} feels like a year from now?',
  'What do we already do that supports {topic}?',
  'What new habit could help {topic} grow?',
  'What would you tell your younger self about {topic}?',
  'How can we help each other cultivate {topic}?',
  'What has surprised you most about {topic}?',
  'Where could {topic} make the biggest positive difference in our life?',
  'What does a healthy version of {topic} look like to you?',
  'Which small sign helps you notice {topic}?',
  'What question about {topic} have you never been asked?',
];
