import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../services/local_storage_service.dart';
import 'register_screen.dart';

class ProfileScreen extends StatelessWidget {
  final LocalUser user;
  final void Function(LocalUser updated) onRankedUp;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onRankedUp,
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

  @override
  Widget build(BuildContext context) {
    final label = _rankLabels[user.rank] ?? user.rank;
    final description = _rankDescriptions[user.rank] ?? '';

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Icon(Icons.account_circle, size: 80),
              const SizedBox(height: 16),
              Text(
                user.alias,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              if (user.rank == 'anonymous')
                FilledButton(
                  onPressed: () => _rankUp(context),
                  child: const Text('Rank up to Apprentice'),
                ),
              const SizedBox(height: 32),
              _DebugAccountSwitcher(current: user, onChanged: onRankedUp),
            ],
          ),
        ),
      ),
    );
  }
}

class _DebugAccountSwitcher extends StatelessWidget {
  final LocalUser current;
  final void Function(LocalUser) onChanged;

  const _DebugAccountSwitcher({required this.current, required this.onChanged});

  static final _accounts = [
    LocalUser(alias: 'Alex', rank: 'apprentice', userId: 101, groupId: 1),
    LocalUser(alias: 'Morgan', rank: 'sponsor', userId: 102, groupId: 1),
    LocalUser(alias: 'Jordan', rank: 'leader', userId: 103, groupId: 1),
    LocalUser(alias: 'Casey', rank: 'influencer', userId: 104, groupId: 1),
    LocalUser(alias: 'Riley', rank: 'graduated', userId: 105, groupId: 1),
    LocalUser(alias: 'Anonymous', rank: 'anonymous', userId: null, groupId: null),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'DEBUG — Account Switcher',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.orange,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          ..._accounts.map((account) {
            final active = current.userId == account.userId &&
                current.rank == account.rank;
            return GestureDetector(
              onTap: active
                  ? null
                  : () async {
                      final updated = await LocalStorageService()
                          .debugSwitchAccount(account);
                      onChanged(updated);
                    },
              child: Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: active ? Colors.orange : Colors.white,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Text(
                      account.alias,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: active ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: active
                            ? Colors.white.withOpacity(0.3)
                            : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        account.rank,
                        style: TextStyle(
                          fontSize: 11,
                          color: active ? Colors.white : Colors.orange.shade800,
                        ),
                      ),
                    ),
                    if (account.userId != null) ...[
                      const Spacer(),
                      Text(
                        'id:${account.userId}',
                        style: TextStyle(
                          fontSize: 10,
                          color: active
                              ? Colors.white70
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
