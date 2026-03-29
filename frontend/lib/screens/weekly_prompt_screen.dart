import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../models/prompt_response.dart';
import '../models/weekly_prompt.dart';
import '../services/weekly_prompt_service.dart';

const _canSetPrompt = {'sponsor', 'leader', 'influencer'};
const _canRespond = {'apprentice', 'sponsor', 'leader', 'influencer', 'graduated'};

class WeeklyPromptScreen extends StatefulWidget {
  final LocalUser user;

  const WeeklyPromptScreen({super.key, required this.user});

  @override
  State<WeeklyPromptScreen> createState() => _WeeklyPromptScreenState();
}

class _WeeklyPromptScreenState extends State<WeeklyPromptScreen> {
  final _service = WeeklyPromptService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  WeeklyPrompt? _prompt;
  List<PromptResponse> _responses = [];
  bool _loadingPrompt = true;
  bool _loadingMore = false;
  bool _sending = false;
  int _page = 1;
  bool _hasMore = true;

  int get _userId => widget.user.userId ?? 0;
  String get _rank => widget.user.rank;

  @override
  void initState() {
    super.initState();
    _loadPrompt();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMore &&
        _hasMore) {
      _loadMoreResponses();
    }
  }

  Future<void> _loadPrompt() async {
    setState(() => _loadingPrompt = true);
    try {
      final prompt = await _service.getCurrentPrompt();
      setState(() {
        _prompt = prompt;
        _responses = [];
        _page = 1;
        _hasMore = true;
      });
      await _loadMoreResponses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not load prompt: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingPrompt = false);
    }
  }

  Future<void> _loadMoreResponses() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final batch = await _service.getResponses(page: _page);
      setState(() {
        _responses.addAll(batch);
        _page++;
        if (batch.length < 20) _hasMore = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not load responses: $e')));
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _send() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      final response = await _service.postResponse(
        userId: _userId,
        userAlias: widget.user.alias,
        userRole: _rank,
        content: content,
      );
      setState(() => _responses.add(response));
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openSetPromptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetPromptSheet(
        user: widget.user,
        service: _service,
        existingPrompt: _prompt,
        onPromptSet: (prompt) {
          setState(() {
            _prompt = prompt;
            _responses = [];
            _page = 1;
            _hasMore = true;
          });
          _loadMoreResponses();
        },
      ),
    );
  }

  Widget _buildPromptCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_prompt == null) {
      return Card(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'No prompt set yet this week.',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
              ),
              if (_canSetPrompt.contains(_rank)) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.tonal(
                    onPressed: _openSetPromptSheet,
                    child: const Text('Set this week\'s prompt'),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _prompt!.promptText,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Asked by ${_prompt!.setByAlias} · ${_prompt!.setByRole[0].toUpperCase()}${_prompt!.setByRole.substring(1)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onPrimaryContainer
                        .withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weekly Prompt'),
        actions: [
          if (_canSetPrompt.contains(_rank))
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Set prompt',
              onPressed: _openSetPromptSheet,
            ),
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: _loadingPrompt ? null : _loadPrompt,
          ),
        ],
      ),
      body: _loadingPrompt
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildPromptCard(context),
                Expanded(
                  child: _responses.isEmpty && !_loadingMore
                      ? Center(
                          child: Text(
                            _prompt == null
                                ? 'Responses will appear here once a prompt is set.'
                                : 'No responses yet. Be the first to share.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(8),
                          itemCount:
                              _responses.length + (_loadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _responses.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                    child: CircularProgressIndicator()),
                              );
                            }
                            final r = _responses[index];
                            return _ResponseBubble(
                              response: r,
                              isMe: r.userId == _userId,
                            );
                          },
                        ),
                ),
                _buildInputArea(context),
              ],
            ),
    );
  }

  Widget _buildInputArea(BuildContext context) {
    if (_userId == 0 || !_canRespond.contains(_rank)) {
      return _AnonBanner();
    }
    if (_prompt == null) {
      return _DisabledInputBar();
    }
    return _InputBar(
      controller: _textController,
      onSend: _send,
      sending: _sending,
    );
  }
}

// ── Response bubble ──────────────────────────────────────────────────────────

class _ResponseBubble extends StatelessWidget {
  final PromptResponse response;
  final bool isMe;

  const _ResponseBubble({required this.response, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? colorScheme.primaryContainer
              : colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      response.userAlias,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
                    if (response.userRole == 'leader') ...[
                      const SizedBox(width: 4),
                      _RoleBadge(
                          label: 'Leader', color: colorScheme.primary),
                    ] else if (response.userRole == 'sponsor') ...[
                      const SizedBox(width: 4),
                      _RoleBadge(
                          label: 'Sponsor', color: colorScheme.secondary),
                    ],
                  ],
                ),
              ),
            Text(
              response.content,
              style: TextStyle(
                color: isMe
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSecondaryContainer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _RoleBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Input / banner widgets ───────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool sending;

  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.sending,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: const InputDecoration(
                  hintText: 'Share your response...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              onPressed: sending ? null : onSend,
            ),
          ],
        ),
      ),
    );
  }
}

class _DisabledInputBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                enabled: false,
                decoration: const InputDecoration(
                  hintText: 'Waiting for this week\'s prompt...',
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: const Icon(Icons.send),
              onPressed: null,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          'Register to join the discussion.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ── Set-prompt bottom sheet ──────────────────────────────────────────────────

class _SetPromptSheet extends StatefulWidget {
  final LocalUser user;
  final WeeklyPromptService service;
  final WeeklyPrompt? existingPrompt;
  final void Function(WeeklyPrompt) onPromptSet;

  const _SetPromptSheet({
    required this.user,
    required this.service,
    required this.existingPrompt,
    required this.onPromptSet,
  });

  @override
  State<_SetPromptSheet> createState() => _SetPromptSheetState();
}

class _SetPromptSheetState extends State<_SetPromptSheet> {
  final _controller = TextEditingController();
  List<String> _suggestions = [];
  bool _loadingSuggestions = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingPrompt != null) {
      _controller.text = widget.existingPrompt!.promptText;
    }
    _loadSuggestions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    try {
      final suggestions = await widget.service.getSuggestions(widget.user.rank);
      if (mounted) setState(() => _suggestions = suggestions);
    } catch (_) {
      // Suggestions are a convenience — silently ignore failures.
    } finally {
      if (mounted) setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      final prompt = await widget.service.setCurrentPrompt(
        userId: widget.user.userId!,
        userAlias: widget.user.alias,
        userRole: widget.user.rank,
        promptText: text,
      );
      if (mounted) {
        widget.onPromptSet(prompt);
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
    final isReplacing = widget.existingPrompt != null;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  isReplacing
                      ? 'Replace this week\'s prompt'
                      : 'Set this week\'s prompt',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _controller,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Write your own prompt...',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '— or pick a suggestion —',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _loadingSuggestions
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (_, index) {
                          final s = _suggestions[index];
                          return ListTile(
                            dense: true,
                            title: Text(s,
                                style: Theme.of(context).textTheme.bodyMedium),
                            onTap: () => setState(() => _controller.text = s),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
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
                            : const Text('Set Prompt'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
