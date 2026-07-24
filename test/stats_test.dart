import 'package:flutter_test/flutter_test.dart';
import 'package:shelfmark/stats.dart';

// Streak/window math is relative to "now", so tests build timestamps as
// offsets from the current day rather than hardcoding dates.
DateTime _daysAgo(int d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day, 12); // midday, tz-safe
  return today.subtract(Duration(days: d));
}

void main() {
  group('computeStreakDays', () {
    test('empty is zero', () {
      expect(computeStreakDays([]), 0);
    });

    test('read today only is a 1-day streak', () {
      expect(computeStreakDays([_daysAgo(0)]), 1);
    });

    test('counts consecutive days including today', () {
      expect(computeStreakDays([_daysAgo(0), _daysAgo(1), _daysAgo(2)]), 3);
    });

    test('multiple reads on the same day count once', () {
      expect(
        computeStreakDays([_daysAgo(0), _daysAgo(0), _daysAgo(1)]),
        2,
      );
    });

    test('a gap breaks the streak', () {
      // today + 3 days ago, missing 1 and 2 -> only today counts.
      expect(computeStreakDays([_daysAgo(0), _daysAgo(3)]), 1);
    });

    test('yesterday (not today) still counts as an active streak', () {
      expect(computeStreakDays([_daysAgo(1), _daysAgo(2)]), 2);
    });

    test('last read 2+ days ago is a broken streak', () {
      expect(computeStreakDays([_daysAgo(2), _daysAgo(3)]), 0);
    });
  });

  group('countInLastDays', () {
    test('counts only timestamps within the window', () {
      final ts = [_daysAgo(0), _daysAgo(3), _daysAgo(6), _daysAgo(10)];
      expect(countInLastDays(ts, 7), 3); // 0,3,6 within 7 days; 10 excluded
    });

    test('empty is zero', () {
      expect(countInLastDays([], 7), 0);
    });
  });
}
