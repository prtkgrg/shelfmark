import 'library_store.dart';
import 'notifications.dart';
import 'release_source.dart';

/// Result of refreshing one series' release info.
class TrackResult {
  final String seriesId;
  final num? latest; // null if fetch failed / untracked
  final int newCount; // chapters released beyond the highest local PDF
  TrackResult(this.seriesId, this.latest, this.newCount);
}

class ReleaseTracker {
  /// Fetches the latest chapter for every tracked series, persists the number
  /// via [library], and fires a notification when a series gains chapters
  /// beyond what's on disk. [highestLocalById] maps series id → highest
  /// chapter number currently in its folder (0 if none).
  ///
  /// Never throws; individual source failures are isolated per series.
  static Future<List<TrackResult>> refreshAll(
    LibraryStore library,
    Map<String, int> highestLocalById,
  ) async {
    final results = <TrackResult>[];
    for (final s in library.series) {
      final source = ReleaseSource.forSeries(s);
      if (source == null) continue;

      final prev = s.latestChapter;
      final latest = await source.fetchLatest();
      if (latest == null) {
        results.add(TrackResult(s.id, prev, _newCount(prev, highestLocalById[s.id] ?? 0)));
        continue;
      }

      await library.updateLatest(s.id, latest);

      final highestLocal = highestLocalById[s.id] ?? 0;
      final newCount = _newCount(latest, highestLocal);

      // Only notify when the number actually grew since last check, so
      // opening the library repeatedly doesn't re-alert for the same release.
      final grew = prev == null || latest > prev;
      if (grew && newCount > 0) {
        await Notifications.showNewChapters(
          notificationId: s.id.hashCode & 0x7fffffff,
          seriesName: s.name,
          from: highestLocal,
          to: latest,
          newCount: newCount,
        );
      }

      results.add(TrackResult(s.id, latest, newCount));
    }
    return results;
  }

  static int _newCount(num? latest, int highestLocal) {
    if (latest == null) return 0;
    final diff = latest.floor() - highestLocal;
    return diff > 0 ? diff : 0;
  }
}
