import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';
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
    'apprentice': 'You\'re on your journey. You can post, connect with a sponsor, and join a group.',
    'sponsor': 'You\'re guiding others in their recovery.',
    'leader': 'You lead a small group and help set the pace.',
    'influencer': 'You share your story to reduce stigma and inspire others.',
    'graduated': 'You\'ve marked your recovery. You can stay on to support others.',
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
    final label = _rankLabels[user.rank] ?? user.rank;
    final description = _rankDescriptions[user.rank] ?? '';

    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              const Icon(Icons.account_circle, size: 80),
              const SizedBox(height: 16),
              Text(
                user.alias,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              if (user.location != null && user.location!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 14,
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      user.location!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  if (user.isLeader)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Group Leader',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              if (user.isRegistered) ...[
                const SizedBox(height: 24),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.history),
                  title: const Text('Past check-ins'),
                  subtitle: const Text('Review your daily check-in entries'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CheckInHistoryScreen(userId: user.userId!),
                    ),
                  ),
                ),
                const Divider(),
              ],
              const SizedBox(height: 24),
              if (user.rank == 'anonymous')
                FilledButton(
                  onPressed: () => _rankUp(context),
                  child: const Text('Rank up to Apprentice'),
                ),
              if (kDebugMode) ...[
                const SizedBox(height: 24),
                _DebugUserSwitcher(onSwitch: onRankedUp),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugUserSwitcher extends StatefulWidget {
  final void Function(LocalUser) onSwitch;
  const _DebugUserSwitcher({required this.onSwitch});

  @override
  State<_DebugUserSwitcher> createState() => _DebugUserSwitcherState();
}

class _DebugUserSwitcherState extends State<_DebugUserSwitcher> {
  static const _seedUsers = [
    (alias: 'Alice',  phone: '+44700000001'),
    (alias: 'Bob',    phone: '+44700000002'),
    (alias: 'Marcus', phone: '+44700000005'),
    (alias: 'Carol',  phone: '+44700000003'),
    (alias: 'Dan',    phone: '+44700000004'),
    (alias: 'Sophie', phone: '+44700000006'),
    (alias: 'Eve',    phone: '+1200000001'),
    (alias: 'Frank',  phone: '+1200000002'),
    (alias: 'Grace',  phone: '+1200000003'),
    (alias: 'Henry',  phone: '+44161000001'),
    (alias: 'Isla',   phone: '+44161000002'),
  ];

  String? _loading;

  Future<void> _loginAs(String alias, String phone) async {
    setState(() => _loading = alias);
    try {
      final apiUser = await AuthService().login(phone, 'password');
      final localUser = await LocalStorageService().saveRegistration(
        apiUser.id, apiUser.alias,
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
      if (mounted) setState(() => _loading = null);
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
                      width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(u.alias),
              onPressed: _loading != null ? null : () => _loginAs(u.alias, u.phone),
            );
          }).toList(),
        ),
      ],
    );
  }
}
