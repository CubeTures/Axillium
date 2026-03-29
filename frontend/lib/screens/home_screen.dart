import 'package:flutter/material.dart';
import '../models/check_in.dart';
import '../models/local_user.dart';
import '../screens/check_in_screen.dart';
import '../screens/sponsor_list_screen.dart';
import '../services/check_in_service.dart';
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

  @override
  void initState() {
    super.initState();
    _fetchCheckIn();
  }

  @override
  void didUpdateWidget(HomeScreen old) {
    super.didUpdateWidget(old);
    if (old.user.userId != widget.user.userId) _fetchCheckIn();
  }

  Future<void> _fetchCheckIn() async {
    if (!widget.user.isRegistered) return;
    setState(() { _loadingCheckIn = true; _todayCheckIn = null; });
    try {
      final ci = await CheckInService().getTodayCheckIn(widget.user.userId!);
      if (mounted) setState(() => _todayCheckIn = ci);
    } catch (_) {
      // silently degrade — button still shows, status just unknown
    } finally {
      if (mounted) setState(() => _loadingCheckIn = false);
    }
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
        subtitle: 'Create an account to post, connect with a sponsor, and join a group.',
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
