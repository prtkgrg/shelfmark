int computeStreakDays(Iterable<DateTime> timestamps) {
  final days = timestamps.map((t) => DateTime(t.year, t.month, t.day)).toSet();
  if (days.isEmpty) return 0;

  final today = DateTime.now();
  var cursor = DateTime(today.year, today.month, today.day);
  if (!days.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
    if (!days.contains(cursor)) return 0;
  }

  var streak = 0;
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

int countInLastDays(Iterable<DateTime> timestamps, int days) {
  final cutoff = DateTime.now().subtract(Duration(days: days));
  return timestamps.where((t) => t.isAfter(cutoff)).length;
}
