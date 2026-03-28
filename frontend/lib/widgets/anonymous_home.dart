import 'package:flutter/material.dart';
import 'home_card.dart';

List<Widget> anonymousHomeCards({
  required void Function(int tabIndex) onNavigate,
}) {
  return [
    HomeCard(
      icon: Icons.chat_bubble_outline,
      title: 'Read the conversations',
      body: 'People in your area are sharing their experiences. '
          'You can read everything — no account needed.',
      actionLabel: 'Open chat',
      onAction: () => onNavigate(1),
    ),
    HomeCard(
      icon: Icons.article_outlined,
      title: 'Read community posts',
      body: 'Sponsors, leaders, and people further along in their recovery '
          'share longer stories here. It helps to know it\'s possible.',
      actionLabel: 'Open community',
      onAction: () => onNavigate(2),
    ),
    HomeCard(
      icon: Icons.lock_open_outlined,
      title: 'Ready to take part?',
      body: 'When you\'re ready, creating an account lets you post in the chat, '
          'connect with a sponsor, and join a group. '
          'There\'s no pressure — come back whenever it feels right.',
      actionLabel: 'Create account',
      onAction: () => onNavigate(3),
    ),
  ];
}
