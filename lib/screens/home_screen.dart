import 'package:flutter/material.dart';

import '../services/app_lock.dart';
import '../services/platform_bridge.dart';
import '../services/protection_lock.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.onRefresh,
  });

  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
        children: [
          _HeroHeader(colorScheme: colorScheme),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: PlatformBridge.blockingEnabled,
            builder: (context, enabled, _) {
              return _StatusStrip(
                enabled: enabled,
                onToggle: (value) async {
                  final allowed = await _authorizeProtectionToggle(context);
                  if (allowed) {
                    await PlatformBridge.setBlockingEnabled(value);
                  }
                },
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: PlatformBridge.blockingEnabled,
            builder: (context, enabled, _) {
              return _FeatureCard(
                title: 'Protection Mode',
                subtitle: 'Applies immediately in YouTube.',
                trailing: Switch(
                  value: enabled,
                  onChanged: (value) async {
                    final allowed = await _authorizeProtectionToggle(context);
                    if (allowed) {
                      await PlatformBridge.setBlockingEnabled(value);
                    }
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<bool>(
            valueListenable: AppLockController.instance.enabled,
            builder: (context, enabled, _) {
              return _FeatureCard(
                title: 'App Lock',
                subtitle:
                    'Require device authentication to open this app.',
                trailing: Switch(
                  value: enabled,
                  onChanged: (value) async {
                    await AppLockController.instance.setEnabled(value);
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          ValueListenableBuilder<ShortsStats>(
            valueListenable: PlatformBridge.stats,
            builder: (context, stats, _) {
              return _FeatureCard(
                title: 'Daily Limits',
                subtitle: stats.limitExceeded
                    ? 'Limit exceeded. Blocking triggers instantly.'
                    : 'First 5 attempts use a 3-second delay.',
                trailing: _MetricPill(
                  label: 'Attempts',
                  value: stats.attemptsToday.toString(),
                  color: stats.limitExceeded
                      ? const Color(0xFFE96B63)
                      : const Color(0xFF2F3B45),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          Text(
            'Quick Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<bool>(
            valueListenable: PlatformBridge.accessibilityEnabled,
            builder: (context, enabled, _) {
              return _ActionCard(
                title: 'Accessibility Service',
                subtitle: enabled
                    ? 'Enabled and actively monitoring YouTube.'
                    : 'Enable to detect Shorts screens.',
                isGranted: enabled,
                buttonLabel: 'Open Accessibility Settings',
                onPressed: PlatformBridge.openAccessibilitySettings,
              );
            },
          ),
          const SizedBox(height: 12),
          ValueListenableBuilder<bool>(
            valueListenable: PlatformBridge.overlayPermissionGranted,
            builder: (context, granted, _) {
              return _ActionCard(
                title: 'Overlay Permission',
                subtitle: granted
                    ? 'Granted and ready to show overlays.'
                    : 'Required to display the block screen.',
                isGranted: granted,
                buttonLabel: 'Open Overlay Settings',
                onPressed: PlatformBridge.openOverlaySettings,
              );
            },
          ),
          const SizedBox(height: 20),
          _InfoPanel(
            title: 'Automatic Protection',
            description:
                'When Shorts is detected, the overlay appears for 3 seconds '
                'and then the app navigates back automatically. No prompts, '
                'no continue option, just focus.',
          ),
        ],
      ),
    );
  }
}

Future<bool> _authorizeProtectionToggle(BuildContext context) async {
  final isSet = await ProtectionLock.isSet();
  if (!isSet) {
    return _showSetPasswordDialog(context);
  }
  return _showVerifyPasswordDialog(context);
}

Future<bool> _showSetPasswordDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  final confirmController = TextEditingController();
  String? errorText;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Set Protection Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New password',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm password',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final password = passwordController.text.trim();
                  final confirm = confirmController.text.trim();
                  if (password.length < 4) {
                    setState(() {
                      errorText = 'Password must be at least 4 characters.';
                    });
                    return;
                  }
                  if (password != confirm) {
                    setState(() {
                      errorText = 'Passwords do not match.';
                    });
                    return;
                  }
                  await ProtectionLock.setPassword(password);
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      );
    },
  );

  return result ?? false;
}

Future<bool> _showVerifyPasswordDialog(BuildContext context) async {
  final passwordController = TextEditingController();
  String? errorText;

  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Enter Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                  ),
                ),
                if (errorText != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorText!,
                    style: const TextStyle(color: Colors.redAccent),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final password = passwordController.text.trim();
                  final ok = await ProtectionLock.verify(password);
                  if (!ok) {
                    setState(() {
                      errorText = 'Incorrect password.';
                    });
                    return;
                  }
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text('Unlock'),
              ),
            ],
          );
        },
      );
    },
  );

  return result ?? false;
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withOpacity(0.95),
            colorScheme.secondary.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            height: 64,
            width: 64,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.contain,
              errorBuilder: (context, _, __) {
                return const Icon(Icons.shield, color: Color(0xFF0F6D6B));
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Shorts Blocker',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Focus-first protection that blocks YouTube Shorts\n'
                  'automatically.',
                  style: TextStyle(color: Color(0xFFEFF6F6), height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({
    required this.enabled,
    required this.onToggle,
  });

  final bool enabled;
  final Future<void> Function(bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E8EC)),
      ),
      child: Row(
        children: [
          Container(
            height: 10,
            width: 10,
            decoration: BoxDecoration(
              color: enabled ? const Color(0xFF1FBF75) : const Color(0xFFE96B63),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              enabled ? 'Protection Active' : 'Protection Paused',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton(
            onPressed: () => onToggle(!enabled),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: Text(enabled ? 'Pause' : 'Resume'),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5A6772),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.isGranted,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final bool isGranted;
  final String buttonLabel;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 34,
                  width: 34,
                  decoration: BoxDecoration(
                    color: isGranted
                        ? const Color(0xFFE6F8F1)
                        : const Color(0xFFFFF4E5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isGranted ? Icons.verified : Icons.warning_amber_rounded,
                    color: isGranted
                        ? const Color(0xFF1FBF75)
                        : const Color(0xFFE0963D),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: const Color(0xFF5A6772)),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: onPressed,
              child: Text(buttonLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8ED)),
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: const Color(0xFF5A6772)),
          ),
        ],
      ),
    );
  }
}
