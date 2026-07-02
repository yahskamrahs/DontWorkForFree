package com.example.my_app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetPlugin

class ShiftWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (widgetId in appWidgetIds) {
            val prefs = HomeWidgetPlugin.getData(context)
            val remaining = prefs.getString("widget_remaining", "--:--:--") ?: "--:--:--"
            val exitTime  = prefs.getString("widget_exit_time", "Safe exit: --") ?: "Safe exit: --"
            val status    = prefs.getString("widget_status", "NO SHIFT") ?: "NO SHIFT"

            val views = RemoteViews(context.packageName, R.layout.shift_widget_layout)
            views.setTextViewText(R.id.widget_time_remaining, remaining)
            views.setTextViewText(R.id.widget_exit_time, exitTime)
            views.setTextViewText(R.id.widget_status, status)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
