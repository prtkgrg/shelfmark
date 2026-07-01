import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart';

import 'models/chapter.dart';

/// Renders the first page of a series' earliest chapter to a cached PNG and
/// returns the file. Returns null if the series has no chapters or rendering
/// fails (e.g. corrupt PDF) and no prior cache exists.
///
/// [chapters] should already be freshly scanned by the caller (avoids
/// re-listing a potentially large folder just for the cover).
Future<File?> getOrGenerateCoverThumbnail(String seriesId, List<Chapter> chapters) async {
  if (chapters.isEmpty) return null;

  final supportDir = await getApplicationSupportDirectory();
  final cacheDir = Directory('${supportDir.path}/covers');
  if (!cacheDir.existsSync()) cacheDir.createSync(recursive: true);
  final cacheFile = File('${cacheDir.path}/$seriesId.png');
  final markerFile = File('${cacheDir.path}/$seriesId.source');

  // Identifies which chapter the cached cover was rendered from, so a
  // rescan that changes the earliest chapter (e.g. an earlier chapter
  // gets added later) regenerates the cover instead of keeping it stale.
  final sourceKey = '${chapters.first.number}:${chapters.first.filename}';
  if (cacheFile.existsSync() &&
      markerFile.existsSync() &&
      markerFile.readAsStringSync() == sourceKey) {
    return cacheFile;
  }

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
    if (rendered == null) return cacheFile.existsSync() ? cacheFile : null;
    await cacheFile.writeAsBytes(rendered.bytes);
    await markerFile.writeAsString(sourceKey);
    return cacheFile;
  } catch (_) {
    // Rendering failed (e.g. corrupt PDF) - fall back to a stale cached
    // cover rather than showing nothing, if one exists.
    return cacheFile.existsSync() ? cacheFile : null;
  }
}

Future<void> invalidateCoverThumbnail(String seriesId) async {
  final supportDir = await getApplicationSupportDirectory();
  final coverFile = File('${supportDir.path}/covers/$seriesId.png');
  final markerFile = File('${supportDir.path}/covers/$seriesId.source');
  if (coverFile.existsSync()) await coverFile.delete();
  if (markerFile.existsSync()) await markerFile.delete();
}
