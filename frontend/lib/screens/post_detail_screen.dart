import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../models/post.dart';

class PostDetailScreen extends StatelessWidget {
  final Post post;
  final LocalUser localUser;

  const PostDetailScreen({
    super.key,
    required this.post,
    required this.localUser,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (post.addictionType.isNotEmpty)
              Text(
                post.addictionType.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            const SizedBox(height: 12),
            Text(
              post.title,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16),
                const SizedBox(width: 6),
                Text(post.authorAlias, style: theme.textTheme.bodySmall),
                const SizedBox(width: 16),
                const Icon(Icons.calendar_today_outlined, size: 14),
                const SizedBox(width: 6),
                Text(_formatDate(post.createdAt),
                    style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 24),
            Text(
              post.content,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.7),
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
