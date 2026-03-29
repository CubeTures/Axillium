import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../screens/check_in_screen.dart';
import '../screens/sponsor_list_screen.dart';
import 'home_card.dart';

List<Widget> apprenticeHomeCards({
  required LocalUser user,
  required void Function(int tabIndex) onNavigate,
  required BuildContext context,
  void Function(LocalUser)? onUserUpdated,
}) {
  return [
    HomeCard(
      icon: Icons.check_circle_outline,
      title: 'Daily check-in',
      body: 'Taking a moment each day to reflect on how you\'re doing '
          'helps you and your sponsor track your progress over time.',
      actionLabel: 'Start check-in',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => CheckInScreen(
            userId: user.userId!,
            alias: user.alias,
            groupId: user.groupId,
          ),
        ),
      ),
      accentColor: Colors.green,
    ),
    // Sponsor card: shown when user has no sponsor yet.
    if (user.sponsorId == null && user.groupId != null)
      HomeCard(
        icon: Icons.handshake_outlined,
        title: 'Find a sponsor',
        body: 'A sponsor is an experienced member who has opted in to offer '
            'guidance. They\'re not here to judge — just to walk alongside you.',
        actionLabel: 'Browse sponsors',
        onAction: () async {
          final sponsorId = await Navigator.push<int>(
            context,
            MaterialPageRoute(
              builder: (_) => SponsorListScreen(
                groupId: user.groupId!,
                userId: user.userId!,
              ),
            ),
          );
          if (sponsorId != null && onUserUpdated != null) {
            onUserUpdated(user.copyWith(sponsorId: sponsorId));
          }
        },
      ),
    HomeCard(
      icon: Icons.chat_bubble_outline,
      title: 'Your group chat',
      body: user.addictionType != null
          ? 'Stay connected with your ${user.addictionType} recovery group. '
              'Your sponsor and group leader can see when you\'re active.'
          : 'Stay connected with your recovery group. '
              'Your sponsor and group leader can see when you\'re active.',
      actionLabel: 'Open chat',
      onAction: () => onNavigate(1),
    ),
    HomeCard(
      icon: Icons.people_outline,
      title: 'Community',
      body: 'Read posts from sponsors and leaders. '
          'Their experiences can help you navigate your own journey.',
      actionLabel: 'Open community',
      onAction: () => onNavigate(2),
    ),
  ];
}
