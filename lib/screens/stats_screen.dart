import 'package:flutter/material.dart';

import '../services/platform_bridge.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ShortsStats>(
      valueListenable: PlatformBridge.stats,
      builder: (context, stats, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          children: [
            _StatsHero(
              attempts: stats.attemptsToday,
              blocks: stats.blocksToday,
              limitExceeded: stats.limitExceeded,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: 'Attempts Today',
                    value: stats.attemptsToday.toString(),
                    icon: Icons.touch_app,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatCard(
                    title: 'Blocks Today',
                    value: stats.blocksToday.toString(),
                    icon: Icons.block,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _LimitCard(limitExceeded: stats.limitExceeded),
            const SizedBox(height: 16),
            Text(
              'Logs',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Each entry tells you what type of Shorts was blocked so you can prove focus protection.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<List<String>>(
              valueListenable: PlatformBridge.logs,
              builder: (context, logs, _) {
                if (logs.isEmpty) {
                  return const _EmptyLogsCard();
                }

                return _LogsCard(entries: logs);
              },
            ),
          ],
        );
      },
    );
  }
}

class _StatsHero extends StatelessWidget {
  const _StatsHero({
    required this.attempts,
    required this.blocks,
    required this.limitExceeded,
  });

  final int attempts;
  final int blocks;
  final bool limitExceeded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.9),
            colorScheme.secondary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Today',
                  style: TextStyle(color: Color(0xFFEFF6F6), fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '${blocks + attempts} total interactions',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  limitExceeded
                      ? 'Limit exceeded. Instant blocking active.'
                      : 'Delay overlay active for first 5 attempts.',
                  style: const TextStyle(color: Color(0xFFEFF6F6)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  attempts.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Text(
                  'Attempts',
                  style: TextStyle(color: Color(0xFFEFF6F6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.primary.withValues(alpha: 0.14),
              child: Icon(icon, color: colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LimitCard extends StatelessWidget {
  const _LimitCard({required this.limitExceeded});

  final bool limitExceeded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: ListTile(
        leading: Container(
          height: 38,
          width: 38,
          decoration: BoxDecoration(
            color: limitExceeded
                ? const Color(0xFFE96B63).withValues(alpha: 0.14)
                : colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            limitExceeded ? Icons.lock_clock : Icons.timelapse_rounded,
            color: limitExceeded ? const Color(0xFFE96B63) : colorScheme.primary,
          ),
        ),
        title: const Text('Daily Limit'),
        subtitle: Text(
          limitExceeded
              ? 'Limit exceeded: blocking is instant now.'
              : 'Active: first 5 attempts include a delay overlay.',
        ),
      ),
    );
  }
}

class _LogsCard extends StatelessWidget {
  const _LogsCard({required this.entries});

  final List<String> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: entries.take(8).map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF1FBF75)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _EmptyLogsCard extends StatelessWidget {
  const _EmptyLogsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'No blocks recorded yet. Open Shorts to see what gets blocked.',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
