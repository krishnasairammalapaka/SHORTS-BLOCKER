package com.example.shorts_blocker

import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import com.example.shorts_blocker.platform.ChannelContracts
import com.example.shorts_blocker.platform.StatsEventBridge
import com.example.shorts_blocker.service.ShortsAccessibilityService
import com.example.shorts_blocker.service.ShortsStatsStore
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)
		StatsEventBridge.init(applicationContext)

		MethodChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			ChannelContracts.METHOD_CHANNEL,
		).setMethodCallHandler { call, result ->
			handleMethodCall(call, result)
		}

		EventChannel(
			flutterEngine.dartExecutor.binaryMessenger,
			ChannelContracts.STATS_EVENT_CHANNEL,
		).setStreamHandler(object : EventChannel.StreamHandler {
			override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
				StatsEventBridge.setSink(events)
				StatsEventBridge.pushStats()
			}

			override fun onCancel(arguments: Any?) {
				StatsEventBridge.setSink(null)
			}
		})
	}

	private fun handleMethodCall(call: MethodCall, result: MethodChannel.Result) {
		when (call.method) {
			"openAccessibilitySettings" -> {
				openAccessibilitySettings()
				result.success(null)
			}

			"openOverlaySettings" -> {
				openOverlaySettings()
				result.success(null)
			}

			"setBlockingEnabled" -> {
				val enabled = call.argument<Boolean>("enabled") ?: true
				ShortsStatsStore.setBlockingEnabled(this, enabled)
				StatsEventBridge.pushStats()
				result.success(null)
			}

			"getBlockingEnabled" -> {
				result.success(ShortsStatsStore.isBlockingEnabled(this))
			}

			"getStats" -> {
				result.success(ShortsStatsStore.getStatsMap(this))
			}

			"getLogs" -> {
				result.success(ShortsStatsStore.getLogs(this))
			}

			"isAccessibilityEnabled" -> {
				result.success(isAccessibilityServiceEnabled())
			}

			"isOverlayPermissionGranted" -> {
				result.success(isOverlayPermissionGranted())
			}

			else -> result.notImplemented()
		}
	}

	private fun openAccessibilitySettings() {
		val intent = Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		startActivity(intent)
	}

	private fun openOverlaySettings() {
		val intent = Intent(
			Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
			Uri.parse("package:$packageName"),
		).apply {
			addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
		}
		startActivity(intent)
	}

	private fun isOverlayPermissionGranted(): Boolean {
		return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
			Settings.canDrawOverlays(this)
		} else {
			true
		}
	}

	private fun isAccessibilityServiceEnabled(): Boolean {
		val accessibilityEnabled =
			Settings.Secure.getInt(contentResolver, Settings.Secure.ACCESSIBILITY_ENABLED, 0) == 1
		if (!accessibilityEnabled) return false

		val expected = ComponentName(this, ShortsAccessibilityService::class.java).flattenToString()
		val enabledServices =
			Settings.Secure.getString(contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES)
				?: return false

		return enabledServices.split(':').any { service ->
			service.equals(expected, ignoreCase = true)
		}
	}
}
