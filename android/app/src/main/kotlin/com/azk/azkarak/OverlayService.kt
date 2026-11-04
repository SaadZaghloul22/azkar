package com.azk.azkarak

import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.Color
import android.media.AudioManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.PowerManager
import org.json.JSONObject
import java.util.Calendar

/**
 * Foreground service that shows a zekr every N minutes while the user is using the phone.
 * Skips: outside chosen hours, screen off/locked, during calls, and in Do Not Disturb.
 */
class OverlayService : Service() {
    companion object {
        const val ACTION_START = "com.azk.azkarak.overlay.START"
        const val ACTION_STOP = "com.azk.azkarak.overlay.STOP"
        private const val CHANNEL = "auto_azkar_service"
        private const val FG_ID = 7101

        @Volatile var running = false

        fun start(context: Context) {
            val i = Intent(context, OverlayService::class.java).setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(i)
            else context.startService(i)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, OverlayService::class.java))
        }

        /** Whether a zekr may be shown right now under the user's rules. */
        fun allowedNow(context: Context, config: JSONObject): Boolean {
            val hour = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)
            val start = config.optInt("startHour", 7)
            val end = config.optInt("endHour", 23)
            val inHours = when {
                start == end -> true
                start < end -> hour in start until end
                else -> hour >= start || hour < end
            }
            if (!inHours) return false
            val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!pm.isInteractive) return false
            val km = context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
            if (km.isKeyguardLocked) return false
            val am = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            if (am.mode == AudioManager.MODE_IN_CALL ||
                am.mode == AudioManager.MODE_IN_COMMUNICATION ||
                am.mode == AudioManager.MODE_RINGTONE) return false
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M &&
                nm.currentInterruptionFilter > NotificationManager.INTERRUPTION_FILTER_ALL) return false
            return true
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var intervalMs = 15 * 60_000L

    private val tick = object : Runnable {
        override fun run() {
            val config = Prefs.overlayConfig(this@OverlayService)
            if (config == null || !config.optBoolean("enabled", false)) {
                stopSelf()
                return
            }
            intervalMs = config.optInt("intervalMinutes", 15).coerceIn(1, 240) * 60_000L
            if (allowedNow(this@OverlayService, config)) {
                AzkarSource.pickForOverlay(this@OverlayService, config)?.let {
                    OverlayWindow.show(this@OverlayService, it, config.optInt("displaySeconds", 10))
                }
            }
            handler.postDelayed(this, intervalMs)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopSelf()
            return START_NOT_STICKY
        }
        startInForeground()
        running = true
        val config = Prefs.overlayConfig(this)
        intervalMs = (config?.optInt("intervalMinutes", 15) ?: 15).coerceIn(1, 240) * 60_000L
        handler.removeCallbacks(tick)
        handler.postDelayed(tick, intervalMs)
        return START_STICKY
    }

    private fun startInForeground() {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "تشغيل الأذكار التلقائية", NotificationManager.IMPORTANCE_MIN).apply {
                    description = "إشعار ثابت يبقي الأذكار التلقائية تعمل"
                    setShowBadge(false)
                }
            )
        }
        val open = PendingIntent.getActivity(
            this, 1, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val stop = PendingIntent.getService(
            this, 2, Intent(this, OverlayService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(this, CHANNEL) else Notification.Builder(this)
        val n = b.setSmallIcon(R.drawable.ic_stat_azkar)
            .setContentTitle("الأذكار التلقائية تعمل")
            .setContentText("سيظهر لك ذكر كل فترة بإذن الله")
            .setColor(Color.parseColor("#0E6B4E"))
            .setOngoing(true)
            .setContentIntent(open)
            .addAction(Notification.Action.Builder(null, "إيقاف", stop).build())
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(FG_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(FG_ID, n)
        }
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        OverlayWindow.remove(this)
        running = false
        super.onDestroy()
    }
}
