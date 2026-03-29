import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/group_member.dart';
import '../models/local_user.dart';
import '../models/user_stats.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../services/check_in_service.dart';
import '../services/local_storage_service.dart';
import '../services/risk_detection_service.dart';
import '../services/sponsor_service.dart';
import 'check_in_history_screen.dart';
import 'register_screen.dart';

class ProfileScreen extends StatefulWidget {
  final LocalUser user;
  final void Function(LocalUser updated) onRankedUp;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onRankedUp,
    required this.onLogout,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _rankLabels = {
    'anonymous': 'Anonymous',
    'apprentice': 'Apprentice',
    'sponsor': 'Sponsor',
    'leader': 'Leader',
    'influencer': 'Influencer',
    'graduated': 'Graduated',
  };

  static const _rankDescriptions = {
    'anonymous': 'You\'re browsing anonymously. Register to participate.',
    'apprentice':
        'You\'re on your journey. You can post, connect with a sponsor, and join a group.',
    'sponsor': 'You\'re guiding others in their recovery.',
    'leader': 'You lead a small group and help set the pace.',
    'influencer': 'You share your story to reduce stigma and inspire others.',
    'graduated':
        'You\'ve marked your recovery. You can stay on to support others.',
  };

  UserStats? _stats;
  bool _becomeSponsorPending = false;
  bool _monitoringActive = false;
  final _riskService = RiskDetectionService();

  @override
  void initState() {
    super.initState();
    _loadStats();
    _checkMonitoringStatus();
  }

  @override
  void didUpdateWidget(ProfileScreen old) {
    super.didUpdateWidget(old);
    if (old.user.userId != widget.user.userId) {
      _loadStats();
      _checkMonitoringStatus();
    }
  }

  Future<void> _checkMonitoringStatus() async {
    final status = await _riskService.getMonitoringStatus();
    if (!mounted) return;
    final enabled = status['accessibility_enabled'] == true;
    final connected = status['service_connected'] == true;
    final hasUser = (status['user_id'] as String?)?.isNotEmpty == true;
    setState(() => _monitoringActive = enabled && connected && hasUser);
  }

  Future<void> _loadStats() async {
    if (!widget.user.isRegistered) return;
    try {
      final stats = await CheckInService().getStats(widget.user.userId!);
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // silently degrade — stats section just won't show
    }
    if (widget.user.rank == 'apprentice') {
      try {
        final pending = await SponsorService().getBecomeSponsorStatus(widget.user.userId!);
        if (mounted) setState(() => _becomeSponsorPending = pending);
      } catch (_) {}
    }
  }

  Future<void> _requestBecomeSponsor() async {
    try {
      await SponsorService().becomeSponsor(widget.user.userId!);
      if (mounted) {
        setState(() => _becomeSponsorPending = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request sent to your group leader.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _restoreRole() async {
    try {
      final newRole = await SponsorService().restoreRole(widget.user.userId!);
      final updated = await LocalStorageService().saveRegistration(
        widget.user.userId!,
        widget.user.alias,
        groupId: widget.user.groupId,
        role: newRole,
        sponsorId: widget.user.sponsorId,
      );
      widget.onRankedUp(updated);
      await _loadStats();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Your ${_rankLabel(newRole)} role has been restored.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  static String _rankLabel(String rank) {
    const labels = {
      'sponsor': 'Sponsor',
      'leader': 'Leader',
      'influencer': 'Influencer',
    };
    return labels[rank] ?? rank;
  }

  Future<void> _rankUp() async {
    final result = await Navigator.push<LocalUser>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(currentAlias: widget.user.alias),
      ),
    );
    if (result != null) widget.onRankedUp(result);
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You\'ll need to log back in or start fresh.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await LocalStorageService().logout();
      widget.onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = widget.user;
    final label = _rankLabels[user.rank] ?? user.rank;
    final description = _rankDescriptions[user.rank] ?? '';

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20, 0, 20, 24 + MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Top row ──────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    icon: const Icon(Icons.logout_outlined),
                    tooltip: 'Log out',
                    onPressed: _confirmLogout,
                  ),
                ],
              ),

              // ── Avatar ───────────────────────────────────────────────────
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primaryContainer,
                  backgroundImage: user.profilePicture != null
                      ? MemoryImage(base64Decode(
                          user.profilePicture!.contains(',')
                              ? user.profilePicture!.split(',').last
                              : user.profilePicture!,
                        ))
                      : null,
                  child: user.profilePicture == null
                      ? Text(
                          user.alias.isNotEmpty ? user.alias[0].toUpperCase() : '?',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // ── Alias + location ─────────────────────────────────────────
              Text(
                user.alias,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (user.location != null && user.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      user.location!,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 14),

              // ── Rank badges ──────────────────────────────────────────────
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Badge(
                    label: label,
                    color: cs.primaryContainer,
                    textColor: cs.onPrimaryContainer,
                  ),
                  if (user.isLeader)
                    _Badge(
                      label: 'Group Leader',
                      color: cs.secondaryContainer,
                      textColor: cs.onSecondaryContainer,
                    ),
                  if (_monitoringActive)
                    _Badge(
                      label: 'Monitored',
                      color: cs.tertiaryContainer,
                      textColor: cs.onTertiaryContainer,
                      icon: Icons.shield_outlined,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),

              // ── Stats + progress ─────────────────────────────────────────
              if (user.isRegistered && _stats != null) ...[
                const SizedBox(height: 28),
                _StatsRow(stats: _stats!),
                const SizedBox(height: 12),
                _SponsorProgressCard(
                  stats: _stats!,
                  rank: user.rank,
                  onRestoreRole: _restoreRole,
                  becomeSponsorPending: _becomeSponsorPending,
                  onRequestBecomeSponsor: user.rank == 'apprentice'
                      ? _requestBecomeSponsor
                      : null,
                ),
              ],

              // ── Registered sections ──────────────────────────────────────
              if (user.isRegistered) ...[
                const SizedBox(height: 16),
                _SponsorStatusSection(
                  key: ValueKey('sponsor_${user.userId}'),
                  user: user,
                  onUserUpdated: widget.onRankedUp,
                ),
                _ApprenticeListSection(
                  key: ValueKey('apprentices_${user.userId}'),
                  user: user,
                ),
                const SizedBox(height: 10),
                _CardTile(
                  icon: Icons.history_outlined,
                  title: 'Check-in history',
                  subtitle: 'Review your daily check-in entries',
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          CheckInHistoryScreen(userId: user.userId!),
                    ),
                  ),
                ),
              ],

              // ── Rank up ──────────────────────────────────────────────────
              if (user.rank == 'anonymous') ...[
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: _rankUp,
                  child: const Text('Register as Apprentice'),
                ),
              ],

              // ── Debug switcher ───────────────────────────────────────────
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                _DebugUserSwitcher(onSwitch: widget.onRankedUp),
                const SizedBox(height: 12),
                if (widget.user.userId != null)
                  _DebugRiskTrigger(user: widget.user),
                const SizedBox(height: 12),
                if (widget.user.userId != null)
                  _DebugMonitoringStatus(riskService: _riskService),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Stats row ──────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final UserStats stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            value: stats.daysClean.toString(),
            label: 'Days clean',
            icon: Icons.spa_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            value: stats.totalCheckIns.toString(),
            label: 'Check-ins',
            icon: Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _StatCard(
            value: stats.daysActive.toString(),
            label: 'Days active',
            icon: Icons.calendar_today_outlined,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: cs.onSurfaceVariant),
          const SizedBox(height: 6),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Sponsor progress card ──────────────────────────────────────────────────────

class _SponsorProgressCard extends StatelessWidget {
  final UserStats stats;
  final String rank;
  final VoidCallback onRestoreRole;
  final bool becomeSponsorPending;
  final VoidCallback? onRequestBecomeSponsor;

  static const int _target = 90;

  static const _milestones = [
    (threshold: 0, label: 'Getting started'),
    (threshold: 10, label: 'Active member'),
    (threshold: 30, label: 'Group member'),
    (threshold: 90, label: 'Sponsor-eligible'),
  ];

  const _SponsorProgressCard({
    required this.stats,
    required this.rank,
    required this.onRestoreRole,
    this.becomeSponsorPending = false,
    this.onRequestBecomeSponsor,
  });

  bool get _alreadySponsor =>
      rank == 'sponsor' || rank == 'leader' || rank == 'influencer';

  String get _currentMilestoneLabel {
    String label = _milestones.first.label;
    for (final m in _milestones) {
      if (stats.progressCheckIns >= m.threshold) label = m.label;
    }
    return label;
  }

  String get _nextMilestoneLabel {
    for (final m in _milestones) {
      if (stats.progressCheckIns < m.threshold) return m.label;
    }
    return '';
  }

  int get _nextMilestoneThreshold {
    for (final m in _milestones) {
      if (stats.progressCheckIns < m.threshold) return m.threshold;
    }
    return _target;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final eligible = stats.progressCheckIns >= _target;
    final paused = stats.isPaused;

    final progress = (stats.progressCheckIns / _target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.volunteer_activism_outlined,
                  size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 8),
              Text(
                'Your path to helping others',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _alreadySponsor && !stats.isDemoted
                ? 'You\'re already helping others — keep showing up.'
                : 'Check-ins build readiness. Every day you show up makes you better equipped to walk alongside someone else.',
            style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),

          // ── Pause / demotion banners ─────────────────────────────────────
          if (stats.pauseTier == 3) ...[
            const SizedBox(height: 12),
            _PauseBanner(
              icon: Icons.block_outlined,
              color: cs.errorContainer,
              onColor: cs.onErrorContainer,
              message: 'Sponsor status suspended. '
                  'Your check-ins are never erased — reach ${_target - stats.progressCheckIns} more to re-earn eligibility.',
            ),
          ] else if (stats.pauseTier == 2 && stats.pauseDaysRemaining > 0) ...[
            const SizedBox(height: 12),
            _PauseBanner(
              icon: Icons.hourglass_top_outlined,
              color: cs.tertiaryContainer,
              onColor: cs.onTertiaryContainer,
              message: 'Sponsor role paused for 60 days — ${stats.pauseDaysRemaining} day${stats.pauseDaysRemaining == 1 ? "" : "s"} remaining. '
                  'Your role and relationships are preserved.',
            ),
          ] else if (stats.pauseTier == 1 && stats.pauseDaysRemaining > 0) ...[
            const SizedBox(height: 12),
            _PauseBanner(
              icon: Icons.pause_circle_outline,
              color: cs.tertiaryContainer,
              onColor: cs.onTertiaryContainer,
              message: 'Progress paused for 30 days — ${stats.pauseDaysRemaining} day${stats.pauseDaysRemaining == 1 ? "" : "s"} remaining. '
                  'Your check-ins are never lost.',
            ),
          ],

          // ── Restore prompt (pause ended but role not yet reclaimed) ───────
          if (stats.isDemoted && stats.pauseDaysRemaining == 0 && stats.pauseTier != 3) ...[
            const SizedBox(height: 12),
            _PauseBanner(
              icon: Icons.check_circle_outline,
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              message: 'Your pause has ended. You can reclaim your ${_rankLabel(stats.originalRole)} role.',
              action: FilledButton.tonal(
                onPressed: onRestoreRole,
                child: const Text('Reclaim role'),
              ),
            ),
          ],
          if (stats.isDemoted && stats.pauseTier == 3 && eligible) ...[
            const SizedBox(height: 12),
            _PauseBanner(
              icon: Icons.check_circle_outline,
              color: cs.primaryContainer,
              onColor: cs.onPrimaryContainer,
              message: 'You\'ve re-earned sponsor eligibility. Reclaim your ${_rankLabel(stats.originalRole)} role.',
              action: FilledButton.tonal(
                onPressed: onRestoreRole,
                child: const Text('Reclaim role'),
              ),
            ),
          ],

          const SizedBox(height: 14),

          // ── Progress bar ─────────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(
                paused ? cs.tertiary : cs.primary,
              ),
            ),
          ),
          const SizedBox(height: 8),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                eligible || (_alreadySponsor && !stats.isDemoted)
                    ? _currentMilestoneLabel
                    : '${stats.progressCheckIns} / $_nextMilestoneThreshold to "$_nextMilestoneLabel"',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${stats.progressCheckIns} check-ins',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          if (eligible && !_alreadySponsor && !stats.isDemoted) ...[
            const SizedBox(height: 12),
            if (becomeSponsorPending)
              _PauseBanner(
                icon: Icons.hourglass_top_outlined,
                color: cs.tertiaryContainer,
                onColor: cs.onTertiaryContainer,
                message: 'Your request is awaiting leader approval.',
              )
            else
              _PauseBanner(
                icon: Icons.check_circle_outline,
                color: cs.primaryContainer,
                onColor: cs.onPrimaryContainer,
                message: 'You\'ve reached sponsor eligibility.',
                action: onRequestBecomeSponsor != null
                    ? FilledButton.tonal(
                        onPressed: onRequestBecomeSponsor,
                        child: const Text('Request sponsor status'),
                      )
                    : null,
              ),
          ],

          // ── Milestone dots ───────────────────────────────────────────────
          const SizedBox(height: 14),
          Row(
            children: _milestones.map((m) {
              final reached = stats.progressCheckIns >= m.threshold;
              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: reached
                            ? (paused ? cs.tertiary : cs.primary)
                            : cs.surfaceContainerHighest,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontSize: 9,
                        color: reached
                            ? cs.onSurface
                            : cs.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  static String _rankLabel(String rank) {
    const labels = {
      'sponsor': 'Sponsor',
      'leader': 'Leader',
      'influencer': 'Influencer',
    };
    return labels[rank] ?? rank;
  }
}

class _PauseBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color onColor;
  final String message;
  final Widget? action;

  const _PauseBanner({
    required this.icon,
    required this.color,
    required this.onColor,
    required this.message,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: onColor),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: onColor),
                ),
                if (action != null) ...[
                  const SizedBox(height: 8),
                  action!,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: textColor,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Card tile ──────────────────────────────────────────────────────────────────

class _CardTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 12, 20),
          child: Row(
            children: [
              Icon(icon, color: cs.onSurfaceVariant, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sponsor status ─────────────────────────────────────────────────────────────

class _SponsorStatusSection extends StatefulWidget {
  final LocalUser user;
  final void Function(LocalUser) onUserUpdated;

  const _SponsorStatusSection({
    super.key,
    required this.user,
    required this.onUserUpdated,
  });

  @override
  State<_SponsorStatusSection> createState() => _SponsorStatusSectionState();
}

class _SponsorStatusSectionState extends State<_SponsorStatusSection> {
  bool _loading = true;
  String? _confirmedAlias;
  ({int notifId, int sponsorId, String sponsorAlias})? _pending;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = widget.user.userId!;
    String? confirmed;
    ({int notifId, int sponsorId, String sponsorAlias})? pending;

    if (widget.user.sponsorId != null) {
      final member =
          await SponsorService().getUserBasic(widget.user.sponsorId!);
      if (member != null) confirmed = member.alias;
    }

    if (confirmed == null) {
      pending = await SponsorService().getOutgoingRequest(userId);
    }

    if (mounted) {
      setState(() {
        _confirmedAlias = confirmed;
        _pending = pending;
        _loading = false;
      });
    }
  }

  Future<void> _removeConfirmed() async {
    try {
      await SponsorService().removeConfirmedSponsor(widget.user.userId!);
      final updated = await LocalStorageService().clearSponsorId();
      if (mounted) {
        setState(() => _confirmedAlias = null);
        widget.onUserUpdated(updated);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _rescindPending() async {
    try {
      await SponsorService().cancelRequest(widget.user.userId!);
      if (mounted) setState(() => _pending = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || (_confirmedAlias == null && _pending == null)) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Icon(
                _confirmedAlias != null
                    ? Icons.volunteer_activism_outlined
                    : Icons.hourglass_top_outlined,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _confirmedAlias != null
                          ? 'Your sponsor'
                          : 'Sponsor request pending',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _confirmedAlias ?? _pending!.sponsorAlias,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: _confirmedAlias != null
                    ? _removeConfirmed
                    : _rescindPending,
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child:
                    Text(_confirmedAlias != null ? 'Remove' : 'Rescind'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Apprentice list ────────────────────────────────────────────────────────────

class _ApprenticeListSection extends StatefulWidget {
  final LocalUser user;
  const _ApprenticeListSection({super.key, required this.user});

  @override
  State<_ApprenticeListSection> createState() => _ApprenticeListSectionState();
}

class _ApprenticeListSectionState extends State<_ApprenticeListSection> {
  List<GroupMember> _apprentices = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await SponsorService().getApprentices(widget.user.userId!);
      if (mounted) {
        setState(() {
          _apprentices = list;
          _loaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _remove(GroupMember apprentice) async {
    try {
      await SponsorService()
          .removeApprentice(widget.user.userId!, apprentice.id);
      if (mounted) setState(() => _apprentices.remove(apprentice));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded || _apprentices.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              child: Text(
                'PEOPLE YOU SPONSOR',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
            ..._apprentices.map((a) => Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: Row(
                    children: [
                      Icon(Icons.person_outline,
                          size: 20, color: cs.onSurfaceVariant),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(a.alias,
                                style: theme.textTheme.bodyMedium
                                    ?.copyWith(fontWeight: FontWeight.w500)),
                            Text(a.role,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _remove(a),
                        style:
                            TextButton.styleFrom(foregroundColor: cs.error),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ── Debug user switcher ────────────────────────────────────────────────────────

class _DebugUserSwitcher extends StatefulWidget {
  final void Function(LocalUser) onSwitch;
  const _DebugUserSwitcher({required this.onSwitch});

  @override
  State<_DebugUserSwitcher> createState() => _DebugUserSwitcherState();
}

class _DebugUserSwitcherState extends State<_DebugUserSwitcher> {
  static const _seedUsers = [
    (alias: 'Alice', phone: '+44700000001'),
    (alias: 'Bob', phone: '+44700000002'),
    (alias: 'Marcus', phone: '+44700000005'),
    (alias: 'Carol', phone: '+44700000003'),
    (alias: 'Dan', phone: '+44700000004'),
    (alias: 'Sophie', phone: '+44700000006'),
    (alias: 'Eve', phone: '+1200000001'),
    (alias: 'Frank', phone: '+1200000002'),
    (alias: 'Grace', phone: '+1200000003'),
    (alias: 'Henry', phone: '+44161000001'),
    (alias: 'Isla', phone: '+44161000002'),
  ];

  String? _loading;

  Future<void> _loginAs(String alias, String phone) async {
    setState(() => _loading = alias);
    try {
      final apiUser = await AuthService().login(phone, 'password');
      final localUser = await LocalStorageService().saveRegistration(
        apiUser.id,
        apiUser.alias,
        groupId: apiUser.groupId > 0 ? apiUser.groupId : null,
        role: apiUser.role,
        sponsorId: apiUser.sponsorId > 0 ? apiUser.sponsorId : null,
        addictionType: apiUser.addictionType,
        profilePicture: apiUser.profilePicture,
      );
      widget.onSwitch(localUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Debug login failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.bug_report, size: 14),
            const SizedBox(width: 4),
            Text('Debug — switch user',
                style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _seedUsers.map((u) {
            final isLoading = _loading == u.alias;
            return ActionChip(
              label: isLoading
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(u.alias),
              onPressed:
                  _loading != null ? null : () => _loginAs(u.alias, u.phone),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ── Debug risk trigger ─────────────────────────────────────────────────────────

class _DebugRiskTrigger extends StatefulWidget {
  final LocalUser user;
  const _DebugRiskTrigger({required this.user});

  @override
  State<_DebugRiskTrigger> createState() => _DebugRiskTriggerState();
}

class _DebugRiskTriggerState extends State<_DebugRiskTrigger> {
  bool _firing = false;
  final _svc = RiskDetectionService();

  Future<void> _fire() async {
    setState(() => _firing = true);
    final status = await _svc.testAlert(widget.user.userId!, apiBase);
    if (!mounted) return;
    setState(() => _firing = false);
    final msg = switch (status) {
      'notified'      => 'Sponsor notified.',
      'no_sponsor'    => 'No sponsor on this account (DB shows sponsor_id = 0).',
      _               => 'Unexpected: $status',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.bug_report, size: 14),
        const SizedBox(width: 4),
        Text('Debug — risk alert',
            style: Theme.of(context).textTheme.labelSmall),
        const Spacer(),
        FilledButton.tonal(
          onPressed: _firing ? null : _fire,
          child: _firing
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Fire test alert'),
        ),
      ],
    );
  }
}

// ── Debug monitoring status ───────────────────────────────────────────────────

class _DebugMonitoringStatus extends StatefulWidget {
  final RiskDetectionService riskService;
  const _DebugMonitoringStatus({required this.riskService});

  @override
  State<_DebugMonitoringStatus> createState() => _DebugMonitoringStatusState();
}

class _DebugMonitoringStatusState extends State<_DebugMonitoringStatus> {
  Map<String, dynamic> _status = {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final s = await widget.riskService.getMonitoringStatus();
    if (mounted) setState(() => _status = s);
  }

  String _formatLastEvent() {
    final ms = _status['last_event_ms'];
    if (ms == null || ms == 0) return 'none';
    final dt = DateTime.fromMillisecondsSinceEpoch((ms as num).toInt());
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accEnabled = _status['accessibility_enabled'] == true;
    final svcConnected = _status['service_connected'] == true;
    final userId = _status['user_id'] as String? ?? '';
    final lastPkg = _status['last_package'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bug_report, size: 14),
              const SizedBox(width: 4),
              Text('Debug — monitoring status',
                  style: theme.textTheme.labelSmall),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.refresh, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _refresh,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _statusRow('Accessibility enabled', accEnabled),
          _statusRow('Service connected', svcConnected),
          _statusRow('User ID stored', userId.isNotEmpty),
          const SizedBox(height: 4),
          Text('Last event: ${_formatLastEvent()}',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          if (lastPkg.isNotEmpty)
            Text('Last package: $lastPkg',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _statusRow(String label, bool ok) {
    return Row(
      children: [
        Icon(
          ok ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: ok ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
