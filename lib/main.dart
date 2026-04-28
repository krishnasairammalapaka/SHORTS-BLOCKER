import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/home_screen.dart';
import 'screens/stats_screen.dart';
import 'services/app_lock.dart';
import 'services/platform_bridge.dart';

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

  @override
  void initState() {
    super.initState();
    PlatformBridge.initialize();
    _appLock.initialize();
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
    const brandTeal = Color(0xFF0F6D6B);
    const slate = Color(0xFF2F3B45);
    const surface = Color(0xFFF6F7F9);
    const cardSurface = Colors.white;
    const accent = Color(0xFF37B3A9);
    final baseTextTheme = GoogleFonts.spaceGroteskTextTheme();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shorts Blocker',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandTeal,
          primary: brandTeal,
          secondary: accent,
          surface: surface,
          onSurface: const Color(0xFF111317),
        ),
        scaffoldBackgroundColor: surface,
        textTheme: baseTextTheme.copyWith(
          titleLarge: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: slate,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: slate,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(color: slate),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(color: slate),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: surface,
          foregroundColor: slate,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: baseTextTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: slate,
          ),
        ),
        cardTheme: CardThemeData(
          color: cardSurface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: brandTeal,
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
                : const Color(0xFFB6BDC5);
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? brandTeal
                : const Color(0xFFE0E4E8);
          }),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Shorts Blocker'),
          actions: [
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
  }
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
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Image.asset(
                'assets/logo.png',
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
