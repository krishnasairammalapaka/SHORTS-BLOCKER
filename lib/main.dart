import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'services/app_lock.dart';
import 'services/platform_bridge.dart';
import 'services/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ShortsBlockerApp());
}

class ShortsBlockerApp extends StatefulWidget {
  const ShortsBlockerApp({super.key});

  @override
  State<ShortsBlockerApp> createState() => _ShortsBlockerAppState();
}

class _ShortsBlockerAppState extends State<ShortsBlockerApp> {
  int _tabIndex = 0;
  final AppLockController _appLock = AppLockController.instance;
  final ThemeController _themeController = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    PlatformBridge.initialize();
    _appLock.initialize();
    _themeController.initialize();
  }

  @override
  void dispose() {
    PlatformBridge.dispose();
    _appLock.dispose();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait<void>([
      PlatformBridge.refreshPermissions(),
      PlatformBridge.refreshStats(),
      PlatformBridge.refreshBlockingEnabled(),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeController.mode,
      builder: (context, themeMode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'FocusLoop',
          theme: _buildTheme(Brightness.light),
          darkTheme: _buildTheme(Brightness.dark),
          themeMode: themeMode,
          home: Scaffold(
            appBar: AppBar(
              title: const Text('FocusLoop'),
              actions: [
                IconButton(
                  tooltip: themeMode == ThemeMode.dark
                      ? 'Switch to light mode'
                      : 'Switch to dark mode',
                  onPressed: () {
                    _themeController.setDarkMode(themeMode != ThemeMode.dark);
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    transitionBuilder: (child, animation) {
                      return RotationTransition(
                        turns: Tween<double>(begin: 0.8, end: 1.0).animate(animation),
                        child: FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_rounded
                          : Icons.light_mode_rounded,
                      key: ValueKey<ThemeMode>(themeMode),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _refreshAll,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            body: ValueListenableBuilder<bool>(
              valueListenable: _appLock.unlocked,
              builder: (context, unlocked, _) {
                if (!unlocked) {
                  return LockScreen(onUnlock: _appLock.authenticate);
                }

                return IndexedStack(
                  index: _tabIndex,
                  children: [
                    HomeScreen(onRefresh: _refreshAll),
                    const StatsScreen(),
                  ],
                );
              },
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tabIndex,
              onDestinationSelected: (value) {
                setState(() {
                  _tabIndex = value;
                });
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Stats',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

ThemeData _buildTheme(Brightness brightness) {
  const brandTeal = Color(0xFF0F6D6B);
  const accent = Color(0xFF37B3A9);
  final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();
  final isDark = brightness == Brightness.dark;

  final colorScheme = ColorScheme.fromSeed(
    seedColor: brandTeal,
    brightness: brightness,
  ).copyWith(
    primary: isDark ? const Color(0xFF4CC7BE) : brandTeal,
    secondary: isDark ? const Color(0xFF69DCD1) : accent,
    surface: isDark ? const Color(0xFF12171C) : const Color(0xFFF6F7F9),
  );

  final scaffoldColor = isDark ? const Color(0xFF0C1116) : const Color(0xFFF6F7F9);
  final cardColor = isDark ? const Color(0xFF161D24) : Colors.white;
  final textPrimary = isDark ? const Color(0xFFE8EEF3) : const Color(0xFF2F3B45);
  final textSecondary = isDark ? const Color(0xFF99A7B5) : const Color(0xFF5A6772);
  final borderColor = isDark ? const Color(0xFF22303C) : const Color(0xFFE4E8EC);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: scaffoldColor,
    cardColor: cardColor,
    dividerColor: borderColor,
    textTheme: baseTextTheme.copyWith(
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: textPrimary),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: textSecondary),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: scaffoldColor,
      foregroundColor: textPrimary,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: baseTextTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: borderColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? Colors.white
            : (isDark ? const Color(0xFF758394) : const Color(0xFFB6BDC5));
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        return states.contains(WidgetState.selected)
            ? colorScheme.primary
            : (isDark ? const Color(0xFF2A3642) : const Color(0xFFE0E4E8));
      }),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: cardColor,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.16),
      labelTextStyle: WidgetStateProperty.all(
        baseTextTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
  );
}

class LockScreen extends StatelessWidget {
  const LockScreen({
    super.key,
    required this.onUnlock,
  });

  final Future<void> Function() onUnlock;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 96,
              width: 96,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Image.asset(
                'assets/focusloop.png',
                fit: BoxFit.contain,
                errorBuilder: (context, _, __) {
                  return const Icon(Icons.shield, color: Color(0xFF0F6D6B));
                },
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'App Locked',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Use device authentication to continue.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onUnlock,
              icon: const Icon(Icons.lock_open),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}
