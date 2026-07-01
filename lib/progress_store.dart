import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ProgressStore {
  final String seriesId;
  ProgressStore(this.seriesId);

  Map<int, String> _readAt = {}; // chapter number -> ISO timestamp
  Map<int, int> _lastPage = {}; // chapter number -> last viewed page index
  int? lastChapter;

  String get _readKey => 'read_$seriesId';
  String get _lastChapterKey => 'lastchapter_$seriesId';
  String get _lastPageKey => 'lastpage_$seriesId';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    lastChapter = prefs.getInt(_lastChapterKey);

    final rawRead = prefs.getString(_readKey);
    if (rawRead != null) {
      final decoded = jsonDecode(rawRead) as Map<String, dynamic>;
      _readAt = decoded.map((k, v) => MapEntry(int.parse(k), v as String));
    }

    final rawPage = prefs.getString(_lastPageKey);
    if (rawPage != null) {
      final decoded = jsonDecode(rawPage) as Map<String, dynamic>;
      _lastPage = decoded.map((k, v) => MapEntry(int.parse(k), v as int));
    }
  }

  bool isRead(int number) => _readAt.containsKey(number);

  DateTime? readAt(int number) {
    final s = _readAt[number];
    return s == null ? null : DateTime.tryParse(s);
  }

  int get readCount => _readAt.length;

  Iterable<DateTime> get allReadTimestamps =>
      _readAt.values.map((s) => DateTime.parse(s));

  Future<void> setRead(int number, bool value) async {
    if (value) {
      _readAt[number] = DateTime.now().toIso8601String();
    } else {
      _readAt.remove(number);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _readKey,
      jsonEncode(_readAt.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  Future<void> setLastChapter(int number) async {
    lastChapter = number;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastChapterKey, number);
  }

  int lastPage(int chapterNumber) => _lastPage[chapterNumber] ?? 0;

  Future<void> setLastPage(int chapterNumber, int page) async {
    _lastPage[chapterNumber] = page;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _lastPageKey,
      jsonEncode(_lastPage.map((k, v) => MapEntry(k.toString(), v))),
    );
  }

  // Raw accessors used by JSON export/import.
  Map<String, String> get readAtRaw =>
      _readAt.map((k, v) => MapEntry(k.toString(), v));
  Map<String, int> get lastPageRaw =>
      _lastPage.map((k, v) => MapEntry(k.toString(), v));

  Future<void> restoreRaw({
    required Map<String, String> readAt,
    required Map<String, int> lastPage,
    int? lastChapter,
  }) async {
    _readAt = readAt.map((k, v) => MapEntry(int.parse(k), v));
    _lastPage = lastPage.map((k, v) => MapEntry(int.parse(k), v));
    this.lastChapter = lastChapter;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_readKey, jsonEncode(readAt));
    await prefs.setString(_lastPageKey, jsonEncode(lastPage));
    if (lastChapter != null) await prefs.setInt(_lastChapterKey, lastChapter);
  }
}
