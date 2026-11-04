package com.azk.azkarak

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar
import kotlin.math.roundToLong

data class NativeZekr(val title: String, val content: String, val category: String)

/** Reads the same bundled azkar.json the Flutter app uses (single source of truth). */
object AzkarSource {
    @Volatile private var cache: List<NativeZekr>? = null

    fun all(context: Context): List<NativeZekr> {
        cache?.let { return it }
        val text = context.assets.open("flutter_assets/assets/data/azkar.json")
            .bufferedReader(Charsets.UTF_8).use { it.readText() }
        val cats = JSONObject(text).getJSONArray("categories")
        val out = ArrayList<NativeZekr>()
        for (i in 0 until cats.length()) {
            val c = cats.getJSONObject(i)
            val key = c.getString("id")
            val items = c.getJSONArray("items")
            for (j in 0 until items.length()) {
                val z = items.getJSONObject(j)
                out.add(NativeZekr(z.getString("title"), z.getString("content"), key))
            }
        }
        cache = out
        return out
    }

    /** Matches AppState.zekrOfDay in Dart so the widget and app agree. */
    fun zekrOfDay(context: Context): NativeZekr? {
        val pool = all(context).filter { it.content.length < 260 && !it.content.startsWith("يقرأ") }
        if (pool.isEmpty()) return null
        val idx = (daysSince2024() % pool.size).toInt()
        return pool[idx]
    }

    fun random(context: Context, maxLen: Int = 300): NativeZekr? {
        val pool = all(context).filter { it.content.length <= maxLen }
        return if (pool.isEmpty()) null else pool.random()
    }

    private fun midnight(year: Int, month: Int, day: Int): Long {
        val c = Calendar.getInstance()
        c.clear()
        c.set(year, month, day, 0, 0, 0)
        return c.timeInMillis
    }

    fun daysSince2024(): Long {
        val now = Calendar.getInstance()
        val today = midnight(now.get(Calendar.YEAR), now.get(Calendar.MONTH), now.get(Calendar.DAY_OF_MONTH))
        val base = midnight(2024, Calendar.JANUARY, 1)
        return ((today - base) / 86_400_000.0).roundToLong()
    }

    /** Picks a zekr for the floating window from the user's chosen categories and custom azkar. */
    fun pickForOverlay(context: Context, config: JSONObject): NativeZekr? {
        val cats = config.optJSONArray("categories") ?: JSONArray()
        val chosen = HashSet<String>()
        for (i in 0 until cats.length()) chosen.add(cats.getString(i))
        val pool = ArrayList<NativeZekr>()
        all(context).filterTo(pool) { it.category in chosen && it.content.length <= 360 }
        val custom = config.optJSONArray("custom") ?: JSONArray()
        for (i in 0 until custom.length()) pool.add(NativeZekr("من أذكاري", custom.getString(i), "custom"))
        if (pool.isEmpty()) return null
        if (config.optBoolean("random", true)) return pool.random()
        val prefs = context.getSharedPreferences(Prefs.FILE, Context.MODE_PRIVATE)
        val i = prefs.getInt(Prefs.SEQ_INDEX, 0)
        prefs.edit().putInt(Prefs.SEQ_INDEX, (i + 1) % pool.size).apply()
        return pool[i % pool.size]
    }
}

object Prefs {
    const val FILE = "azkar_native"
    const val OVERLAY_CONFIG = "overlay_config"
    const val SEQ_INDEX = "overlay_seq_index"
    const val WIDGET_TEXT = "widget_text"
    const val WIDGET_TITLE = "widget_title"
    const val WIDGET_DAY = "widget_day"
    const val LAST_STATUS = "overlay_last_status"
    const val LAST_STATUS_AT = "overlay_last_status_at"

    fun overlayConfig(context: Context): JSONObject? {
        val raw = context.getSharedPreferences(FILE, Context.MODE_PRIVATE)
            .getString(OVERLAY_CONFIG, null) ?: return null
        return try { JSONObject(raw) } catch (_: Exception) { null }
    }
}
