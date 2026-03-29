import 'package:flutter/material.dart';
import '../models/app_notification.dart';
import '../models/local_user.dart';
import '../services/crisis_service.dart';
import '../services/notification_service.dart';
import '../services/sponsor_service.dart';

class NotificationsScreen extends StatefulWidget {
  final LocalUser user;

  const NotificationsScreen({super.key, required this.user});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  List<AppNotification> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.user.userId == null) {
      setState(() => _loading = false);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _service.getNotifications(widget.user.userId!);
      if (mounted) setState(() => _notifications = items);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load notifications.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _dismiss(AppNotification n) async {
    await _service.markRead(widget.user.userId!, n.id);
    if (mounted) setState(() => _notifications.remove(n));
  }

  Future<void> _acceptSponsorRequest(AppNotification n) async {
    try {
      await SponsorService().acceptRequest(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You are now ${n.senderAlias}\'s sponsor.')),
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

  Future<void> _declineSponsorRequest(AppNotification n) async {
    try {
      await SponsorService().declineRequest(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request from ${n.senderAlias} declined.')),
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

  Future<void> _approveBecomeSponsors(AppNotification n) async {
    try {
      await SponsorService().approveBecomeSponsors(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${n.senderAlias} is now a sponsor.')),
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

  Future<void> _denyBecomeSponsors(AppNotification n) async {
    try {
      await SponsorService().denyBecomeSponsors(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Request from ${n.senderAlias} declined.')),
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

  Future<void> _respondToCrisis(AppNotification n) async {
    if (widget.user.userId == null) return;
    try {
      await CrisisService().respond(
        crisisUserId: n.senderId,
        responderId: widget.user.userId!,
        responderAlias: widget.user.alias,
      );
      await _service.markRead(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('${n.senderAlias} has been notified you\'re on your way.')),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Notifications',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Updates from your group and sponsors.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh_outlined),
                    tooltip: 'Refresh',
                    onPressed: _loading ? null : _load,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // ── Body ─────────────────────────────────────────────────────────
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (widget.user.userId == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'Register to receive notifications.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    if (_notifications.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 4, 20, 20 + MediaQuery.of(context).padding.bottom),
          children: [
            const SizedBox(height: 80),
            Center(
              child: Text(
                'No new notifications.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(
          20, 4, 20, 20 + MediaQuery.of(context).padding.bottom,
        ),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final n = _notifications[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Dismissible(
              key: ValueKey(n.id),
              direction: DismissDirection.endToStart,
              onDismissed: (_) => _dismiss(n),
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
              child: _NotificationTile(
                notification: n,
                onAccept: _acceptSponsorRequest,
                onDecline: _declineSponsorRequest,
                onCrisisRespond: _respondToCrisis,
                onApproveBecomeSponsors: _approveBecomeSponsors,
                onDenyBecomeSponsors: _denyBecomeSponsors,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final Future<void> Function(AppNotification) onAccept;
  final Future<void> Function(AppNotification) onDecline;
  final Future<void> Function(AppNotification) onCrisisRespond;
  final Future<void> Function(AppNotification) onApproveBecomeSponsors;
  final Future<void> Function(AppNotification) onDenyBecomeSponsors;

  const _NotificationTile({
    required this.notification,
    required this.onAccept,
    required this.onDecline,
    required this.onCrisisRespond,
    required this.onApproveBecomeSponsors,
    required this.onDenyBecomeSponsors,
  });

  IconData get _icon {
    switch (notification.type) {
      case 'sponsor_request':
        return Icons.volunteer_activism_outlined;
      case 'sponsor_accepted':
        return Icons.handshake_outlined;
      case 'relapse_alert':
      case 'risk_alert':
        return Icons.warning_amber_outlined;
      case 'crisis_alert':
        return Icons.emergency_outlined;
      case 'crisis_responded':
        return Icons.favorite_outlined;
      case 'become_sponsor_request':
        return Icons.star_outline;
      case 'become_sponsor_approved':
        return Icons.star_rounded;
      case 'become_sponsor_denied':
        return Icons.star_border_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(ColorScheme cs) {
    switch (notification.type) {
      case 'relapse_alert':
      case 'risk_alert':
      case 'crisis_alert':
        return cs.error;
      case 'crisis_responded':
      case 'sponsor_accepted':
      case 'become_sponsor_approved':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final isSponsorRequest = notification.type == 'sponsor_request';
    final isCrisisAlert = notification.type == 'crisis_alert';
    final isBecomeSponsorRequest = notification.type == 'become_sponsor_request';

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(_icon, color: _iconColor(cs), size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.message,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatDate(notification.createdAt),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (isSponsorRequest) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () => onAccept(notification),
                          child: const Text('Accept'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => onDecline(notification),
                          child: const Text('Decline'),
                        ),
                      ],
                    ),
                  ],
                  if (isCrisisAlert) ...[
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      icon: const Icon(Icons.favorite_outlined, size: 16),
                      label: const Text("I'm here"),
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                      ),
                      onPressed: () => onCrisisRespond(notification),
                    ),
                  ],
                  if (isBecomeSponsorRequest) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        FilledButton.tonal(
                          onPressed: () => onApproveBecomeSponsors(notification),
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: () => onDenyBecomeSponsors(notification),
                          child: const Text('Deny'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
