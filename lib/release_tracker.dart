import 'library_store.dart';
import 'notifications.dart';
import 'release_source.dart';

import 'models/series.dart';

/// Result of refreshing one series' release info.
class TrackResult {
  final String seriesId;
  final num? latest; // null if fetch failed / untracked
  final int newCount; // chapters released beyond the highest local PDF
  final bool fetched; // false if the source was unreachable / untracked
  TrackResult(this.seriesId, this.latest, this.newCount, {this.fetched = true});
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
      final result = await refreshSeries(library, s, highestLocalById[s.id] ?? 0);
      if (result != null) results.add(result);
    }
    return results;
  }

  /// Refreshes a single [series]. Returns null if it isn't tracked, otherwise
  /// a [TrackResult] (with `fetched: false` when the source was unreachable,
  /// in which case the cached number is left untouched). Fires a notification
  /// on a grown number, same as [refreshAll]. Never throws.
  static Future<TrackResult?> refreshSeries(
    LibraryStore library,
    Series s,
    int highestLocal,
  ) async {
    final source = ReleaseSource.forSeries(s);
    if (source == null) return null;

    final prev = s.latestChapter;
    final latest = await source.fetchLatest();
    if (latest == null) {
      return TrackResult(s.id, prev, _newCount(prev, highestLocal), fetched: false);
    }

    await library.updateLatest(s.id, latest);
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

    return TrackResult(s.id, latest, newCount);
  }

  static int _newCount(num? latest, int highestLocal) {
    if (latest == null) return 0;
    final diff = latest.floor() - highestLocal;
    return diff > 0 ? diff : 0;
  }
}
