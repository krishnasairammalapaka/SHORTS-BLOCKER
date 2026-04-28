package com.example.shorts_blocker.platform

import android.content.Context
import com.example.shorts_blocker.service.ShortsStatsStore
import io.flutter.plugin.common.EventChannel

object StatsEventBridge {
    @Volatile
    private var eventSink: EventChannel.EventSink? = null
    @Volatile
    private var appContext: Context? = null

    fun init(context: Context) {
        appContext = context.applicationContext
    }

    fun setSink(sink: EventChannel.EventSink?) {
        eventSink = sink
    }

    fun pushStats() {
        val context = appContext ?: return
        eventSink?.success(ShortsStatsStore.getStatsMap(context))
    }
}
