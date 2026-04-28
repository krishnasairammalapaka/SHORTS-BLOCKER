package com.example.shorts_blocker.service

import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.PixelFormat
import android.util.Log
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import io.flutter.FlutterInjector

class ShortsOverlayManager(private val context: Context) {
    private val appContext = context.applicationContext
    private val windowManager = appContext.getSystemService(Context.WINDOW_SERVICE) as WindowManager
    private var overlayView: View? = null

    fun show(title: String, subtitle: String): Boolean {
        if (overlayView != null) {
            return true
        }

        val container = FrameLayout(appContext).apply {
            setBackgroundColor(Color.BLACK)
            isClickable = true
            isFocusable = false
            setOnTouchListener { _: View, _: MotionEvent -> true }
        }

        val overlayImage = buildOverlayImageView() ?: return false

        container.addView(
            overlayImage,
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
            return true
        } catch (primaryException: Exception) {
            Log.e(TAG, "Application overlay failed, trying accessibility overlay", primaryException)
            try {
                params.type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                windowManager.addView(container, params)
                overlayView = container
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
            windowManager.removeView(currentView)
        } catch (_: Exception) {
            // Ignore cleanup exceptions.
        } finally {
            overlayView = null
        }
    }

    private fun buildOverlayImageView(): ImageView? {
        val assetKey = FlutterInjector.instance().flutterLoader()
            .getLookupKeyForAsset(OVERLAY_ASSET)
        val bitmap = try {
            appContext.assets.open(assetKey).use(BitmapFactory::decodeStream)
        } catch (exception: Exception) {
            Log.e(TAG, "Failed to load overlay asset: $OVERLAY_ASSET", exception)
            null
        } ?: return null

        return ImageView(appContext).apply {
            setImageBitmap(bitmap)
            adjustViewBounds = true
            scaleType = ImageView.ScaleType.FIT_CENTER
            setBackgroundColor(Color.BLACK)
        }
    }

    companion object {
        private const val TAG = "ShortsOverlayManager"
        private const val OVERLAY_ASSET = "assets/Shortsdetected.png"
    }
}
