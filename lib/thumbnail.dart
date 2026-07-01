import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'chapter_scanner.dart';

/// Renders the first page of a series' earliest chapter to a cached PNG and
/// returns the file. Returns null if the series has no chapters or rendering
/// fails (e.g. corrupt PDF).
Future<File?> getOrGenerateCoverThumbnail(String seriesId, String folderPath) async {
  final supportDir = await getApplicationSupportDirectory();
  final cacheDir = Directory('${supportDir.path}/covers');
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  final cacheFile = File('${cacheDir.path}/$seriesId.png');
  if (cacheFile.existsSync()) return cacheFile;

  final chapters = scanChapters(folderPath);
  if (chapters.isEmpty) return null;

  try {
    final document = await PdfDocument.openFile(chapters.first.path);
    final page = await document.getPage(1);
    final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    await document.close();
    if (rendered == null) return null;
    await cacheFile.writeAsBytes(rendered.bytes);
    return cacheFile;
  } catch (_) {
    return null;
  }
}

Future<void> invalidateCoverThumbnail(String seriesId) async {
  final supportDir = await getApplicationSupportDirectory();
  final cacheFile = File('${supportDir.path}/covers/$seriesId.png');
  if (cacheFile.existsSync()) await cacheFile.delete();
}
