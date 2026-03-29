import 'package:flutter/material.dart';
import '../models/check_in.dart';
import '../services/check_in_service.dart';
import '../services/chat_service.dart';

class CheckInScreen extends StatefulWidget {
  final int userId;
  final int? groupId;
  final String alias;

  const CheckInScreen({
    super.key,
    required this.userId,
    required this.alias,
    this.groupId,
  });

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  static const _moodLabels = ['Rough', 'Hard', 'Okay', 'Good', 'Great'];

  final Map<String, dynamic> _responses = {};
  bool _submitting = false;
  bool _loadingToday = true;
  CheckIn? _todayCheckIn;
  bool _relapseMode = false;

  @override
  void initState() {
    super.initState();
    _checkToday();
  }

  Future<void> _checkToday() async {
    try {
      final ci = await CheckInService().getTodayCheckIn(widget.userId);
      if (mounted) setState(() => _todayCheckIn = ci);
    } catch (_) {
      // silently degrade — just show the form
    } finally {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  bool get _canSubmit => _relapseMode || _responses['mood'] != null;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final moodScore = _relapseMode
          ? (_todayCheckIn?.moodScore ?? 3)
          : _responses['mood'] as int;
      final relapsed =
          _relapseMode ? true : (_responses['relapsed'] as bool? ?? false);

      await CheckInService().submit(
        userId: widget.userId,
        moodScore: moodScore,
        relapsed: relapsed,
        reflection: _responses['reflection'] as String? ?? '',
      );

      final gid = widget.groupId;
      if (gid != null && gid > 0 && !_relapseMode) {
        final moodLabel = _moodLabels[moodScore - 1];
        await ChatService().sendMessage(
          gid,
          widget.userId,
          widget.alias,
          '📋 ${widget.alias} checked in — feeling $moodLabel.',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_relapseMode
                ? 'Relapse logged. Your sponsor and leader have been notified.'
                : 'Check-in saved. Thank you for showing up today.'),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingToday) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_todayCheckIn != null && !_relapseMode) {
      return _AlreadyCheckedInView(
        alias: widget.alias,
        checkIn: _todayCheckIn!,
        onLogRelapse: () => setState(() => _relapseMode = true),
      );
    }

    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final today = DateTime.now();
    final dateLabel =
        '${_weekday(today.weekday)}, ${today.day} ${_month(today.month)}';
    final relapsed = _responses['relapsed'] as bool? ?? false;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 4, 20, 24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Text(
              dateLabel,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              _relapseMode ? 'Log a\nrelapse.' : 'How are you\ndoing?',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _relapseMode
                  ? 'Take a moment to reflect. Your sponsor and leader will be notified.'
                  : 'A minute to reflect. This is just for you.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: 28),

            // ── Mood question ────────────────────────────────────────────────
            if (!_relapseMode) ...[
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'How was today?',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    _MoodRow(
                      value: _responses['mood'] as int?,
                      labels: _moodLabels,
                      onSelect: (v) =>
                          setState(() => _responses['mood'] = v),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // ── Relapse toggle ─────────────────────────────────────────────
              _Section(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Did you relapse?',
                            style: theme.textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Your sponsor will be notified.',
                            style: theme.textTheme.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: relapsed,
                      onChanged: (v) =>
                          setState(() => _responses['relapsed'] = v),
                    ),
                  ],
                ),
              ),

              if (relapsed) ...[
                const SizedBox(height: 10),
                _Section(
                  child: _ReflectionField(
                    value: _responses['reflection'] as String? ?? '',
                    onChanged: (v) =>
                        setState(() => _responses['reflection'] = v),
                  ),
                ),
              ],
            ] else ...[
              // ── Relapse mode: reflection only ──────────────────────────────
              _Section(
                child: _ReflectionField(
                  value: _responses['reflection'] as String? ?? '',
                  onChanged: (v) =>
                      setState(() => _responses['reflection'] = v),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // ── Submit ───────────────────────────────────────────────────────
            FilledButton(
              onPressed: (_canSubmit && !_submitting) ? _submit : null,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _submitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_relapseMode ? 'Log relapse' : 'Save check-in'),
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(int d) =>
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']
          [d - 1];

  static String _month(int m) => [
        'January', 'February', 'March',    'April',   'May',      'June',
        'July',    'August',   'September', 'October', 'November', 'December'
      ][m - 1];
}

// ── Already checked in ─────────────────────────────────────────────────────────

class _AlreadyCheckedInView extends StatelessWidget {
  final String alias;
  final CheckIn checkIn;
  final VoidCallback onLogRelapse;

  const _AlreadyCheckedInView({
    required this.alias,
    required this.checkIn,
    required this.onLogRelapse,
  });

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
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20, 4, 20, 24 + MediaQuery.of(context).padding.bottom,
          ),
          children: [
            Text(
              'All done,',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w300,
                color: cs.onSurface.withValues(alpha: 0.55),
                height: 1.1,
              ),
            ),
            Text(
              '$alias.',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'ve already checked in today.',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),

            const SizedBox(height: 28),

            _Section(
              child: Row(
                children: [
                  Text(
                    checkIn.moodEmoji,
                    style: const TextStyle(fontSize: 28),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkIn.moodLabel,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Today\'s mood',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (checkIn.reflection.isNotEmpty) ...[
              const SizedBox(height: 10),
              _Section(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your note',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      checkIn.reflection,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 32),

            Text(
              'Need to log a relapse?',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onLogRelapse,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text('Log a relapse'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared section container ───────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

// ── Mood rating row ────────────────────────────────────────────────────────────

class _MoodRow extends StatelessWidget {
  final int? value;
  final List<String> labels;
  final void Function(int) onSelect;

  const _MoodRow({
    required this.value,
    required this.labels,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          children: List.generate(5, (i) {
            final v = i + 1;
            final selected = value == v;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(v),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: selected
                        ? cs.primary
                        : cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$v',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: selected ? cs.onPrimary : cs.onSurface,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              labels.first,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            Text(
              labels.last,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Reflection text field ──────────────────────────────────────────────────────

class _ReflectionField extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _ReflectionField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What happened?',
          style:
              theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        Text(
          'There\'s no wrong answer. This is just for you.',
          style:
              theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        TextFormField(
          initialValue: value,
          minLines: 3,
          maxLines: 6,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: 'Write anything...',
            filled: true,
            fillColor: cs.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: cs.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
