package com.example.shorts_blocker.service

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import org.json.JSONArray

object ShortsStatsStore {
    private const val PREFS_NAME = "shorts_blocker_prefs"
    private const val KEY_DATE = "date"
    private const val KEY_ATTEMPTS_TODAY = "attempts_today"
    private const val KEY_BLOCKS_TODAY = "blocks_today"
    private const val KEY_BLOCKING_ENABLED = "blocking_enabled"
    private const val KEY_LOGS = "block_logs"
    private const val MAX_LOGS = 30

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    private fun todayKey(): String {
        return SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    }

    @Synchronized
    private fun ensureToday(context: Context) {
        val currentDate = todayKey()
        val sharedPreferences = prefs(context)
        val storedDate = sharedPreferences.getString(KEY_DATE, null)

        if (storedDate != currentDate) {
            sharedPreferences.edit()
                .putString(KEY_DATE, currentDate)
                .putInt(KEY_ATTEMPTS_TODAY, 0)
                .putInt(KEY_BLOCKS_TODAY, 0)
                .putString(KEY_LOGS, "[]")
                .apply()
        }
    }

    @Synchronized
    fun addLog(context: Context, message: String) {
        ensureToday(context)
        val sharedPreferences = prefs(context)
        val rawLogs = sharedPreferences.getString(KEY_LOGS, "[]") ?: "[]"
        val logsArray = JSONArray(rawLogs)
        val timestamp = SimpleDateFormat("HH:mm", Locale.US).format(Date())
        val entry = "$timestamp - $message"
        val newArray = JSONArray()
        newArray.put(entry)
        for (index in 0 until logsArray.length()) {
            if (newArray.length() >= MAX_LOGS) break
            newArray.put(logsArray.getString(index))
        }
        sharedPreferences.edit().putString(KEY_LOGS, newArray.toString()).apply()
    }

    @Synchronized
    fun getLogs(context: Context): List<String> {
        ensureToday(context)
        val rawLogs = prefs(context).getString(KEY_LOGS, "[]") ?: "[]"
        val logsArray = JSONArray(rawLogs)
        val output = ArrayList<String>(logsArray.length())
        for (index in 0 until logsArray.length()) {
            output.add(logsArray.getString(index))
        }
        return output
    }

    @Synchronized
    fun isBlockingEnabled(context: Context): Boolean {
        return prefs(context).getBoolean(KEY_BLOCKING_ENABLED, true)
    }

    @Synchronized
    fun setBlockingEnabled(context: Context, enabled: Boolean) {
        prefs(context).edit().putBoolean(KEY_BLOCKING_ENABLED, enabled).apply()
    }

    @Synchronized
    fun incrementAttempt(context: Context): Int {
        ensureToday(context)
        val sharedPreferences = prefs(context)
        val newValue = sharedPreferences.getInt(KEY_ATTEMPTS_TODAY, 0) + 1
        sharedPreferences.edit().putInt(KEY_ATTEMPTS_TODAY, newValue).apply()
        return newValue
    }

    @Synchronized
    fun incrementBlock(context: Context): Int {
        ensureToday(context)
        val sharedPreferences = prefs(context)
        val newValue = sharedPreferences.getInt(KEY_BLOCKS_TODAY, 0) + 1
        sharedPreferences.edit().putInt(KEY_BLOCKS_TODAY, newValue).apply()
        return newValue
    }

    @Synchronized
    fun getAttemptsToday(context: Context): Int {
        ensureToday(context)
        return prefs(context).getInt(KEY_ATTEMPTS_TODAY, 0)
    }

    @Synchronized
    fun getBlocksToday(context: Context): Int {
        ensureToday(context)
        return prefs(context).getInt(KEY_BLOCKS_TODAY, 0)
    }

    @Synchronized
    fun isDailyLimitExceeded(context: Context): Boolean {
        return getAttemptsToday(context) > 5
    }

    @Synchronized
    fun getStatsMap(context: Context): Map<String, Any> {
        val attemptsToday = getAttemptsToday(context)
        val blocksToday = getBlocksToday(context)
        return mapOf(
            KEY_ATTEMPTS_TODAY to attemptsToday,
            KEY_BLOCKS_TODAY to blocksToday,
            "limit_exceeded" to (attemptsToday > 5),
        )
    }
}
