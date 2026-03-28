import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../services/local_storage_service.dart';
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
        child: Padding(
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
              Center(
                child: Container(
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
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              if (user.rank == 'anonymous')
                FilledButton(
                  onPressed: () => _rankUp(context),
                  child: const Text('Rank up to Apprentice'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
