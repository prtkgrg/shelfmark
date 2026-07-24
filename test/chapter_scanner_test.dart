import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shelfmark/chapter_scanner.dart';

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('shelfmark_scan_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  void write(String name) => File('${tmp.path}/$name').writeAsStringSync('x');

  test('picks up chapter PDFs, sorted ascending by number', () {
    write('Chapter 1000.pdf');
    write('chapter_691.pdf');
    write('Chapter 5.pdf');
    final chapters = scanChapters(tmp.path);
    expect(chapters.map((c) => c.number), [5, 691, 1000]);
  });

  test('tolerates real-world naming junk', () {
    write('Chapter 1186 [TCB SCANS].pdf');
    write('chapter_1186_[SCANS].pdf'); // same number, different file
    final nums = scanChapters(tmp.path).map((c) => c.number).toList();
    expect(nums, everyElement(1186));
    expect(nums.length, 2);
  });

  test('ignores non-pdf and non-chapter files', () {
    write('Chapter 3.pdf');
    write('cover.jpg');
    write('notes.txt');
    write('readme.pdf'); // pdf but no "chapter N"
    final chapters = scanChapters(tmp.path);
    expect(chapters.length, 1);
    expect(chapters.single.number, 3);
    expect(chapters.single.filename, 'Chapter 3.pdf');
  });

  test('captures the leading integer of a decimal-named chapter', () {
    // Regex is \d+, so "Chapter 10.5" reads as 10 (documents current behavior).
    write('Chapter 10.5.pdf');
    expect(scanChapters(tmp.path).single.number, 10);
  });

  test('missing folder returns empty, does not throw', () {
    expect(scanChapters('${tmp.path}/does-not-exist'), isEmpty);
  });
}
