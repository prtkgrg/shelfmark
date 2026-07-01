package com.prateek.shelfmark

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

class ContinueReadingWidgetProvider : HomeWidgetProvider() {

  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    appWidgetIds.forEach { widgetId ->
      val views = RemoteViews(context.packageName, R.layout.continue_reading_widget).apply {
        val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
        setOnClickPendingIntent(R.id.widget_root, pendingIntent)

        val seriesName = widgetData.getString("series_name", null)
        if (seriesName != null) {
          val chapterNumber = widgetData.getInt("chapter_number", 0)
          val totalChapters = widgetData.getInt("total_chapters", 0)
          val readCount = widgetData.getInt("read_count", 0)

          setTextViewText(R.id.widget_series_name, seriesName)
          setTextViewText(
              R.id.widget_chapter_label,
              "Chapter $chapterNumber of $totalChapters",
          )
          val progress = if (totalChapters > 0) (readCount * 100 / totalChapters) else 0
          setProgressBar(R.id.widget_progress, 100, progress, false)
        } else {
          setTextViewText(R.id.widget_series_name, "Shelfmark")
          setTextViewText(R.id.widget_chapter_label, "Open a series to start reading")
          setProgressBar(R.id.widget_progress, 100, 0, false)
        }
      }

      appWidgetManager.updateAppWidget(widgetId, views)
    }
  }
}
