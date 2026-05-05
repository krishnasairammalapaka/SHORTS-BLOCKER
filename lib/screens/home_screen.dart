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
  if (!context.mounted) {
    return false;
  }
  if (!isSet) {
    return _showSetPinDialog(context);
  }
  final result = await _showVerifyPinDialog(context);
  if (!context.mounted) {
    return false;
  }
  switch (result) {
    case _PinAuthResult.authorized:
      return true;
    case _PinAuthResult.cancelled:
      return false;
    case _PinAuthResult.resetRequested:
      final didAuthenticate =
          await AppLockController.instance.authenticateDevice(
        localizedReason: 'Verify your identity to reset the protection PIN',
      );
      if (!context.mounted || !didAuthenticate) {
        return false;
      }
      return _showSetPinDialog(
        context,
        title: 'Create New Protection PIN',
        subtitle: 'Enter a new 4-digit PIN to continue.',
        confirmLabel: 'Save PIN',
      );
  }
}

Future<bool> _showSetPinDialog(
  BuildContext context, {
  String title = 'Set Protection PIN',
  String subtitle = 'Create a 4-digit PIN for Protection Mode.',
  String confirmLabel = 'Save PIN',
}) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ProtectionPinDialog(
        title: title,
        subtitle: subtitle,
        confirmLabel: confirmLabel,
        mode: _ProtectionPinDialogMode.create,
        onCompleted: (pin) async {
          await ProtectionLock.setPassword(pin);
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop(true);
          }
          return true;
        },
      );
    },
  );

  return result ?? false;
}

Future<_PinAuthResult> _showVerifyPinDialog(BuildContext context) async {
  final result = await showDialog<_PinAuthResult>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return _ProtectionPinDialog(
        title: 'Enter Protection PIN',
        subtitle: 'Use your 4-digit PIN to change Protection Mode.',
        confirmLabel: 'Unlock',
        mode: _ProtectionPinDialogMode.verify,
        showForgotPassword: true,
        onForgotPassword: () {
          Navigator.of(dialogContext).pop(_PinAuthResult.resetRequested);
        },
        onCompleted: (pin) async {
          final ok = await ProtectionLock.verify(pin);
          if (!dialogContext.mounted) {
            return false;
          }
          if (!ok) {
            return 'Incorrect PIN.';
          }
          Navigator.of(dialogContext).pop(_PinAuthResult.authorized);
          return true;
        },
      );
    },
  );

  return result ?? _PinAuthResult.cancelled;
}

enum _PinAuthResult { authorized, cancelled, resetRequested }

enum _ProtectionPinDialogMode { create, verify }

class _ProtectionPinDialog extends StatefulWidget {
  const _ProtectionPinDialog({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    required this.mode,
    required this.onCompleted,
    this.showForgotPassword = false,
    this.onForgotPassword,
  });

  final String title;
  final String subtitle;
  final String confirmLabel;
  final _ProtectionPinDialogMode mode;
  final Future<Object?> Function(String pin) onCompleted;
  final bool showForgotPassword;
  final VoidCallback? onForgotPassword;

  @override
  State<_ProtectionPinDialog> createState() => _ProtectionPinDialogState();
}

class _ProtectionPinDialogState extends State<_ProtectionPinDialog> {
  String _pin = '';
  String? _firstPin;
  String? _errorText;
  bool _submitting = false;

  bool get _isCreateMode => widget.mode == _ProtectionPinDialogMode.create;
  bool get _isConfirming => _isCreateMode && _firstPin != null;
  String get _headline => _isConfirming ? 'Confirm your PIN' : widget.subtitle;

  void _appendDigit(String digit) {
    if (_submitting || _pin.length >= ProtectionLock.pinLength) {
      return;
    }

    setState(() {
      _pin += digit;
      _errorText = null;
    });

    if (_pin.length == ProtectionLock.pinLength) {
      _handleCompletedPin();
    }
  }

  void _backspace() {
    if (_submitting || _pin.isEmpty) {
      return;
    }

    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _errorText = null;
    });
  }

  Future<void> _handleCompletedPin() async {
    if (!ProtectionLock.isValidPin(_pin)) {
      setState(() {
        _errorText = 'PIN must be exactly 4 digits.';
        _pin = '';
      });
      return;
    }

    if (_isCreateMode && !_isConfirming) {
      setState(() {
        _firstPin = _pin;
        _pin = '';
        _errorText = null;
      });
      return;
    }

    if (_isCreateMode && _firstPin != _pin) {
      setState(() {
        _pin = '';
        _firstPin = null;
        _errorText = 'PINs did not match. Try again.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    final response = await widget.onCompleted(_pin);
    if (!mounted) {
      return;
    }

    if (response is String && response.isNotEmpty) {
      setState(() {
        _pin = '';
        _submitting = false;
        _errorText = response;
      });
      return;
    }

    setState(() {
      _submitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final dialogContentWidth = (screenWidth - 96).clamp(220.0, 320.0);
    return AlertDialog(
      title: Text(widget.title),
      contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      content: SizedBox(
        width: dialogContentWidth,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _headline,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 18),
            _PinIndicator(length: _pin.length),
            const SizedBox(height: 18),
            if (_errorText != null) ...[
              Text(
                _errorText!,
                style: const TextStyle(color: Colors.redAccent),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
            ],
            _PinKeypad(
              enabled: !_submitting,
              onDigitPressed: _appendDigit,
              onBackspacePressed: _backspace,
            ),
            if (widget.showForgotPassword) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: _submitting ? null : widget.onForgotPassword,
                child: const Text('Forgot PIN?'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting || _pin.length != ProtectionLock.pinLength
              ? null
              : _handleCompletedPin,
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

class _PinIndicator extends StatelessWidget {
  const _PinIndicator({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(
        ProtectionLock.pinLength,
        (index) {
          final filled = index < length;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            height: 16,
            width: 16,
            decoration: BoxDecoration(
              color: filled
                  ? Theme.of(context).colorScheme.primary
                  : const Color(0xFFD7DEE5),
              shape: BoxShape.circle,
            ),
          );
        },
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigitPressed,
    required this.onBackspacePressed,
  });

  final bool enabled;
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;

  @override
  Widget build(BuildContext context) {
    final keys = const [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      ['', '0', 'back'],
    ];

    return Column(
      children: keys.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const Expanded(child: SizedBox(height: 56));
              }
              if (key == 'back') {
                return Expanded(
                  child: _PinKeyButton(
                    enabled: enabled,
                    icon: Icons.backspace_outlined,
                    onPressed: onBackspacePressed,
                  ),
                );
              }
              return Expanded(
                child: _PinKeyButton(
                  enabled: enabled,
                  label: key,
                  onPressed: () => onDigitPressed(key),
                ),
              );
            }).toList().separated(const SizedBox(width: 8)),
          ),
        );
      }).toList(),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  const _PinKeyButton({
    required this.enabled,
    required this.onPressed,
    this.label,
    this.icon,
  });

  final bool enabled;
  final VoidCallback onPressed;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: FilledButton.tonal(
        onPressed: enabled ? onPressed : null,
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: icon != null
            ? Icon(icon)
            : Text(
                label!,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
      ),
    );
  }
}

extension on List<Widget> {
  List<Widget> separated(Widget separator) {
    if (length < 2) return this;
    final output = <Widget>[first];
    for (var index = 1; index < length; index++) {
      output
        ..add(separator)
        ..add(this[index]);
    }
    return output;
  }
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
            colorScheme.primary.withValues(alpha: 0.95),
            colorScheme.secondary.withValues(alpha: 0.9),
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
              'assets/focusloop.png',
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
                  'FocusLoop',
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
    final surfaceColor = Theme.of(context).cardColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
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
    final colorScheme = Theme.of(context).colorScheme;
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
                          color: colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;
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
                        ? const Color(0xFF1FBF75).withValues(alpha: 0.14)
                        : const Color(0xFFE0963D).withValues(alpha: 0.16),
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
                  ?.copyWith(color: colorScheme.onSurfaceVariant),
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
        color: color.withValues(alpha: 0.1),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
        color: Theme.of(context).cardColor,
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
                ?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
