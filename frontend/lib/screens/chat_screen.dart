import 'package:flutter/material.dart';
import '../models/direct_message.dart';
import '../models/local_user.dart';
import '../models/message.dart';
import '../services/chat_service.dart';
import '../services/dm_service.dart';
import '../services/sponsor_service.dart';
import 'members_screen.dart';

enum _ChatMode { group, dm }

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
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  // Group chat state
  List<Message> _groupMessages = [];

  // DM state
  List<DirectMessage> _dmMessages = [];
  List<_DmTarget> _dmTargets = [];
  _DmTarget? _activeDmTarget;

  _ChatMode _mode = _ChatMode.group;
  bool _loading = false;
  bool _sending = false;

  int get _groupId => widget.user.groupId ?? 0;
  int get _userId => widget.user.userId ?? 0;

  @override
  void initState() {
    super.initState();
    _loadGroupMessages();
    _loadDmTargets();
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDmTargets() async {
    final userId = _userId;
    if (userId == 0) return;

    final targets = <_DmTarget>[];

    // Apprentice: can DM their sponsor.
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

    // Sponsor/leader: can DM each apprentice.
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

  void _switchMode(_ChatMode mode, {_DmTarget? dmTarget}) {
    setState(() {
      _mode = mode;
      if (dmTarget != null) _activeDmTarget = dmTarget;
    });
    if (mode == _ChatMode.group) {
      _loadGroupMessages();
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
          SnackBar(content: Text('Could not send message: $e')),
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
    if (_mode == _ChatMode.group) return 'Group Chat';
    return _activeDmTarget?.label ?? 'Direct Message';
  }

  Widget _buildTitleDropdown() {
    final hasDmTargets = _dmTargets.isNotEmpty;
    if (!hasDmTargets) return Text(_currentTitle);

    return PopupMenuButton<String>(
      tooltip: 'Switch chat',
      onSelected: (key) {
        if (key == '__group__') {
          _switchMode(_ChatMode.group);
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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_currentTitle),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
    );
  }

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

    return Scaffold(
      appBar: AppBar(
        title: _buildTitleDropdown(),
        actions: [
          if (_mode == _ChatMode.group) ...[
            IconButton(
              icon: const Icon(Icons.people_outline),
              tooltip: 'Members',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => MembersScreen(groupId: _groupId)),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _loadGroupMessages,
            ),
          ] else ...[
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed:
                  (_loading || _activeDmTarget == null) ? null : () => _loadDmMessages(_activeDmTarget!),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : messages.isEmpty
                    ? const Center(child: Text('No messages yet.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(8),
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
          _userId == 0
              ? _AnonBanner()
              : _InputBar(
                  controller: _textController,
                  onSend: _send,
                  sending: _sending,
                ),
        ],
      ),
    );
  }
}

// Unified view model so group messages and DMs render identically.
class _UnifiedMessage {
  final int senderId;
  final String alias;
  final String role;
  final String content;
  _UnifiedMessage({
    required this.senderId,
    required this.alias,
    required this.role,
    required this.content,
  });
}

class _MessageBubble extends StatelessWidget {
  final _UnifiedMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  bool get _isSystemMessage => message.content.startsWith('📋');

  // Rewrites legacy "📋 Checked in today — feeling X." to attribute it.
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

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
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
        style: TextStyle(
            fontSize: 10, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

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
                  hintText: 'Message...',
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

class _AnonBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(
          'Register to send messages.',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }
}
