package dev.selector.jk_bms

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * The last known state of one battery, on the home screen.
 *
 * It shows what was last read, not what is true now: the app holds a Bluetooth
 * connection only while it is open and in range, so anything here is a memory.
 * The age line exists for exactly that reason. A charge percentage with no
 * timestamp reads as current, and acting on a two-day-old number is worse than
 * having no widget at all.
 */
class PackWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences
    ) {
        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pack_widget).apply {
                setTextViewText(
                    R.id.widget_pack,
                    widgetData.getString("pack_name", "") ?: ""
                )
                setTextViewText(
                    R.id.widget_soc,
                    widgetData.getString("soc", "--") ?: "--"
                )
                setTextViewText(
                    R.id.widget_range,
                    widgetData.getString("range", "") ?: ""
                )
                setTextViewText(
                    R.id.widget_age,
                    widgetData.getString("age", "") ?: ""
                )

                // Tapping it opens the app. Nothing else: a widget that can
                // start a connection would be a widget that drains a battery
                // from the home screen.
                setOnClickPendingIntent(
                    R.id.widget_soc,
                    HomeWidgetLaunchIntent.getActivity(
                        context,
                        MainActivity::class.java
                    )
                )
            }
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
