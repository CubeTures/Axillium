import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../models/meeting.dart';
import '../services/meeting_service.dart';
import '../widgets/section_label.dart';

const _canOrganize = {'sponsor', 'leader', 'influencer'};

class MeetingsScreen extends StatefulWidget {
  final LocalUser user;
  final int groupId;

  const MeetingsScreen({
    super.key,
    required this.user,
    required this.groupId,
  });

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  final _service = MeetingService();
  List<Meeting> _meetings = [];
  bool _loading = true;

  List<Meeting> get _upcoming {
    final now = DateTime.now();
    return _meetings.where((m) => m.scheduledAt.isAfter(now)).toList();
  }

  List<Meeting> get _past {
    final now = DateTime.now();
    return _meetings
        .where((m) => !m.scheduledAt.isAfter(now))
        .toList()
        .reversed
        .toList(); // most recent past first
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final meetings = await _service.getMeetings(widget.groupId);
      setState(() => _meetings = meetings);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load meetings: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _addAndSort(Meeting meeting) {
    setState(() {
      _meetings.add(meeting);
      _meetings.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    });
  }

  Future<void> _confirmDelete(Meeting meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel meeting?'),
        content: Text('Are you sure you want to cancel "${meeting.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancel meeting'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteMeeting(
        groupId: widget.groupId,
        meetingId: meeting.id,
        userId: widget.user.userId!,
        role: widget.user.rank,
      );
      setState(() => _meetings.remove(meeting));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  void _openScheduleSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ScheduleMeetingSheet(
        user: widget.user,
        groupId: widget.groupId,
        service: _service,
        onCreated: _addAndSort,
      ),
    );
  }

  Widget _buildBody(BuildContext context, bool canOrganize) {
    final upcoming = _upcoming;
    final past = _past;

    if (upcoming.isEmpty && past.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 40, 32, 32),
          child: Text(
            canOrganize
                ? 'No meetings scheduled yet. Tap + to add one.'
                : 'No meetings scheduled yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final items = <Widget>[];

    if (upcoming.isNotEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.only(bottom: 10, top: 8),
        child: SectionLabel(label: 'Upcoming'),
      ));
      for (final m in upcoming) {
        items.add(_MeetingCard(
          meeting: m,
          canOrganize: canOrganize,
          onDelete: () => _confirmDelete(m),
        ));
      }
    }

    if (past.isNotEmpty) {
      items.add(const Padding(
        padding: EdgeInsets.only(bottom: 10, top: 8),
        child: SectionLabel(label: 'Past'),
      ));
      for (final m in past) {
        items.add(_MeetingCard(
          meeting: m,
          canOrganize: false, // past meetings can't be deleted
          onDelete: () {},
        ));
      }
    }

    return ListView(
      padding: EdgeInsets.fromLTRB(
        20, 16, 20, 20 + MediaQuery.of(context).padding.bottom + 132,
      ),
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    final canOrganize = _canOrganize.contains(widget.user.rank);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
        title: const Text(
          'Meetings',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context, canOrganize),
      floatingActionButton: canOrganize
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: FloatingActionButton(
                onPressed: _openScheduleSheet,
                tooltip: 'Schedule meeting',
                child: const Icon(Icons.add),
              ),
            )
          : null,
    );
  }
}

// ── Meeting card ──────────────────────────────────────────────────────────────

class _MeetingCard extends StatelessWidget {
  final Meeting meeting;
  final bool canOrganize;
  final VoidCallback onDelete;

  const _MeetingCard({
    required this.meeting,
    required this.canOrganize,
    required this.onDelete,
  });

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dt.year, dt.month, dt.day);
    final diff = date.difference(today).inDays;

    final timeStr = _formatTime(dt);
    if (diff == 0) return 'Today at $timeStr';
    if (diff == 1) return 'Tomorrow at $timeStr';
    if (diff < 7) return '${_weekday(dt.weekday)} at $timeStr';
    return '${_month(dt.month)} ${dt.day} at $timeStr';
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _weekday(int w) =>
      ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];

  String _month(int m) => [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      meeting.title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (canOrganize)
                    IconButton(
                      icon: Icon(Icons.delete_outline, size: 20, color: cs.error),
                      tooltip: 'Cancel meeting',
                      visualDensity: VisualDensity.compact,
                      onPressed: onDelete,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              _InfoRow(
                icon: Icons.schedule_outlined,
                text: _formatDate(meeting.scheduledAt),
              ),
              const SizedBox(height: 4),
              _InfoRow(
                icon: Icons.location_on_outlined,
                text: meeting.location,
              ),
              if (meeting.note.isNotEmpty) ...[
                const SizedBox(height: 4),
                _InfoRow(
                  icon: Icons.notes_outlined,
                  text: meeting.note,
                  muted: true,
                ),
              ],
              const SizedBox(height: 10),
              Text(
                'Scheduled by ${meeting.createdByAlias}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool muted;

  const _InfoRow({required this.icon, required this.text, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final color = muted
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
        ),
      ],
    );
  }
}

// ── Schedule meeting bottom sheet ─────────────────────────────────────────────

class _ScheduleMeetingSheet extends StatefulWidget {
  final LocalUser user;
  final int groupId;
  final MeetingService service;
  final void Function(Meeting) onCreated;

  const _ScheduleMeetingSheet({
    required this.user,
    required this.groupId,
    required this.service,
    required this.onCreated,
  });

  @override
  State<_ScheduleMeetingSheet> createState() => _ScheduleMeetingSheetState();
}

class _ScheduleMeetingSheetState extends State<_ScheduleMeetingSheet> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _submitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  String get _dateLabel {
    if (_selectedDate == null) return 'Pick a date';
    final d = _selectedDate!;
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String get _timeLabel {
    if (_selectedTime == null) return 'Pick a time';
    final t = _selectedTime!;
    final hour = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final location = _locationController.text.trim();
    final note = _noteController.text.trim();

    if (title.isEmpty || location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and location are required.')),
      );
      return;
    }
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please pick a date and time.')),
      );
      return;
    }

    final scheduledAt = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    setState(() => _submitting = true);
    try {
      final meeting = await widget.service.createMeeting(
        groupId: widget.groupId,
        createdById: widget.user.userId!,
        createdByAlias: widget.user.alias,
        createdByRole: widget.user.rank,
        title: title,
        location: location,
        note: note,
        scheduledAt: scheduledAt,
      );
      if (mounted) {
        widget.onCreated(meeting);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Schedule a meeting',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 20),

            // Title
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Location
            TextField(
              controller: _locationController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Location *',
                hintText: 'e.g. Community center, Room 12',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),

            // Date + time pickers side by side
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.calendar_today_outlined, size: 18),
                    label: Text(_dateLabel),
                    onPressed: _pickDate,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.schedule_outlined, size: 18),
                    label: Text(_timeLabel),
                    onPressed: _pickTime,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Note (optional)
            TextField(
              controller: _noteController,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Anything members should know beforehand...',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Schedule'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
