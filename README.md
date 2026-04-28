# Shorts Blocker

Production-ready Flutter + Kotlin Android application to automatically block YouTube Shorts using an Accessibility Service.

## Features

- Monitors only `com.google.android.youtube` via Accessibility Service.
- Detects Shorts screen by traversing node tree and matching `text` / `contentDescription` containing `shorts`.
- Blocking flow:
	- Full-screen overlay
	- `Shorts Blocked` + `Stay Focused`
	- 3-second delay
	- Automatic BACK action
- Daily limit:
	- Tracks `attempts_today`, `blocks_today`, and `date`
	- When attempts exceed 5, instantly performs BACK
	- Shows `Shorts blocked for today`
- No continue button and no user interaction required on block overlay.
- Flutter UI:
	- Home: enable/disable toggle, open accessibility settings, open overlay settings
	- Stats: attempts today, blocks today, limit status
- Platform channels:
	- Flutter -> Kotlin: settings and toggle/stat calls
	- Kotlin -> Flutter: real-time stats updates (EventChannel)

## Architecture

### Flutter

- `lib/main.dart`: app shell, navigation, refresh flow
- `lib/screens/home_screen.dart`: controls and permissions entry points
- `lib/screens/stats_screen.dart`: daily usage stats
- `lib/services/platform_bridge.dart`: method/event channel integration

### Android (Kotlin)

- `MainActivity.kt`: MethodChannel + EventChannel handlers
- `service/ShortsAccessibilityService.kt`: Shorts detection + blocking flow
- `service/ShortsOverlayManager.kt`: full-screen non-interactive overlay via WindowManager
- `service/ShortsStatsStore.kt`: SharedPreferences-backed daily counters and blocking toggle
- `platform/StatsEventBridge.kt`: pushes native stats updates to Flutter
- `platform/ChannelContracts.kt`: channel names
- `res/xml/accessibility_config.xml`: accessibility service config

## Permissions and System Setup

Required on Android:

- Accessibility Service (manual enable by user)
- Draw over other apps (`SYSTEM_ALERT_WINDOW`)

Manifest entries are already configured in:

- `android/app/src/main/AndroidManifest.xml`

## Build and Run

1. Install dependencies:

```bash
flutter pub get
```

2. Run on Android device:

```bash
flutter run
```

3. In the app Home screen:

- Keep `Enable Shorts Blocking` turned on
- Tap `Open Accessibility Settings` and enable `Shorts Blocker`
- Tap `Open Overlay Settings` and allow draw over apps

## Testing Instructions

1. Open YouTube app on the device.
2. Navigate to Shorts content.
3. Verify expected behavior:
	 - Overlay appears with `Shorts Blocked` and `Stay Focused`
	 - After 3 seconds, app automatically goes BACK
4. Trigger blocking repeatedly until attempts exceed 5 for the day.
5. Verify after limit exceeded:
	 - BACK happens instantly
	 - Message shown: `Shorts blocked for today`
6. Open Stats tab in app and confirm counters update.

## Notes

- This app is focused on digital wellbeing and reduces accidental/repetitive Shorts consumption.
- Accessibility detection and overlay behavior can vary by OEM ROM policies and Android versions.
