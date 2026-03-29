import 'package:flutter/material.dart';
import '../models/check_in.dart';
import '../services/check_in_service.dart';
import '../services/chat_service.dart';
import '../widgets/form_question.dart';

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
  // ── Question list ──────────────────────────────────────────────────────────
  // Add, remove, or reorder questions here to customise the daily form.
  static final _questions = <CheckInQuestion>[
    LikertQuestion(
      id: 'mood',
      prompt: 'How was today?',
      steps: 5,
      labels: ['Very hard', 'Hard', 'Okay', 'Good', 'Great'],
    ),
    BoolQuestion(
      id: 'relapsed',
      prompt: 'Did you relapse today?',
    ),
    TextQuestion(
      id: 'reflection',
      prompt: 'What happened, or what did you learn?',
      hint: 'There\'s no wrong answer here. This is just for you.',
      showWhen: _relapseOccurred,
    ),
  ];

  static bool _relapseOccurred(Map<String, dynamic> r) => r['relapsed'] == true;

  // ── State ──────────────────────────────────────────────────────────────────

  final Map<String, dynamic> _responses = {};
  bool _submitting = false;
  bool _loadingToday = true;
  CheckIn? _todayCheckIn; // set if user already checked in today
  bool _relapseMode = false; // true when logging relapse after already checking in

  @override
  void initState() {
    super.initState();
    _checkToday();
  }

  Future<void> _checkToday() async {
    try {
      final checkIn = await CheckInService().getTodayCheckIn(widget.userId);
      if (mounted) setState(() => _todayCheckIn = checkIn);
    } catch (_) {
      // Ignore errors — just show the full form.
    } finally {
      if (mounted) setState(() => _loadingToday = false);
    }
  }

  void _onChanged(String id, dynamic value) {
    setState(() => _responses[id] = value);
  }

  bool get _canSubmit => _relapseMode
      ? true // relapse mode only needs optional reflection
      : _responses['mood'] != null;

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final moodScore = _relapseMode
          ? (_todayCheckIn?.moodScore ?? 3)
          : _responses['mood'] as int;
      final relapsed = _relapseMode ? true : (_responses['relapsed'] as bool? ?? false);

      await CheckInService().submit(
        userId: widget.userId,
        moodScore: moodScore,
        relapsed: relapsed,
        reflection: _responses['reflection'] as String? ?? '',
      );

      // Post a system message to the group chat summarising the check-in.
      final gid = widget.groupId;
      if (gid != null && gid > 0 && !_relapseMode) {
        final moodLabel = const ['Very hard', 'Hard', 'Okay', 'Good', 'Great'][moodScore - 1];
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
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
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

    // Already checked in today — show summary and optional relapse logging.
    if (_todayCheckIn != null && !_relapseMode) {
      return _AlreadyCheckedInView(
        alias: widget.alias,
        checkIn: _todayCheckIn!,
        onLogRelapse: () => setState(() => _relapseMode = true),
      );
    }

    final today = DateTime.now();
    final dateLabel =
        '${_weekday(today.weekday)}, ${today.day} ${_month(today.month)} ${today.year}';

    return Scaffold(
      appBar: AppBar(
        title: Text(_relapseMode ? 'Log Relapse' : 'Daily Check-in'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(dateLabel,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  )),
          const SizedBox(height: 4),
          Text(
            _relapseMode ? 'Log today\'s relapse' : 'How are you doing?',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            _relapseMode
                ? 'Take a moment to reflect. This is just for you — and your sponsor and leader will be notified.'
                : 'This takes about a minute. It\'s just for you — a moment to reflect.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          if (_relapseMode) ...[
            // Relapse-only mode: just show the reflection text field.
            QuestionWidget(
              question: TextQuestion(
                id: 'reflection',
                prompt: 'What happened, or what did you learn?',
                hint: 'There\'s no wrong answer here. This is just for you.',
              ),
              responses: _responses,
              onChanged: _onChanged,
            ),
          ] else ...[
            for (final q in _questions) ...[
              QuestionWidget(
                question: q,
                responses: _responses,
                onChanged: _onChanged,
              ),
              if (q.id == 'relapsed' && _responses['relapsed'] == true)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.onErrorContainer),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your sponsor and group leader will be notified.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ],
          const SizedBox(height: 8),
          FilledButton(
            onPressed: (_canSubmit && !_submitting) ? _submit : null,
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
    );
  }

  static String _weekday(int d) =>
      ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'][d - 1];

  static String _month(int m) => [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m - 1];
}

/// Shown when the user has already completed their check-in for today.
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
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Check-in')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            Icon(
              Icons.check_circle_outline,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              '$alias has already checked in today',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${checkIn.moodEmoji} ${checkIn.moodLabel}',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            if (checkIn.reflection.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  checkIn.reflection,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
            const Spacer(),
            Text(
              'Need to log a relapse?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: onLogRelapse,
              child: const Text('Log a relapse'),
            ),
          ],
        ),
      ),
    );
  }
}
