import 'package:flutter/material.dart';
import '../models/group_member.dart';
import '../services/chat_service.dart';
import '../widgets/section_label.dart';

class MembersScreen extends StatefulWidget {
  final int groupId;

  const MembersScreen({super.key, required this.groupId});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  late Future<List<GroupMember>> _future;

  @override
  void initState() {
    super.initState();
    _future = ChatService().getGroupMembers(widget.groupId);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: FutureBuilder<List<GroupMember>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load members.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }

          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return Center(
              child: Text(
                'No members found.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }

          final leaders =
              members.where((m) => m.role == 'leader').toList();
          final sponsors =
              members.where((m) => m.role == 'sponsor').toList();
          final others = members
              .where((m) => m.role != 'leader' && m.role != 'sponsor')
              .toList();

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20, 0, 20, 24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Text(
                'Group Members',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              if (leaders.isNotEmpty) ...[
                const SectionLabel(label: 'Leader'),
                const SizedBox(height: 8),
                ...leaders.map((m) => _MemberCard(member: m)),
                const SizedBox(height: 8),
              ],
              if (sponsors.isNotEmpty) ...[
                const SectionLabel(label: 'Sponsors'),
                const SizedBox(height: 8),
                ...sponsors.map((m) => _MemberCard(member: m)),
                const SizedBox(height: 8),
              ],
              if (others.isNotEmpty) ...[
                SectionLabel(
                  label: 'Members (${others.length})',
                ),
                const SizedBox(height: 8),
                ...others.map((m) => _MemberCard(member: m)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MemberCard extends StatelessWidget {
  final GroupMember member;

  const _MemberCard({required this.member});

  IconData get _icon {
    switch (member.role) {
      case 'leader':
        return Icons.star_outline;
      case 'sponsor':
        return Icons.volunteer_activism_outlined;
      default:
        return Icons.person_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
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
              Icon(_icon, color: cs.onSurfaceVariant, size: 22),
              const SizedBox(width: 12),
              Text(
                member.alias,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
