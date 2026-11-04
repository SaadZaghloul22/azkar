package com.azk.azkarak

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews

/** Home-screen widget: zekr of the day, with a button for another zekr. Works without opening the app. */
class AzkarWidget : AppWidgetProvider() {
    companion object {
        const val ACTION_NEXT = "com.azk.azkarak.widget.NEXT"

        fun updateAll(context: Context) {
            val mgr = AppWidgetManager.getInstance(context)
            val ids = mgr.getAppWidgetIds(ComponentName(context, AzkarWidget::class.java))
            if (ids.isNotEmpty()) render(context, mgr, ids)
        }

        private fun render(context: Context, mgr: AppWidgetManager, ids: IntArray) {
            val prefs = context.getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE)
            val today = AzkarSource.daysSince2024()
            var title = prefs.getString(Prefs.WIDGET_TITLE, null)
            var text = prefs.getString(Prefs.WIDGET_TEXT, null)
            if (prefs.getLong(Prefs.WIDGET_DAY, -1) != today || text == null) {
                val z = AzkarSource.zekrOfDay(context)
                title = "ذكر اليوم"
                text = z?.content ?: "سُبْحَانَ اللَّهِ وَبِحَمْدِهِ"
                prefs.edit().putLong(Prefs.WIDGET_DAY, today)
                    .putString(Prefs.WIDGET_TITLE, title).putString(Prefs.WIDGET_TEXT, text).apply()
            }
            val open = PendingIntent.getActivity(
                context, 10, Intent(context, MainActivity::class.java),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val next = PendingIntent.getBroadcast(
                context, 11, Intent(context, AzkarWidget::class.java).setAction(ACTION_NEXT),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            for (id in ids) {
                val v = RemoteViews(context.packageName, R.layout.azkar_widget)
                v.setTextViewText(R.id.widget_title, title)
                v.setTextViewText(R.id.widget_text, text)
                v.setOnClickPendingIntent(R.id.widget_text, open)
                v.setOnClickPendingIntent(R.id.widget_title, open)
                v.setOnClickPendingIntent(R.id.widget_next, next)
                mgr.updateAppWidget(id, v)
            }
        }
    }

    override fun onUpdate(context: Context, mgr: AppWidgetManager, ids: IntArray) {
        render(context, mgr, ids)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        if (intent.action == ACTION_NEXT) {
            val z = AzkarSource.random(context, 220)
            context.getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE).edit()
                .putLong(Prefs.WIDGET_DAY, AzkarSource.daysSince2024())
                .putString(Prefs.WIDGET_TITLE, "ذكر عشوائي")
                .putString(Prefs.WIDGET_TEXT, z?.content ?: "الْحَمْدُ لِلَّهِ")
                .apply()
            updateAll(context)
        }
    }
}
