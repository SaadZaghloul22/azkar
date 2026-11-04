package com.azk.azkarak

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * Watchdog for the floating azkar. Some phones (realme/Oppo/Xiaomi…) kill the foreground
 * service in the background. An AlarmManager alarm survives that: when it fires and the
 * service is gone, it restarts it (or, if the system refuses, shows the zekr directly).
 */
object OverlayAlarm {
    private const val REQ = 7201

    private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
        context, REQ,
        Intent(context, OverlayAlarmReceiver::class.java).setAction(OverlayAlarmReceiver.ACTION_TICK),
        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
    )

    fun schedule(context: Context, delayMs: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val at = System.currentTimeMillis() + delayMs
        val pi = pending(context)
        try {
            val exact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
            if (exact && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.set(AlarmManager.RTC_WAKEUP, at, pi)
            }
        } catch (_: SecurityException) {
            am.set(AlarmManager.RTC_WAKEUP, at, pi)
        }
    }

    fun cancel(context: Context) {
        (context.getSystemService(Context.ALARM_SERVICE) as AlarmManager).cancel(pending(context))
    }
}

class OverlayAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_TICK = "com.azk.azkarak.overlay.TICK"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_TICK) return
        val config = Prefs.overlayConfig(context) ?: return
        if (!config.optBoolean("enabled", false)) return
        val interval = config.optInt("intervalMinutes", 15).coerceIn(1, 240) * 60_000L
        // Keep the chain going whatever happens below.
        OverlayAlarm.schedule(context, interval)
        if (OverlayService.running) return // service alive: it shows azkar itself
        try {
            OverlayService.start(context, showNow = true)
        } catch (_: Exception) {
            // System refused to start the service from background: show this one directly.
            if (OverlayService.allowedNow(context, config)) {
                val pending = goAsync()
                AzkarSource.pickForOverlay(context, config)?.let {
                    OverlayWindow.show(context, it, config.optInt("displaySeconds", 10).coerceAtMost(8))
                }
                android.os.Handler(android.os.Looper.getMainLooper())
                    .postDelayed({ pending.finish() }, 9_000)
            }
        }
    }
}
