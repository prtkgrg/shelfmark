import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';

/// Pushes "continue reading" state to the Android home screen widget.
///
/// Callers treat this as fire-and-forget (it runs on every chapter
/// open/navigate/read-toggle), so failures are swallowed here rather than
/// left as unhandled Future rejections at every call site.
class WidgetService {
  static const _androidWidgetName = 'ContinueReadingWidgetProvider';

  static Future<void> update({
    required String seriesName,
    required int chapterNumber,
    required int totalChapters,
    required int readCount,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('series_name', seriesName);
      await HomeWidget.saveWidgetData<int>('chapter_number', chapterNumber);
      await HomeWidget.saveWidgetData<int>('total_chapters', totalChapters);
      await HomeWidget.saveWidgetData<int>('read_count', readCount);
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('WidgetService.update failed: $e');
    }
  }
}
