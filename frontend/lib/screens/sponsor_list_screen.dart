import 'package:flutter/material.dart';
import '../models/group_member.dart';
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Request sent to ${sponsor.alias}. Waiting for their acceptance.',
            ),
          ),
        );
        Navigator.pop(context, null);
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
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Could not load sponsors.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ),
            );
          }

          final sponsors = snapshot.data ?? [];

          return ListView(
            padding: EdgeInsets.fromLTRB(
              20, 0, 20, 24 + MediaQuery.of(context).padding.bottom,
            ),
            children: [
              Text(
                'Available Sponsors',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Sponsors are experienced members who have opted in to offer guidance. '
                'Selecting one sends them a notification — there\'s no pressure on either side.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              if (sponsors.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Text(
                    'No sponsors are currently available in your group. Check back later.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                )
              else
                ...sponsors.map((s) {
                  final isLoading = _requesting == s.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.volunteer_activism_outlined,
                              color: cs.onSurfaceVariant,
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                s.alias,
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (isLoading)
                              const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2),
                              )
                            else
                              FilledButton.tonal(
                                onPressed: _requesting != null
                                    ? null
                                    : () => _request(s),
                                child: const Text('Select'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
            ],
          );
        },
      ),
    );
  }
}
