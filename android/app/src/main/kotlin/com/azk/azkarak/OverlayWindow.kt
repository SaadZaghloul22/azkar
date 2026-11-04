package com.azk.azkarak

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.TextUtils
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView

/** Draws the floating zekr card over other apps, or falls back to a notification. */
object OverlayWindow {
    private const val MSG_CHANNEL = "auto_azkar_messages"
    private const val MSG_ID = 7102
    private val handler = Handler(Looper.getMainLooper())
    private var current: View? = null
    private var amiri: Typeface? = null
    private var cairo: Typeface? = null

    fun canDraw(context: Context): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.M || Settings.canDrawOverlays(context)

    fun show(context: Context, zekr: NativeZekr, seconds: Int) {
        if (!canDraw(context)) {
            setStatus(context, "no_permission")
            notify(context, zekr, needsPermission = true)
            return
        }
        handler.post { addView(context.applicationContext, zekr, seconds) }
    }

    private fun dp(context: Context, v: Float): Int =
        TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, context.resources.displayMetrics).toInt()

    private fun fonts(context: Context) {
        if (amiri == null) {
            amiri = try { Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Amiri_400Regular.ttf") } catch (_: Exception) { Typeface.SERIF }
        }
        if (cairo == null) {
            cairo = try { Typeface.createFromAsset(context.assets, "flutter_assets/assets/fonts/Cairo_700Bold.ttf") } catch (_: Exception) { Typeface.DEFAULT_BOLD }
        }
    }

    private fun addView(context: Context, zekr: NativeZekr, seconds: Int) {
        remove(context)
        fonts(context)
        val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager

        val card = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
            setPadding(dp(context, 18f), dp(context, 12f), dp(context, 18f), dp(context, 12f))
            background = GradientDrawable(
                GradientDrawable.Orientation.TR_BL,
                intArrayOf(Color.parseColor("#0E6B4E"), Color.parseColor("#0A5139"))
            ).apply {
                cornerRadius = dp(context, 22f).toFloat()
                setStroke(dp(context, 1.5f), Color.parseColor("#C9A227"))
            }
            elevation = dp(context, 8f).toFloat()
            alpha = 0f
        }

        val header = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            layoutDirection = View.LAYOUT_DIRECTION_RTL
        }
        val title = TextView(context).apply {
            text = "✦ ${zekr.title}"
            setTextColor(Color.parseColor("#E9D79A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = cairo
            maxLines = 1
            ellipsize = TextUtils.TruncateAt.END
            layoutParams = LinearLayout.LayoutParams(0, LinearLayout.LayoutParams.WRAP_CONTENT, 1f)
        }
        val close = TextView(context).apply {
            text = "✕"
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 18f)
            setPadding(dp(context, 10f), dp(context, 2f), dp(context, 4f), dp(context, 2f))
            contentDescription = "إغلاق"
            setOnClickListener { remove(context) }
        }
        header.addView(title)
        header.addView(close)

        val body = TextView(context).apply {
            text = zekr.content
            setTextColor(Color.WHITE)
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 19f)
            typeface = amiri
            gravity = Gravity.CENTER
            setLineSpacing(0f, 1.25f)
            maxLines = 7
            ellipsize = TextUtils.TruncateAt.END
            setPadding(0, dp(context, 6f), 0, dp(context, 6f))
        }

        val open = TextView(context).apply {
            text = "فتح التطبيق"
            setTextColor(Color.parseColor("#E9D79A"))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 13f)
            typeface = cairo
            gravity = Gravity.CENTER
            setPadding(dp(context, 8f), dp(context, 4f), dp(context, 8f), dp(context, 2f))
            setOnClickListener {
                remove(context)
                context.startActivity(
                    Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
        }

        card.addView(header)
        card.addView(body)
        card.addView(open)
        card.setOnClickListener { remove(context) }

        @Suppress("DEPRECATION")
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        else WindowManager.LayoutParams.TYPE_PHONE

        val width = context.resources.displayMetrics.widthPixels - dp(context, 32f)
        val params = WindowManager.LayoutParams(
            width,
            WindowManager.LayoutParams.WRAP_CONTENT,
            type,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT
        ).apply {
            gravity = Gravity.TOP or Gravity.CENTER_HORIZONTAL
            y = dp(context, 56f)
        }

        try {
            wm.addView(card, params)
            current = card
            card.animate().alpha(1f).setDuration(250).start()
            handler.postDelayed({ if (current === card) remove(context) }, seconds.coerceIn(3, 60) * 1000L)
            setStatus(context, "shown")
        } catch (e: Exception) {
            setStatus(context, "error:" + (e.javaClass.simpleName + " " + (e.message ?: "")).take(160))
            notify(context, zekr, needsPermission = false)
        }
    }

    fun remove(context: Context) {
        val v = current ?: return
        current = null
        try {
            (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager).removeView(v)
        } catch (_: Exception) {
        }
    }

    private fun setStatus(context: Context, status: String) {
        context.getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE).edit()
            .putString(Prefs.LAST_STATUS, status)
            .putLong(Prefs.LAST_STATUS_AT, System.currentTimeMillis())
            .apply()
    }

    /** Fallback when the floating window cannot be shown. */
    fun notify(context: Context, zekr: NativeZekr, needsPermission: Boolean) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(MSG_CHANNEL, "الأذكار التلقائية", NotificationManager.IMPORTANCE_DEFAULT).apply {
                    description = "ذكر يصلك كل فترة"
                    setSound(null, null)
                }
            )
        }
        val pi = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(context, MSG_CHANNEL) else Notification.Builder(context)
        b.setSmallIcon(R.drawable.ic_stat_azkar)
            .setContentTitle(zekr.title)
            .setContentText(zekr.content)
            .setStyle(Notification.BigTextStyle().bigText(zekr.content))
            .setColor(Color.parseColor("#0E6B4E"))
            .setAutoCancel(true)
            .setContentIntent(pi)
        if (needsPermission && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val grant = PendingIntent.getActivity(
                context, 3,
                Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, android.net.Uri.parse("package:" + context.packageName))
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            b.addAction(Notification.Action.Builder(null, "تفعيل النافذة العائمة", grant).build())
        }
        val n = b.build()
        try { nm.notify(MSG_ID, n) } catch (_: SecurityException) { }
    }
}
