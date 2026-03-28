import 'package:flutter/material.dart';
import '../models/group_member.dart';
import '../services/chat_service.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('Group Members')),
      body: FutureBuilder<List<GroupMember>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load members: ${snapshot.error}'));
          }
          final members = snapshot.data ?? [];
          if (members.isEmpty) {
            return const Center(child: Text('No members found.'));
          }

          final leaders = members.where((m) => m.role == 'leader').toList();
          final sponsors = members.where((m) => m.role == 'sponsor').toList();
          final others = members
              .where((m) => m.role != 'leader' && m.role != 'sponsor')
              .toList();

          return ListView(
            children: [
              if (leaders.isNotEmpty) ...[
                _SectionHeader(title: 'Leader', count: leaders.length),
                for (final m in leaders) _MemberTile(member: m),
              ],
              if (sponsors.isNotEmpty) ...[
                _SectionHeader(title: 'Sponsors', count: sponsors.length),
                for (final m in sponsors) _MemberTile(member: m),
              ],
              if (others.isNotEmpty) ...[
                _SectionHeader(title: 'Members', count: others.length),
                for (final m in others) _MemberTile(member: m),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
          const SizedBox(width: 6),
          Text(
            '($count)',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  final GroupMember member;

  const _MemberTile({required this.member});

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
    return ListTile(
      leading: Icon(_icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
      title: Text(member.alias),
    );
  }
}
