import 'package:flutter/material.dart';

// ── Question definitions ───────────────────────────────────────────────────
// To customise the daily form: add, remove, or reorder entries in
// CheckInScreen._questions. The three types cover most use cases.

sealed class CheckInQuestion {
  final String id;
  final String prompt;
  const CheckInQuestion({required this.id, required this.prompt});
}

/// A 1–N rating scale. Provide a label for each value in [labels] (index 0 = value 1).
class LikertQuestion extends CheckInQuestion {
  final int steps;
  final List<String> labels;
  const LikertQuestion({
    required super.id,
    required super.prompt,
    this.steps = 5,
    required this.labels,
  });
}

/// A yes/no toggle (stored as bool).
class BoolQuestion extends CheckInQuestion {
  const BoolQuestion({required super.id, required super.prompt});
}

/// A free-text field, optionally shown only when a condition is met.
class TextQuestion extends CheckInQuestion {
  final String hint;
  final bool Function(Map<String, dynamic> responses)? showWhen;
  const TextQuestion({
    required super.id,
    required super.prompt,
    this.hint = '',
    this.showWhen,
  });
}

// ── Question widget ────────────────────────────────────────────────────────

class QuestionWidget extends StatelessWidget {
  final CheckInQuestion question;
  final Map<String, dynamic> responses;
  final void Function(String id, dynamic value) onChanged;

  const QuestionWidget({
    super.key,
    required this.question,
    required this.responses,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final q = question;

    if (q is TextQuestion && q.showWhen != null && !q.showWhen!(responses)) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: switch (q) {
        LikertQuestion() => _LikertWidget(q: q, responses: responses, onChanged: onChanged),
        BoolQuestion()   => _BoolWidget(q: q, responses: responses, onChanged: onChanged),
        TextQuestion()   => _TextWidget(q: q, responses: responses, onChanged: onChanged),
      },
    );
  }
}

// ── Likert ─────────────────────────────────────────────────────────────────

class _LikertWidget extends StatelessWidget {
  final LikertQuestion q;
  final Map<String, dynamic> responses;
  final void Function(String, dynamic) onChanged;

  const _LikertWidget({required this.q, required this.responses, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = responses[q.id] as int?;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.prompt, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        Row(
          children: List.generate(q.steps, (i) {
            final value = i + 1;
            final selected = current == value;
            return Expanded(
              child: GestureDetector(
                onTap: () => onChanged(q.id, value),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$value',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: selected
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(q.labels.first,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            Text(q.labels.last,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      ],
    );
  }
}

// ── Bool ───────────────────────────────────────────────────────────────────

class _BoolWidget extends StatelessWidget {
  final BoolQuestion q;
  final Map<String, dynamic> responses;
  final void Function(String, dynamic) onChanged;

  const _BoolWidget({required this.q, required this.responses, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final current = responses[q.id] as bool? ?? false;
    return Row(
      children: [
        Expanded(child: Text(q.prompt, style: Theme.of(context).textTheme.titleSmall)),
        Switch(
          value: current,
          onChanged: (v) => onChanged(q.id, v),
        ),
      ],
    );
  }
}

// ── Text ───────────────────────────────────────────────────────────────────

class _TextWidget extends StatelessWidget {
  final TextQuestion q;
  final Map<String, dynamic> responses;
  final void Function(String, dynamic) onChanged;

  const _TextWidget({required this.q, required this.responses, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q.prompt, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: responses[q.id] as String? ?? '',
          minLines: 3,
          maxLines: 6,
          decoration: InputDecoration(
            hintText: q.hint,
            border: const OutlineInputBorder(),
          ),
          onChanged: (v) => onChanged(q.id, v),
        ),
      ],
    );
  }
}
