import 'dart:io';

import 'models/chapter.dart';

// Matches "chapter" followed by junk then digits, case-insensitive.
// Handles: "Chapter 1000", "chapter 691", "Chapter 1065..", "Chapter 1186 [TCB SCANS]"
final RegExp _chapterRe = RegExp(r'chapter\D{0,10}(\d+)', caseSensitive: false);

List<Chapter> scanChapters(String folderPath) {
  final dir = Directory(folderPath);
  if (!dir.existsSync()) return [];

  final chapters = <Chapter>[];
  for (final entity in dir.listSync()) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (!name.toLowerCase().endsWith('.pdf')) continue;
    final match = _chapterRe.firstMatch(name);
    if (match == null) continue;
    chapters.add(Chapter(
      number: int.parse(match.group(1)!),
      path: entity.path,
      filename: name,
    ));
  }
  chapters.sort((a, b) => a.number.compareTo(b.number));
  return chapters;
}
