package com.example.shorts_blocker.service

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityNodeInfo
import com.example.shorts_blocker.platform.StatsEventBridge
import java.util.Locale

class ShortsAccessibilityService : AccessibilityService() {
    private val mainHandler = Handler(Looper.getMainLooper())
    private lateinit var overlayManager: ShortsOverlayManager

    @Volatile
    private var blockInProgress = false
    private var lastBlockTimestamp = 0L

    override fun onServiceConnected() {
        super.onServiceConnected()
        overlayManager = ShortsOverlayManager(this)
        serviceInfo = serviceInfo.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
            packageNames = arrayOf(YOUTUBE_PACKAGE)
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 50
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        if (!ShortsStatsStore.isBlockingEnabled(this)) return

        val packageName = event.packageName?.toString() ?: return
        if (packageName != YOUTUBE_PACKAGE) return

        val eventType = event.eventType
        if (eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED &&
            eventType != AccessibilityEvent.TYPE_WINDOW_CONTENT_CHANGED
        ) {
            return
        }

        if (blockInProgress) return

        val now = System.currentTimeMillis()
        if (now - lastBlockTimestamp < BLOCK_DEBOUNCE_MS) return

        val eventNode = event.source
        val rootNode = rootInActiveWindow

        val signals = ShortsSignals()
        collectShortsSignals(eventNode, 0, signals)
        collectShortsSignals(rootNode, 0, signals)

        // Avoid triggering on the Home feed Shorts shelf; require player or URL signals.
        val isShortsScreen = signals.url || signals.player

        val reason = resolveBlockReason(event, signals)

        eventNode?.recycle()

        if (!isShortsScreen) return

        Log.d(TAG, "Shorts detected, triggering blocking flow")

        triggerBlockingFlow(reason)
    }

    override fun onInterrupt() {
        overlayManager.dismiss()
    }

    override fun onDestroy() {
        overlayManager.dismiss()
        super.onDestroy()
    }

    private fun triggerBlockingFlow(reason: String) {
        if (blockInProgress) return
        blockInProgress = true
        lastBlockTimestamp = System.currentTimeMillis()

        val attempts = ShortsStatsStore.incrementAttempt(this)
        ShortsStatsStore.incrementBlock(this)
        ShortsStatsStore.addLog(this, "Blocked: $reason - redirected to Home")
        StatsEventBridge.pushStats()

        val limitExceeded = attempts > DAILY_LIMIT
        val canDrawOverApps = Settings.canDrawOverlays(this)

        if (limitExceeded) {
            val shown = overlayManager.show("Shorts blocked for today", "Redirecting home...")
            Log.d(
                TAG,
                "Limit exceeded block. canDrawOverApps=$canDrawOverApps overlayShown=$shown",
            )
            mainHandler.postDelayed({
                openYouTubeHome()
                overlayManager.dismiss()
                blockInProgress = false
            }, NORMAL_FLOW_DELAY_MS)
            return
        }

        val shown = overlayManager.show("Shorts Blocked", "Redirecting home...")
        Log.d(
            TAG,
            "Normal block flow. canDrawOverApps=$canDrawOverApps overlayShown=$shown",
        )

        mainHandler.postDelayed({
            openYouTubeHome()
            overlayManager.dismiss()
            blockInProgress = false
        }, NORMAL_FLOW_DELAY_MS)
    }

    private fun resolveBlockReason(
        event: AccessibilityEvent,
        signals: ShortsSignals,
    ): String {
        return when {
            signals.url -> "Shorts link"
            signals.player -> "Shorts player"
            signals.reelViewId -> "Shorts reel"
            isShortsFromEvent(event) -> "Shorts section"
            signals.keyword -> "Shorts label"
            else -> "Shorts content"
        }
    }

    private fun openYouTubeHome(): Boolean {
        return try {
            val intent = Intent(
                Intent.ACTION_VIEW,
                Uri.parse("https://www.youtube.com"),
            ).apply {
                setPackage(YOUTUBE_PACKAGE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
            true
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to open YouTube home", exception)
            false
        }
    }

    private fun isShortsFromEvent(event: AccessibilityEvent): Boolean {
        val className = event.className?.toString()?.lowercase(Locale.US).orEmpty()
        if (className.contains("reel") || className.contains("shorts")) {
            return true
        }

        val description = event.contentDescription?.toString()?.lowercase(Locale.US).orEmpty()
        if (description.contains("/shorts/") || containsShortsKeyword(description)) {
            return true
        }

        return false
    }

    private fun collectShortsSignals(
        node: AccessibilityNodeInfo?,
        depth: Int,
        signals: ShortsSignals,
    ) {
        if (node == null) return
        if (depth > MAX_NODE_DEPTH) return

        val nodeText = node.text?.toString()?.lowercase(Locale.US).orEmpty()
        if (containsShortsKeyword(nodeText)) {
            signals.keyword = true
        }
        if (nodeText.contains("/shorts/")) {
            signals.url = true
        }

        val contentDescription = node.contentDescription?.toString()?.lowercase(Locale.US).orEmpty()
        if (containsShortsKeyword(contentDescription)) {
            signals.keyword = true
        }
        if (contentDescription.contains("/shorts/")) {
            signals.url = true
        }

        val viewId = node.viewIdResourceName?.lowercase(Locale.US).orEmpty()
        if (SHORTS_PLAYER_VIEW_ID_TOKENS.any { token -> viewId.contains(token) }) {
            signals.player = true
        }
        if (viewId.contains("reel")) {
            signals.reelViewId = true
        }

        val paneTitle = node.paneTitle?.toString()?.lowercase(Locale.US).orEmpty()
        if (containsShortsKeyword(paneTitle)) {
            signals.keyword = true
        }

        val stateDescription = node.stateDescription?.toString()?.lowercase(Locale.US).orEmpty()
        if (containsShortsKeyword(stateDescription)) {
            signals.keyword = true
        }

        for (index in 0 until node.childCount) {
            val child = node.getChild(index)
            collectShortsSignals(child, depth + 1, signals)
            child?.recycle()
        }
    }

    private fun containsShortsKeyword(value: String): Boolean {
        if (value.isBlank()) return false
        return SHORTS_KEYWORDS.any { keyword -> value.contains(keyword) }
    }

    companion object {
        private const val TAG = "ShortsBlockerService"
        private const val YOUTUBE_PACKAGE = "com.google.android.youtube"
        private const val DAILY_LIMIT = 5
        private const val NORMAL_FLOW_DELAY_MS = 1_000L
        private const val INSTANT_FLOW_OVERLAY_MS = 1_000L
        private const val BLOCK_DEBOUNCE_MS = 1_200L
        private const val MAX_NODE_DEPTH = 80
        private val SHORTS_KEYWORDS = listOf(
            "shorts",
        )
        private val SHORTS_PLAYER_VIEW_ID_TOKENS = listOf(
            "reel_player",
            "reel_watch",
            "reel_pager",
            "reel_container",
            "shorts_player",
            "shorts_video",
            "shorts_container",
        )
    }
}

private data class ShortsSignals(
    var keyword: Boolean = false,
    var player: Boolean = false,
    var url: Boolean = false,
    var reelViewId: Boolean = false,
)
