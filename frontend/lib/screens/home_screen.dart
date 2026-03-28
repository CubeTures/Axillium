import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../widgets/anonymous_home.dart';
import '../widgets/apprentice_home.dart';

class HomeScreen extends StatelessWidget {
  final LocalUser user;
  final void Function(int tabIndex) onNavigate;
  final void Function(LocalUser)? onUserUpdated;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNavigate,
    this.onUserUpdated,
  });

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  List<Widget> _cardsForRank(BuildContext context) {
    switch (user.rank) {
      case 'apprentice':
      case 'sponsor':
      case 'leader':
      case 'influencer':
      case 'graduated':
        return apprenticeHomeCards(
          user: user,
          onNavigate: onNavigate,
          context: context,
          onUserUpdated: onUserUpdated,
        );
      default:
        return anonymousHomeCards(onNavigate: onNavigate);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const SizedBox(height: 8),
            Text(
              '$_greeting, ${user.alias}.',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (user.addictionType != null) ...[
              const SizedBox(height: 4),
              Text(
                user.addictionType!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
            const SizedBox(height: 20),
            ..._cardsForRank(context),
          ],
        ),
      ),
    );
  }
}
