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

  Future<Series> addSeries({required String name, required String folderPath}) async {
    final s = Series(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      folderPath: folderPath,
    );
    series.add(s);
    await _persist();
    return s;
  }

  Future<void> renameSeries(String id, String newName) async {
    series.firstWhere((e) => e.id == id).name = newName;
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
