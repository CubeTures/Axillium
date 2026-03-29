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
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
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
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
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
      // Mark the notification read and remove it from the list
      await _service.markRead(widget.user.userId!, n.id);
      if (mounted) {
        setState(() => _notifications.remove(n));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${n.senderAlias} has been notified you\'re on your way.')),
        );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
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
      return Center(
        child: Text(
          'No new notifications.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: EdgeInsets.only(
            top: 8, bottom: 8 + MediaQuery.of(context).padding.bottom),
        itemCount: _notifications.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) => _NotificationTile(
          notification: _notifications[index],
          onDismiss: _dismiss,
          onAccept: _acceptSponsorRequest,
          onDecline: _declineSponsorRequest,
          onCrisisRespond: _respondToCrisis,
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final Future<void> Function(AppNotification) onDismiss;
  final Future<void> Function(AppNotification) onAccept;
  final Future<void> Function(AppNotification) onDecline;
  final Future<void> Function(AppNotification) onCrisisRespond;

  const _NotificationTile({
    required this.notification,
    required this.onDismiss,
    required this.onAccept,
    required this.onDecline,
    required this.onCrisisRespond,
  });

  IconData get _icon {
    switch (notification.type) {
      case 'sponsor_request':
        return Icons.volunteer_activism_outlined;
      case 'sponsor_accepted':
        return Icons.handshake_outlined;
      case 'relapse_alert':
        return Icons.warning_amber_outlined;
      case 'crisis_alert':
        return Icons.emergency_outlined;
      case 'crisis_responded':
        return Icons.favorite_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color _iconColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (notification.type) {
      case 'relapse_alert':
      case 'crisis_alert':
        return cs.error;
      case 'crisis_responded':
      case 'sponsor_accepted':
        return cs.primary;
      default:
        return cs.onSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSponsorRequest = notification.type == 'sponsor_request';
    final isCrisisAlert = notification.type == 'crisis_alert';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: _iconColor(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(notification.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant,
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
                      backgroundColor:
                          Theme.of(context).colorScheme.error,
                      foregroundColor:
                          Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () => onCrisisRespond(notification),
                  ),
                ],
              ],
            ),
          ),
          if (!isSponsorRequest && !isCrisisAlert)
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              tooltip: 'Dismiss',
              onPressed: () => onDismiss(notification),
            ),
        ],
      ),
    );
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
}
