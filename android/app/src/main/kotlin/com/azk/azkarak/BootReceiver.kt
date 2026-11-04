package com.azk.azkarak

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Restarts the floating azkar service after reboot or app update if the user enabled it. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action != Intent.ACTION_BOOT_COMPLETED &&
            action != Intent.ACTION_MY_PACKAGE_REPLACED &&
            action != "android.intent.action.QUICKBOOT_POWERON") return
        val config = Prefs.overlayConfig(context)
        if (config != null && config.optBoolean("enabled", false)) {
            try {
                OverlayService.start(context)
            } catch (_: Exception) {
                // Background start refused: the watchdog alarm will retry shortly.
                OverlayAlarm.schedule(context, 60_000L)
            }
        }
        AzkarWidget.updateAll(context)
        try { UpdateChecker.scheduleDaily(context) } catch (_: Exception) { }
    }
}
