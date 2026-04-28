package com.example.shorts_blocker.service

import android.content.Context
import android.graphics.Color
import android.graphics.PixelFormat
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

class ShortsOverlayManager(private val context: Context) {
    private val appContext = context.applicationContext
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null
    private var pulseAnimator: ObjectAnimator? = null

    fun show(title: String, subtitle: String): Boolean {
        if (overlayView != null) {
            updateText(title, subtitle)
            return true
        }

        val container = FrameLayout(appContext).apply {
            setBackgroundColor(Color.parseColor("#D9000000"))
            isClickable = true
            isFocusable = false
            setOnTouchListener { _: View, _: MotionEvent -> true }
        }

        val content = LinearLayout(appContext).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }

        val titleText = TextView(appContext).apply {
            text = title
            textSize = 28f
            gravity = Gravity.CENTER
            setTextColor(Color.WHITE)
            setPadding(0, 0, 0, 16)
            tag = "overlay_title"
        }

        val subtitleText = TextView(appContext).apply {
            text = subtitle
            textSize = 18f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#D9FFFFFF"))
            tag = "overlay_subtitle"
        }

        val mascot = TextView(appContext).apply {
            text = ":-)"
            textSize = 56f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#FFF5C542"))
            setPadding(0, 0, 0, 20)
            tag = "overlay_mascot"
        }

        content.addView(mascot)
        content.addView(titleText)
        content.addView(subtitleText)

        container.addView(
            content,
            FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT,
                FrameLayout.LayoutParams.MATCH_PARENT,
                Gravity.CENTER,
            ),
        )

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_FULLSCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.CENTER
        }

        try {
            windowManager.addView(container, params)
            overlayView = container
            startMascotAnimation(mascot)
            return true
        } catch (primaryException: Exception) {
            Log.e(TAG, "Application overlay failed, trying accessibility overlay", primaryException)
            try {
                params.type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                windowManager.addView(container, params)
                overlayView = container
                startMascotAnimation(mascot)
                return true
            } catch (fallbackException: Exception) {
                Log.e(TAG, "Accessibility overlay fallback failed", fallbackException)
                overlayView = null
                return false
            }
        }
    }

    fun dismiss() {
        val currentView = overlayView ?: return
        try {
            pulseAnimator?.cancel()
            pulseAnimator = null
            windowManager.removeView(currentView)
        } catch (_: Exception) {
            // Ignore cleanup exceptions.
        } finally {
            overlayView = null
        }
    }

    private fun updateText(title: String, subtitle: String) {
        val root = overlayView as? FrameLayout ?: return
        val titleView = root.findViewWithTag<TextView>("overlay_title")
        val subtitleView = root.findViewWithTag<TextView>("overlay_subtitle")
        titleView?.text = title
        subtitleView?.text = subtitle
    }

    private fun startMascotAnimation(mascot: View) {
        pulseAnimator?.cancel()
        pulseAnimator = ObjectAnimator.ofFloat(mascot, "translationY", 0f, -18f, 0f).apply {
            duration = 900
            repeatMode = ValueAnimator.RESTART
            repeatCount = ValueAnimator.INFINITE
            start()
        }
    }

    companion object {
        private const val TAG = "ShortsOverlayManager"
    }
}
