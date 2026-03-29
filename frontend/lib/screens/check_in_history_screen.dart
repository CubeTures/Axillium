import 'package:flutter/material.dart';
import '../models/check_in.dart';
import '../services/check_in_service.dart';

class CheckInHistoryScreen extends StatefulWidget {
  final int userId;

  const CheckInHistoryScreen({super.key, required this.userId});

  @override
  State<CheckInHistoryScreen> createState() => _CheckInHistoryScreenState();
}

class _CheckInHistoryScreenState extends State<CheckInHistoryScreen> {
  late Future<List<CheckIn>> _future;

  @override
  void initState() {
    super.initState();
    _future = CheckInService().getHistory(widget.userId);
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
        title: const Text(
          'Check-in History',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<CheckIn>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Could not load history.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }
          final entries = snapshot.data!;
          if (entries.isEmpty) {
            return Center(
              child: Text(
                'No check-ins yet.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.fromLTRB(
              20, 12, 20, 24 + MediaQuery.of(context).padding.bottom,
            ),
            itemCount: entries.length,
            itemBuilder: (context, i) => _CheckInTile(entry: entries[i]),
          );
        },
      ),
    );
  }
}

class _CheckInTile extends StatefulWidget {
  final CheckIn entry;
  const _CheckInTile({required this.entry});

  @override
  State<_CheckInTile> createState() => _CheckInTileState();
}

class _CheckInTileState extends State<_CheckInTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final e = widget.entry;
    final date = e.createdAt.toLocal();
    final dateLabel = '${date.day}/${date.month}/${date.year}';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: e.reflection.isNotEmpty
              ? () => setState(() => _expanded = !_expanded)
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(e.moodEmoji,
                        style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            dateLabel,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            e.moodLabel,
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                    if (e.relapsed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: cs.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Relapse logged',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: cs.onErrorContainer,
                          ),
                        ),
                      ),
                    if (e.reflection.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Icon(
                        _expanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ],
                ),
                if (_expanded && e.reflection.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    e.reflection,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
