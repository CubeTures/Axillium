import 'package:flutter/material.dart';
import '../models/group_member.dart';
import '../services/local_storage_service.dart';
import '../services/sponsor_service.dart';

class SponsorListScreen extends StatefulWidget {
  final int groupId;
  final int userId;

  const SponsorListScreen({
    super.key,
    required this.groupId,
    required this.userId,
  });

  @override
  State<SponsorListScreen> createState() => _SponsorListScreenState();
}

class _SponsorListScreenState extends State<SponsorListScreen> {
  late Future<List<GroupMember>> _future;
  int? _requesting;

  @override
  void initState() {
    super.initState();
    _future = SponsorService().getAvailableSponsors(widget.groupId);
  }

  Future<void> _request(GroupMember sponsor) async {
    setState(() => _requesting = sponsor.id);
    try {
      await SponsorService().requestSponsor(widget.userId, sponsor.id);
      await LocalStorageService().saveSponsorId(sponsor.id);
      if (mounted) {
        Navigator.pop(context, sponsor.id);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
        setState(() => _requesting = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Available Sponsors')),
      body: FutureBuilder<List<GroupMember>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Could not load sponsors: ${snapshot.error}'));
          }
          final sponsors = snapshot.data ?? [];
          if (sponsors.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'No sponsors are currently available in your group. Check back later.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Sponsors are experienced members who have opted in to offer guidance. '
                  'Selecting one sends them a notification — there\'s no pressure on either side.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              const Divider(),
              Expanded(
                child: ListView.separated(
                  itemCount: sponsors.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = sponsors[index];
                    final isLoading = _requesting == s.id;
                    return ListTile(
                      leading: const Icon(Icons.volunteer_activism_outlined),
                      title: Text(s.alias),
                      trailing: isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : FilledButton.tonal(
                              onPressed: _requesting != null ? null : () => _request(s),
                              child: const Text('Select'),
                            ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
