import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/group_member.dart';
import '../models/local_user.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
import '../services/sponsor_service.dart';
import 'check_in_history_screen.dart';
import 'register_screen.dart';

class ProfileScreen extends StatelessWidget {
  final LocalUser user;
  final void Function(LocalUser updated) onRankedUp;
  final VoidCallback onLogout;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onRankedUp,
    required this.onLogout,
  });

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

  Future<void> _rankUp(BuildContext context) async {
    final result = await Navigator.push<LocalUser>(
      context,
      MaterialPageRoute(
        builder: (_) => RegisterScreen(currentAlias: user.alias),
      ),
    );
    if (result != null) onRankedUp(result);
  }

  Future<void> _confirmLogout(BuildContext context) async {
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
      onLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
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
                    onPressed: () => _confirmLogout(context),
                  ),
                ],
              ),

              // ── Avatar ───────────────────────────────────────────────────
              Center(
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    user.alias.isNotEmpty
                        ? user.alias[0].toUpperCase()
                        : '?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
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
                ],
              ),
              const SizedBox(height: 10),
              Text(
                description,
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),

              // ── Registered sections ──────────────────────────────────────
              if (user.isRegistered) ...[
                const SizedBox(height: 28),
                _SponsorStatusSection(
                  key: ValueKey('sponsor_${user.userId}'),
                  user: user,
                  onUserUpdated: onRankedUp,
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
                  onPressed: () => _rankUp(context),
                  child: const Text('Register as Apprentice'),
                ),
              ],

              // ── Debug switcher ───────────────────────────────────────────
              if (kDebugMode) ...[
                const SizedBox(height: 28),
                _DebugUserSwitcher(onSwitch: onRankedUp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Badge ──────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  final Color textColor;

  const _Badge({
    required this.label,
    required this.color,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 13,
        ),
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
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
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
      final member = await SponsorService().getUserBasic(widget.user.sponsorId!);
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
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
                onPressed:
                    _confirmedAlias != null ? _removeConfirmed : _rescindPending,
                style: TextButton.styleFrom(foregroundColor: cs.error),
                child: Text(_confirmedAlias != null ? 'Remove' : 'Rescind'),
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
      await SponsorService().removeApprentice(
          widget.user.userId!, apprentice.id);
      if (mounted) setState(() => _apprentices.remove(apprentice));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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
              onPressed: _loading != null
                  ? null
                  : () => _loginAs(u.alias, u.phone),
            );
          }).toList(),
        ),
      ],
    );
  }
}
