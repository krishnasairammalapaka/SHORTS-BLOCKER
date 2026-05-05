import 'package:flutter/widgets.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLockController with WidgetsBindingObserver {
  AppLockController._();

  static final AppLockController instance = AppLockController._();

  static const _prefKey = 'app_lock_enabled';

  final LocalAuthentication _auth = LocalAuthentication();
  final ValueNotifier<bool> enabled = ValueNotifier<bool>(false);
  final ValueNotifier<bool> unlocked = ValueNotifier<bool>(true);
  bool _authInProgress = false;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    final prefs = await SharedPreferences.getInstance();
    enabled.value = prefs.getBool(_prefKey) ?? false;

    if (enabled.value) {
      unlocked.value = false;
      await authenticate();
    }
  }

  Future<void> setEnabled(bool value) async {
    enabled.value = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (value) {
      unlocked.value = false;
      await authenticate();
    } else {
      unlocked.value = true;
    }
  }

  Future<void> authenticate() async {
    if (_authInProgress) return;
    if (!enabled.value) {
      unlocked.value = true;
      return;
    }

    _authInProgress = true;

    try {
      final didAuth = await authenticateDevice(
        localizedReason: 'Unlock FocusLoop',
      );
      unlocked.value = didAuth;
    } catch (_) {
      unlocked.value = false;
    } finally {
      _authInProgress = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!enabled.value) return;
    if (state == AppLifecycleState.resumed) {
      if (!unlocked.value) {
        authenticate();
      }
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  Future<bool> authenticateDevice({
    required String localizedReason,
  }) async {
    final isSupported = await _auth.isDeviceSupported();
    if (!isSupported) {
      return false;
    }

    return _auth.authenticate(
      localizedReason: localizedReason,
      options: const AuthenticationOptions(
        biometricOnly: false,
        stickyAuth: true,
        useErrorDialogs: true,
      ),
    );
  }
}
