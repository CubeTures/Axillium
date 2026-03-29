import 'dart:async';
import 'package:flutter/material.dart';
import '../models/check_in.dart';
import '../models/crisis_alert.dart';
import '../models/local_user.dart';
import '../screens/check_in_screen.dart';
import '../screens/sponsor_list_screen.dart';
import '../services/check_in_service.dart';
import '../services/crisis_service.dart';
import '../widgets/home_card.dart';

class HomeScreen extends StatefulWidget {
  final LocalUser user;
  final void Function(int tabIndex) onNavigate;
  final void Function(LocalUser)? onUserUpdated;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
    this.onUserUpdated,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CheckIn? _todayCheckIn;
  bool _loadingCheckIn = false;

  CrisisAlert? _activeAlert;
  bool _crisisLoading = false;
  Timer? _escalationTimer;

  static const _escalationWindow = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _fetchCheckIn();
    _loadActiveCrisis();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.user.userId != widget.user.userId) {
      _fetchCheckIn();
      _loadActiveCrisis();
    }
  }

  @override
  void dispose() {
    _escalationTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchCheckIn() async {
    if (!widget.user.isRegistered) return;
    setState(() {
      _loadingCheckIn = true;
      _todayCheckIn = null;
    });
    try {
      final ci = await CheckInService().getTodayCheckIn(widget.user.userId!);
      if (mounted) setState(() => _todayCheckIn = ci);
    } catch (_) {
      // silently degrade — button still shows, status just unknown
    } finally {
      if (mounted) setState(() => _loadingCheckIn = false);
    }
  }

  Future<void> _loadActiveCrisis() async {
    if (!widget.user.isRegistered) return;
    try {
      final alert = await CrisisService().getActive(widget.user.userId!);
      if (mounted && alert != null) {
        setState(() => _activeAlert = alert);
        _scheduleEscalationFromAlert(alert);
      }
    } catch (_) {
      // silently degrade
    }
  }

  /// Calculates remaining time based on when the alert was created and its
  /// current stage, then sets timers for any pending escalations.
  void _scheduleEscalationFromAlert(CrisisAlert alert) {
    _escalationTimer?.cancel();
    if (alert.resolved) return;

    final elapsed = DateTime.now().difference(alert.createdAt);

    if (alert.stage == 1) {
      final remaining = _escalationWindow - elapsed;
      if (remaining <= Duration.zero) {
        // Window already passed — escalate immediately
        _doEscalate(alert);
      } else {
        _escalationTimer = Timer(remaining, () => _doEscalate(_activeAlert!));
      }
    } else if (alert.stage == 2) {
      // Stage 2 started at ~5 min; escalate to 3 at ~10 min
      final remaining = (_escalationWindow * 2) - elapsed;
      if (remaining <= Duration.zero) {
        _doEscalate(alert);
      } else {
        _escalationTimer = Timer(remaining, () => _doEscalate(_activeAlert!));
      }
    }
    // Stage 3 = no more escalations
  }

  Future<void> _doEscalate(CrisisAlert alert) async {
    if (!mounted) return;
    if (alert.resolved) return;
    try {
      await CrisisService().escalate(alert.id, widget.user.userId!);
      if (!mounted) return;
      final updated = await CrisisService().getActive(widget.user.userId!);
      if (!mounted) return;
      if (updated != null) {
        setState(() => _activeAlert = updated);
        _scheduleEscalationFromAlert(updated);
      }
    } catch (_) {
      // silently degrade — try again on next load
    }
  }

  Future<void> _triggerCrisis() async {
    if (!widget.user.isRegistered) return;

    // Step 1: surface emergency services first (per project requirements)
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Are you safe right now?'),
        content: const Text(
          'If you are in immediate physical danger, please call emergency services first.',
        ),
        actions: [
          FilledButton.icon(
            icon: const Icon(Icons.call),
            label: const Text('Call 911'),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // Surface info — user taps themselves to call
              Navigator.pop(ctx, false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dial 911 or your local emergency number now.'),
                  duration: Duration(seconds: 8),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I need emotional support'),
          ),
        ],
      ),
    );

    if (proceed != true || !mounted) return;

    // Step 2: confirm before notifying the group
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reach out for help?'),
        content: Text(
          widget.user.sponsorId != null
              ? 'Your sponsor will be notified immediately. If they don\'t respond within 5 minutes, group sponsors will be contacted, then the wider community.'
              : 'Group sponsors will be notified. If no one responds within 5 minutes, the wider community will be contacted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, reach out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _crisisLoading = true);
    try {
      final alert = await CrisisService().trigger(
        userId: widget.user.userId!,
        userAlias: widget.user.alias,
        groupId: widget.user.groupId ?? 0,
      );
      if (!mounted) return;
      setState(() => _activeAlert = alert);
      _scheduleEscalationFromAlert(alert);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _crisisLoading = false);
    }
  }

  Future<void> _cancelCrisis() async {
    final alert = _activeAlert;
    if (alert == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel alert?'),
        content: const Text(
            'This will let your group know you\'re okay. People who saw the notification will not be notified that you cancelled.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep active'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('I\'m okay'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    _escalationTimer?.cancel();
    _escalationTimer = null;
    try {
      await CrisisService().cancel(alert.id, widget.user.userId!);
    } catch (_) {
      // best-effort
    }
    if (mounted) setState(() => _activeAlert = null);
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  Future<void> _goCheckIn() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CheckInScreen(
          userId: widget.user.userId!,
          alias: widget.user.alias,
          groupId: widget.user.groupId,
        ),
      ),
    );
    _fetchCheckIn();
  }

  Future<void> _goFindSponsor() async {
    final sponsorId = await Navigator.push<int>(
      context,
      MaterialPageRoute(
        builder: (_) => SponsorListScreen(
          groupId: widget.user.groupId!,
          userId: widget.user.userId!,
        ),
      ),
    );
    if (sponsorId != null && widget.onUserUpdated != null) {
      widget.onUserUpdated!(widget.user.copyWith(sponsorId: sponsorId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final user = widget.user;
    final isRegistered = user.isRegistered;

    final engage = <Widget>[];
    final explore = <Widget>[];

    if (!isRegistered) {
      engage.add(HomeTile(
        icon: Icons.lock_open_outlined,
        title: 'Join the community',
        subtitle:
            'Create an account to post, connect with a sponsor, and join a group.',
        iconColor: cs.primary,
        onTap: () => widget.onNavigate(4),
      ));
    } else {
      if (user.sponsorId == null && user.groupId != null) {
        engage.add(HomeTile(
          icon: Icons.handshake_outlined,
          title: 'Find a sponsor',
          subtitle: 'An experienced member who can walk alongside you.',
          iconColor: cs.primary,
          onTap: _goFindSponsor,
        ));
      }
    }

    explore.add(HomeTile(
      icon: Icons.chat_bubble_outline,
      title: 'Group chat',
      subtitle: user.addictionType != null
          ? '${user.addictionType} recovery group'
          : 'Talk with your recovery group',
      onTap: () => widget.onNavigate(1),
    ));
    explore.add(HomeTile(
      icon: Icons.people_outline,
      title: 'Community',
      subtitle: 'Stories and experiences from sponsors and leaders',
      onTap: () => widget.onNavigate(2),
    ));

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 32, 20, 20 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ── Greeting ──────────────────────────────────────────────────────
            Text(
              _greeting,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.1,
              ),
            ),
            Text(
              '${user.alias}.',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            if (user.addictionType != null) ...[
              const SizedBox(height: 6),
              Text(
                '${user.addictionType} recovery',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],

            // ── Check-in strip ────────────────────────────────────────────────
            if (isRegistered) ...[
              const SizedBox(height: 24),
              _CheckInStrip(
                loading: _loadingCheckIn,
                checkedIn: _todayCheckIn != null,
                onTap: _goCheckIn,
              ),
            ],

            // ── Crisis panel ──────────────────────────────────────────────────
            if (isRegistered) ...[
              const SizedBox(height: 16),
              _activeAlert != null
                  ? _ActiveCrisisCard(
                      alert: _activeAlert!,
                      loading: _crisisLoading,
                      onCancel: _cancelCrisis,
                    )
                  : _PanicButton(
                      loading: _crisisLoading,
                      onTap: _triggerCrisis,
                    ),
            ],

            // ── Engage ────────────────────────────────────────────────────────
            if (engage.isNotEmpty) ...[
              const SizedBox(height: 28),
              _SectionLabel(label: 'Engage'),
              const SizedBox(height: 10),
              ...engage,
            ],

            // ── Explore ───────────────────────────────────────────────────────
            if (explore.isNotEmpty) ...[
              const SizedBox(height: 20),
              _SectionLabel(label: 'Explore'),
              const SizedBox(height: 10),
              ...explore,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Panic button ───────────────────────────────────────────────────────────────

class _PanicButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onTap;

  const _PanicButton({required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Material(
      color: errorColor.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: loading ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: errorColor,
                        ),
                      )
                    : Icon(Icons.emergency_outlined, size: 20, color: errorColor),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Need help right now?',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: errorColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Reach out to your sponsor and group.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: errorColor.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: errorColor.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Active crisis card ─────────────────────────────────────────────────────────

class _ActiveCrisisCard extends StatelessWidget {
  final CrisisAlert alert;
  final bool loading;
  final VoidCallback onCancel;

  const _ActiveCrisisCard({
    required this.alert,
    required this.loading,
    required this.onCancel,
  });

  String get _stageLabel {
    switch (alert.stage) {
      case 1:
        return 'Your sponsor has been notified.';
      case 2:
        return 'Group sponsors have been notified.';
      case 3:
        return 'Your full group has been notified.';
      default:
        return 'Alert active.';
    }
  }

  String get _nextStepLabel {
    switch (alert.stage) {
      case 1:
        return 'Group sponsors will be contacted in 5 minutes if no one responds.';
      case 2:
        return 'The wider community will be contacted in 5 minutes if no one responds.';
      case 3:
        return 'Waiting for someone to respond.';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final errorColor = theme.colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: errorColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, size: 18, color: errorColor),
              const SizedBox(width: 8),
              Text(
                'Alert active',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: errorColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: errorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Stage ${alert.stage} of 3',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: errorColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _stageLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _nextStepLabel,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: loading ? null : onCancel,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: errorColor.withValues(alpha: 0.4)),
              ),
              child: Text(
                "I'm okay — cancel alert",
                style: TextStyle(color: errorColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Check-in strip ─────────────────────────────────────────────────────────────

class _CheckInStrip extends StatelessWidget {
  final bool loading;
  final bool checkedIn;
  final VoidCallback onTap;

  const _CheckInStrip({
    required this.loading,
    required this.checkedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bg = checkedIn ? cs.surfaceContainerLow : cs.primary;
    final fg = checkedIn ? cs.onSurface : cs.onPrimary;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: checkedIn ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              if (loading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: fg,
                  ),
                )
              else
                Icon(
                  checkedIn
                      ? Icons.check_circle_rounded
                      : Icons.today_outlined,
                  size: 20,
                  color: fg,
                ),
              const SizedBox(width: 12),
              Text(
                checkedIn ? 'Checked in today' : 'Check in for today',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
              if (!checkedIn && !loading) ...[
                const Spacer(),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 13,
                  color: fg.withValues(alpha: 0.7),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
    );
  }
}
