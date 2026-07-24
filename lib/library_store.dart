import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'models/series.dart';

class LibraryStore {
  static const _seriesKey = 'series_list';

  List<Series> series = [];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_seriesKey);
    if (raw == null) {
      series = [];
      return;
    }
    final list = jsonDecode(raw) as List;
    series = list.map((e) => Series.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_seriesKey, jsonEncode(series.map((s) => s.toJson()).toList()));
  }

  /// Persists the current in-memory [series] list. Used after directly
  /// mutating [series] (e.g. restoring from a backup).
  Future<void> save() => _persist();

  Future<void> addOrReplaceSeries(Series s) async {
    series.removeWhere((e) => e.id == s.id);
    series.add(s);
    await _persist();
  }

  Future<Series> addSeries({
    required String name,
    required String folderPath,
    String? sourceType,
    String? sourceRef,
  }) async {
    final s = Series(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      folderPath: folderPath,
      sourceType: sourceType,
      sourceRef: sourceRef,
    );
    series.add(s);
    await _persist();
    return s;
  }

  Future<void> renameSeries(String id, String newName) async {
    final index = series.indexWhere((e) => e.id == id);
    if (index == -1) return;
    series[index].name = newName;
    await _persist();
  }

  /// Sets (or clears, when [sourceType]/[sourceRef] are null) the release
  /// tracking source for a series. Changing the source invalidates the cached
  /// [latestChapter] so a stale number from the old source isn't shown.
  Future<void> setSource(String id, {String? sourceType, String? sourceRef}) async {
    final index = series.indexWhere((e) => e.id == id);
    if (index == -1) return;
    final s = series[index];
    s.sourceType = sourceType;
    s.sourceRef = sourceRef;
    s.latestChapter = null;
    s.lastCheckedAt = null;
    await _persist();
  }

  /// Persists a freshly fetched latest-chapter number and check timestamp.
  Future<void> updateLatest(String id, num latestChapter) async {
    final index = series.indexWhere((e) => e.id == id);
    if (index == -1) return;
    series[index].latestChapter = latestChapter;
    series[index].lastCheckedAt = DateTime.now().toIso8601String();
    await _persist();
  }

  /// [newIndex] must already account for the item's removal at [oldIndex]
  /// (i.e. the final resting index), matching ReorderableListView's
  /// onReorderItem contract.
  Future<void> reorder(int oldIndex, int newIndex) async {
    final item = series.removeAt(oldIndex);
    series.insert(newIndex, item);
    await _persist();
  }

  Future<void> removeSeries(String id) async {
    series.removeWhere((e) => e.id == id);
    await _persist();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('read_$id');
    await prefs.remove('lastchapter_$id');
    await prefs.remove('lastpage_$id');
  }
}
