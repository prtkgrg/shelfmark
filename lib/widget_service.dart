import 'package:home_widget/home_widget.dart';

/// Pushes "continue reading" state to the Android home screen widget.
class WidgetService {
  static const _androidWidgetName = 'ContinueReadingWidgetProvider';

  static Future<void> update({
    required String seriesName,
    required int chapterNumber,
    required int totalChapters,
    required int readCount,
  }) async {
    await HomeWidget.saveWidgetData<String>('series_name', seriesName);
    await HomeWidget.saveWidgetData<int>('chapter_number', chapterNumber);
    await HomeWidget.saveWidgetData<int>('total_chapters', totalChapters);
    await HomeWidget.saveWidgetData<int>('read_count', readCount);
    await HomeWidget.updateWidget(androidName: _androidWidgetName);
  }
}
