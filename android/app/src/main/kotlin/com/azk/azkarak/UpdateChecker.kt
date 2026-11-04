package com.azk.azkarak

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.net.Uri
import android.os.Build
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.install.model.UpdateAvailability

/**
 * Asks Google Play once a day whether a newer version is published and, if so,
 * posts a notification that opens the store page. Needs no server.
 */
object UpdateChecker {
    private const val CHANNEL = "app_updates"
    private const val NOTIF_ID = 7301
    private const val REQ = 7302
    private const val LAST_NOTIFIED = "update_last_notified_code"

    fun scheduleDaily(context: Context) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(
            context, REQ, Intent(context, UpdateCheckReceiver::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        am.setInexactRepeating(
            AlarmManager.RTC,
            System.currentTimeMillis() + AlarmManager.INTERVAL_HOUR * 3,
            AlarmManager.INTERVAL_DAY,
            pi
        )
    }

    fun storeIntent(context: Context): Intent {
        val market = Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=${context.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return if (market.resolveActivity(context.packageManager) != null) market
        else Intent(
            Intent.ACTION_VIEW,
            Uri.parse("https://play.google.com/store/apps/details?id=${context.packageName}")
        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
    }

    fun checkAndNotify(context: Context, done: () -> Unit) {
        try {
            AppUpdateManagerFactory.create(context).appUpdateInfo
                .addOnSuccessListener { info ->
                    if (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE) {
                        val prefs = context.getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE)
                        val code = info.availableVersionCode()
                        if (prefs.getInt(LAST_NOTIFIED, 0) != code) {
                            notify(context)
                            prefs.edit().putInt(LAST_NOTIFIED, code).apply()
                        }
                    }
                    done()
                }
                .addOnFailureListener { done() }
        } catch (_: Exception) {
            done()
        }
    }

    private fun notify(context: Context) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "تحديثات التطبيق", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "إشعار عند توفر إصدار جديد من التطبيق"
                }
            )
        }
        val pi = PendingIntent.getActivity(
            context, REQ + 1, storeIntent(context),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(context, CHANNEL) else Notification.Builder(context)
        val n = b.setSmallIcon(R.drawable.ic_stat_azkar)
            .setContentTitle("تحديث جديد لأذكار المسلم")
            .setContentText("اضغط لتحديث التطبيق والحصول على أحدث المميزات")
            .setColor(Color.parseColor("#0E6B4E"))
            .setAutoCancel(true)
            .setContentIntent(pi)
            .build()
        try { nm.notify(NOTIF_ID, n) } catch (_: SecurityException) { }
    }
}

class UpdateCheckReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val pending = goAsync()
        UpdateChecker.checkAndNotify(context.applicationContext) { pending.finish() }
    }
}
