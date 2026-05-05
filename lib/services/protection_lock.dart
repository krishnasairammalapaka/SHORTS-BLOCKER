import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProtectionLock {
  ProtectionLock._();

  static const String _keyHash = 'protection_lock_hash';
  static const int pinLength = 4;

  static Future<bool> isSet() async {
    final prefs = await SharedPreferences.getInstance();
    final hash = prefs.getString(_keyHash);
    return hash != null && hash.isNotEmpty;
  }

  static Future<void> setPassword(String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHash, _hash(password));
  }

  static Future<bool> verify(String password) async {
    final prefs = await SharedPreferences.getInstance();
    final storedHash = prefs.getString(_keyHash);
    if (storedHash == null || storedHash.isEmpty) {
      return false;
    }
    return storedHash == _hash(password);
  }

  static bool isValidPin(String value) {
    if (value.length != pinLength) {
      return false;
    }
    return RegExp(r'^\d+$').hasMatch(value);
  }

  static String _hash(String value) {
    final bytes = utf8.encode(value);
    return sha256.convert(bytes).toString();
  }
}
