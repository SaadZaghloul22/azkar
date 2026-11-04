package com.azk.azkarak

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "azkarak/native")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "canDrawOverlays" -> result.success(OverlayWindow.canDraw(this))
                        "openOverlaySettings" -> {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                                startActivity(
                                    Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        "openBatterySettings" -> {
                            val i = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                                Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                            else Intent(Settings.ACTION_SETTINGS)
                            try {
                                startActivity(i)
                            } catch (_: Exception) {
                                startActivity(
                                    Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName"))
                                )
                            }
                            result.success(null)
                        }
                        "isOverlayRunning" -> result.success(OverlayService.running)
                        "overlayStatus" -> {
                            val p = getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE)
                            result.success(mapOf(
                                "status" to p.getString(Prefs.LAST_STATUS, null),
                                "at" to p.getLong(Prefs.LAST_STATUS_AT, 0L),
                                "manufacturer" to Build.MANUFACTURER,
                                "sdk" to Build.VERSION.SDK_INT
                            ))
                        }
                        "startOverlay" -> {
                            val cfg = call.argument<String>("config") ?: "{}"
                            getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE).edit()
                                .putString(Prefs.OVERLAY_CONFIG, cfg).apply()
                            if (JSONObject(cfg).optBoolean("enabled", false)) OverlayService.start(this)
                            result.success(null)
                        }
                        "stopOverlay" -> {
                            val prefs = getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE)
                            val cfg = Prefs.overlayConfig(this) ?: JSONObject()
                            cfg.put("enabled", false)
                            prefs.edit().putString(Prefs.OVERLAY_CONFIG, cfg.toString()).apply()
                            OverlayService.stop(this)
                            result.success(null)
                        }
                        "previewOverlay" -> {
                            val cfg = JSONObject(call.argument<String>("config") ?: "{}")
                            val z = AzkarSource.pickForOverlay(this, cfg) ?: AzkarSource.random(this)
                            if (z != null) OverlayWindow.show(this, z, cfg.optInt("displaySeconds", 10))
                            result.success(null)
                        }
                        "refreshWidget" -> {
                            AzkarWidget.updateAll(this)
                            result.success(null)
                        }
                        "requestPinWidget" -> {
                            var ok = false
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                                val mgr = getSystemService(AppWidgetManager::class.java)
                                if (mgr != null && mgr.isRequestPinAppWidgetSupported) {
                                    ok = mgr.requestPinAppWidget(ComponentName(this, AzkarWidget::class.java), null, null)
                                }
                            }
                            result.success(ok)
                        }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native_error", e.message, null)
                }
            }
    }
}
