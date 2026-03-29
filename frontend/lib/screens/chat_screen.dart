import 'package:flutter/material.dart';
import '../models/direct_message.dart';
import '../models/local_user.dart';
import '../models/message.dart';
import '../models/prompt_response.dart';
import '../models/weekly_prompt.dart';
import '../services/chat_service.dart';
import '../services/dm_service.dart';
import '../services/sponsor_service.dart';
import '../services/weekly_prompt_service.dart';
import 'meetings_screen.dart';
import 'members_screen.dart';

enum _ChatMode { group, weeklyPrompt, dm }

const _canSetPrompt = {'sponsor', 'leader', 'influencer'};
const _canRespond = {'apprentice', 'sponsor', 'leader', 'influencer', 'graduated'};

class _DmTarget {
  final int userId;
  final String alias;
  final String label;
  _DmTarget({required this.userId, required this.alias, required this.label});
}

class ChatScreen extends StatefulWidget {
  final LocalUser user;

  const ChatScreen({super.key, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _chatService = ChatService();
  final _dmService = DmService();
  final _promptService = WeeklyPromptService();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // Group chat state
  List<Message> _groupMessages = [];

  // DM state
  List<DirectMessage> _dmMessages = [];
  List<_DmTarget> _dmTargets = [];
  _DmTarget? _activeDmTarget;

  // Weekly prompt state
  WeeklyPrompt? _prompt;
  List<PromptResponse> _promptResponses = [];
  bool _loadingPrompt = false;
  bool _loadingMoreResponses = false;
  int _promptPage = 1;
  bool _promptHasMore = true;

  _ChatMode _mode = _ChatMode.group;
  bool _loading = false;
  bool _sending = false;
  int _onlineCount = 0;

  int get _groupId => widget.user.groupId ?? 0;
  int get _userId => widget.user.userId ?? 0;
  String get _rank => widget.user.rank;

  @override
  void initState() {
    super.initState();
    _loadGroupMessages();
    _loadDmTargets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_mode != _ChatMode.weeklyPrompt) return;
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_loadingMoreResponses &&
        _promptHasMore) {
      _loadMorePromptResponses();
    }
  }

  Future<void> _loadDmTargets() async {
    final userId = _userId;
    if (userId == 0) return;

    final targets = <_DmTarget>[];

    if (widget.user.sponsorId != null) {
      final sponsor =
          await SponsorService().getUserBasic(widget.user.sponsorId!);
      if (sponsor != null) {
        targets.add(_DmTarget(
          userId: sponsor.id,
          alias: sponsor.alias,
          label: 'Sponsor: ${sponsor.alias}',
        ));
      }
    }

    if (widget.user.rank == 'sponsor' || widget.user.rank == 'leader') {
      final apprentices = await SponsorService().getApprentices(userId);
      for (final a in apprentices) {
        targets.add(_DmTarget(
          userId: a.id,
          alias: a.alias,
          label: a.alias,
        ));
      }
    }

    if (mounted) setState(() => _dmTargets = targets);
  }

  Future<void> _loadGroupMessages() async {
    if (_groupId == 0) return;
    setState(() => _loading = true);
    try {
      final messages = await _chatService.getMessages(_groupId);
      setState(() => _groupMessages = messages);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load messages: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDmMessages(_DmTarget target) async {
    setState(() => _loading = true);
    try {
      final messages = await _dmService.getDMs(_userId, target.userId);
      setState(() => _dmMessages = messages);
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load messages: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWeeklyPrompt() async {
    setState(() {
      _loadingPrompt = true;
      _promptResponses = [];
      _promptPage = 1;
      _promptHasMore = true;
    });
    try {
      final prompt = await _promptService.getCurrentPrompt();
      setState(() => _prompt = prompt);
      await _loadMorePromptResponses();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load prompt: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingPrompt = false);
    }
  }

  Future<void> _loadMorePromptResponses() async {
    if (_loadingMoreResponses || !_promptHasMore) return;
    setState(() => _loadingMoreResponses = true);
    try {
      final batch = await _promptService.getResponses(page: _promptPage);
      setState(() {
        _promptResponses.addAll(batch);
        _promptPage++;
        if (batch.length < 20) _promptHasMore = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load responses: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMoreResponses = false);
    }
  }

  void _switchMode(_ChatMode mode, {_DmTarget? dmTarget}) {
    setState(() {
      _mode = mode;
      if (dmTarget != null) _activeDmTarget = dmTarget;
    });
    if (mode == _ChatMode.group) {
      _loadGroupMessages();
    } else if (mode == _ChatMode.weeklyPrompt) {
      _loadWeeklyPrompt();
    } else if (dmTarget != null) {
      _loadDmMessages(dmTarget);
    }
  }

  Future<void> _send() async {
    final content = _textController.text.trim();
    if (content.isEmpty || _sending) return;
    _textController.clear();
    setState(() => _sending = true);
    try {
      if (_mode == _ChatMode.group) {
        final msg = await _chatService.sendMessage(
            _groupId, _userId, widget.user.alias, content);
        setState(() => _groupMessages.add(msg));
      } else if (_mode == _ChatMode.weeklyPrompt) {
        final response = await _promptService.postResponse(
          userId: _userId,
          userAlias: widget.user.alias,
          userRole: _rank,
          content: content,
        );
        setState(() => _promptResponses.add(response));
      } else if (_activeDmTarget != null) {
        final msg = await _dmService.sendDM(
          senderId: _userId,
          recipientId: _activeDmTarget!.userId,
          senderAlias: widget.user.alias,
          content: content,
        );
        setState(() => _dmMessages.add(msg));
      }
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
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

  String get _currentTitle {
    switch (_mode) {
      case _ChatMode.group:
        return 'Group Chat';
      case _ChatMode.weeklyPrompt:
        return 'Weekly Prompt';
      case _ChatMode.dm:
        return _activeDmTarget?.label ?? 'Direct Message';
    }
  }

  Widget _buildTitleDropdown() {
    return PopupMenuButton<String>(
      tooltip: 'Switch chat',
      onSelected: (key) {
        if (key == '__group__') {
          _switchMode(_ChatMode.group);
        } else if (key == '__weekly__') {
          _switchMode(_ChatMode.weeklyPrompt);
        } else {
          final target = _dmTargets.firstWhere((t) => '${t.userId}' == key);
          _switchMode(_ChatMode.dm, dmTarget: target);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: '__group__',
          child: Row(children: [
            const Icon(Icons.group_outlined, size: 18),
            const SizedBox(width: 8),
            const Text('Group Chat'),
          ]),
        ),
        PopupMenuItem(
          value: '__weekly__',
          child: Row(children: [
            const Icon(Icons.forum_outlined, size: 18),
            const SizedBox(width: 8),
            const Text('Weekly Prompt'),
          ]),
        ),
        if (_dmTargets.isNotEmpty) ...[
          const PopupMenuDivider(),
          ..._dmTargets.map((t) => PopupMenuItem(
                value: '${t.userId}',
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 18),
                  const SizedBox(width: 8),
                  Text(t.label),
                ]),
              )),
        ],
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currentTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }

  Widget _buildFloatingHeader(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGroup = _mode == _ChatMode.group;
    final canEditPrompt =
        _mode == _ChatMode.weeklyPrompt && _canSetPrompt.contains(_rank);

    return Material(
      elevation: 3,
      shadowColor: colorScheme.shadow.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(28),
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            colors: [
              colorScheme.primaryContainer,
              colorScheme.secondaryContainer,
            ],
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 6, 12, 6),
        child: Row(
          children: [
            // Left: title + online count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildTitleDropdown(),
                  const SizedBox(height: 1),
                  Text(
                    '$_onlineCount online',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer
                              .withValues(alpha: 0.7),
                        ),
                  ),
                ],
              ),
            ),

            // Right: inline action icons
            if (isGroup) ...[
              IconButton(
                icon: const Icon(Icons.calendar_month_outlined),
                tooltip: 'Meetings',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MeetingsScreen(
                      user: widget.user,
                      groupId: _groupId,
                    ),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.group_outlined),
                tooltip: 'Members',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => MembersScreen(groupId: _groupId)),
                ),
              ),
            ] else if (canEditPrompt)
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Set prompt',
                onPressed: _openSetPromptSheet,
              ),
          ],
        ),
      ),
      ),
    );
  }

  // ── Weekly prompt UI ───────────────────────────────────────────────────────

  void _openSetPromptSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SetPromptSheet(
        user: widget.user,
        service: _promptService,
        existingPrompt: _prompt,
        onPromptSet: (prompt) {
          setState(() {
            _prompt = prompt;
            _promptResponses = [];
            _promptPage = 1;
            _promptHasMore = true;
          });
          _loadMorePromptResponses();
        },
      ),
    );
  }

  Widget _buildPromptCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_prompt == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Material(
        elevation: 0,
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
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
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Material(
        elevation: 0,
        color: colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
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
                'Asked by ${_prompt!.setByAlias} · '
                '${_prompt!.setByRole[0].toUpperCase()}${_prompt!.setByRole.substring(1)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyPromptBody(BuildContext context, double topPadding) {
    final headerOffset = topPadding + 88.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    const halfBarHeight = 32.0;
    final solidBottomHeight = safeBottom + halfBarHeight;

    final inputWidget = _buildWeeklyPromptInput();

    if (_loadingPrompt) {
      return Stack(
        children: [
          Positioned.fill(
            child: Padding(
              padding: EdgeInsets.only(
                  top: headerOffset, bottom: solidBottomHeight + 64),
              child: const Center(child: CircularProgressIndicator()),
            ),
          ),
          Positioned(
            bottom: 0, left: 0, right: 0,
            height: solidBottomHeight,
            child: Container(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Positioned(bottom: 0, left: 0, right: 0, child: inputWidget),
        ],
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(height: headerOffset),
              _buildPromptCard(context),
              Expanded(
                child: _promptResponses.isEmpty && !_loadingMoreResponses
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
                                    .onSurfaceVariant,
                              ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding: EdgeInsets.fromLTRB(
                            4, 8, 4, solidBottomHeight - 84),
                        itemCount: _promptResponses.length +
                            (_loadingMoreResponses ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _promptResponses.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final r = _promptResponses[index];
                          return _MessageBubble(
                            message: _UnifiedMessage(
                              senderId: r.userId,
                              alias: r.userAlias,
                              role: r.userRole,
                              content: r.content,
                            ),
                            isMe: r.userId == _userId,
                          );
                        },
                      ),
              ),
              SizedBox(height: solidBottomHeight),
            ],
          ),
        ),
        Positioned(
          bottom: 0, left: 0, right: 0,
          height: solidBottomHeight,
          child: Container(color: Theme.of(context).scaffoldBackgroundColor),
        ),
        Positioned(bottom: 0, left: 0, right: 0, child: inputWidget),
      ],
    );
  }

  Widget _buildWeeklyPromptInput() {
    if (_userId == 0 || !_canRespond.contains(_rank)) {
      return _AnonBanner(text: 'Register to join the discussion.');
    }
    if (_prompt == null) {
      return _DisabledInputBar(hint: 'Waiting for this week\'s prompt...');
    }
    return _InputBar(
      controller: _textController,
      onSend: _send,
      sending: _sending,
    );
  }

  // ── Main build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_groupId == 0) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chat')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'You\'re not in a group yet. Complete onboarding to join one.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    final topPadding = MediaQuery.of(context).padding.top;
    // Solid bg covers status bar + top half of the ~60px header pill
    final headerBgHeight = topPadding + 8 + 30.0;

    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _mode == _ChatMode.weeklyPrompt
              ? _buildWeeklyPromptBody(context, topPadding)
              : _buildGroupOrDmBody(context, topPadding),
          // Header background: solid from top down to halfway through the pill
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: headerBgHeight,
            child: Container(
                color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Positioned(
            top: topPadding + 8,
            left: 16,
            right: 16,
            child: _buildFloatingHeader(context),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupOrDmBody(BuildContext context, double topPadding) {
    final headerOffset = topPadding + 88.0;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    // Solid bg covers bottom half of the ~64px input bar + safe area
    const halfBarHeight = 32.0;
    final solidBottomHeight = safeBottom + halfBarHeight;

    final messages = _mode == _ChatMode.group
        ? _groupMessages
            .map((m) => _UnifiedMessage(
                  senderId: m.userId,
                  alias: m.alias,
                  role: m.senderRole,
                  content: m.content,
                ))
            .toList()
        : _dmMessages
            .map((m) => _UnifiedMessage(
                  senderId: m.senderId,
                  alias: m.senderAlias,
                  role: m.senderRole,
                  content: m.content,
                ))
            .toList();

    final inputWidget = _userId == 0
        ? _AnonBanner(text: 'Register to send messages.')
        : _InputBar(
            controller: _textController,
            onSend: _send,
            sending: _sending,
          );

    return Stack(
      children: [
        Positioned.fill(
          child: _loading
              ? Padding(
                  padding: EdgeInsets.only(
                      top: headerOffset, bottom: solidBottomHeight + 64),
                  child: const Center(child: CircularProgressIndicator()),
                )
              : messages.isEmpty
                  ? Padding(
                      padding: EdgeInsets.only(
                          top: headerOffset, bottom: solidBottomHeight + 64),
                      child: const Center(child: Text('No messages yet.')),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.fromLTRB(
                          16, headerOffset, 16, solidBottomHeight + 48),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final m = messages[index];
                        return _MessageBubble(
                          message: m,
                          isMe: m.senderId == _userId,
                        );
                      },
                    ),
        ),
        // Bottom solid block: covers only the bottom half of the bar area
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: solidBottomHeight,
          child: Container(
              color: Theme.of(context).scaffoldBackgroundColor),
        ),
        // Input bar on top
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: inputWidget,
        ),
      ],
    );
  }
}

// ── Shared view model ─────────────────────────────────────────────────────────

class _UnifiedMessage {
  final int senderId;
  final String alias;
  final String role;
  final String content;
  final String? profilePicture;
  _UnifiedMessage({
    required this.senderId,
    required this.alias,
    required this.role,
    required this.content,
    this.profilePicture,
  });
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  final _UnifiedMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  bool get _isSystemMessage => message.content.startsWith('📋');

  String get _systemDisplayText {
    return message.content.replaceFirst(
      'Checked in today',
      '${message.alias} checked in',
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isSystemMessage) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _systemDisplayText,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
    }

    final bubble = Container(
      margin: EdgeInsets.only(
        top: 4,
        bottom: 4,
        left: isMe ? 8 : 4,
        right: isMe ? 16 : 8,
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFFFCE4EC) : colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isMe
            ? [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.alias,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSecondaryContainer,
                    ),
                  ),
                  if (message.role == 'leader') ...[
                    const SizedBox(width: 4),
                    _RoleBadge(label: 'Leader', color: colorScheme.primary),
                  ] else if (message.role == 'sponsor') ...[
                    const SizedBox(width: 4),
                    _RoleBadge(
                        label: 'Sponsor', color: colorScheme.secondary),
                  ],
                ],
              ),
            ),
          Text(
            message.content,
            style: TextStyle(
              color: isMe ? const Color(0xFF4A1428) : colorScheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );

    if (isMe) {
      return Align(
        alignment: Alignment.centerRight,
        child: bubble,
      );
    }

    // Non-me: avatar + bubble
    final hasPhoto = message.profilePicture != null;
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 4),
            child: CircleAvatar(
              radius: 16,
              backgroundImage:
                  hasPhoto ? NetworkImage(message.profilePicture!) : null,
              backgroundColor: colorScheme.secondaryContainer,
              child: hasPhoto
                  ? null
                  : Text(
                      message.alias.isNotEmpty
                          ? message.alias[0].toUpperCase()
                          : '?',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSecondaryContainer,
                      ),
                    ),
            ),
          ),
          bubble,
        ],
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
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Input / banner widgets ────────────────────────────────────────────────────

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
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: const InputDecoration(
                    hintText: 'Message...',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: FilledButton(
                  onPressed: sending ? null : onSend,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DisabledInputBar extends StatelessWidget {
  final String hint;
  const _DisabledInputBar({required this.hint});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(32),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: hint,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(4),
                child: FilledButton(
                  onPressed: null,
                  style: FilledButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Icon(Icons.send, size: 20),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnonBanner extends StatelessWidget {
  final String text;
  const _AnonBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ── Set-prompt bottom sheet ───────────────────────────────────────────────────

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
      final suggestions =
          await widget.service.getSuggestions(widget.user.rank);
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
                                style:
                                    Theme.of(context).textTheme.bodyMedium),
                            onTap: () =>
                                setState(() => _controller.text = s),
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
                                    strokeWidth: 2,
                                    color: Colors.white),
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
