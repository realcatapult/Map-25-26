class InterestsCatalog {
  static const List<String> all = [
    'STEM',
    'Math',
    'Chemistry',
    'Physics',
    'Biology',
    'Coding',
    'AI',
    'Robotics',
    'Engineering',
    'English',
    'Reading',
    'Writing',
    'Debate',
    'Law',
    'History',
    'Culture',
    'Art',
    'Design',
    'Music',
    'Photography',
    'Film',
    'Business',
    'Entrepreneurship',
    'Finance',
    'Marketing',
    'Chess',
    'Gaming',
    'Cooking',
    'Health',
    'Sports',
    'Volunteering',
    'Environment',
    'Outdoors',
    'Public Speaking',
  ];

  static List<String> normalize(List<String> values) {
    final seen = <String>{};
    final cleaned = <String>[];

    for (final value in values) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final key = trimmed.toLowerCase();
      if (seen.contains(key)) {
        continue;
      }
      seen.add(key);
      cleaned.add(trimmed);
    }

    return cleaned;
  }
}
