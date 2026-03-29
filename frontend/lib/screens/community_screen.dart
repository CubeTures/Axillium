import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import 'create_post_screen.dart';
import 'post_detail_screen.dart';

const _canPost = {'sponsor', 'leader', 'influencer'};
const _canFeature = {'leader', 'sponsor'};
const _addictionTypes = [
  'All',
  'Alcohol',
  'Drugs',
  'Gambling',
  'Gaming',
  'Social Media',
  'Food',
  'Other',
];

class CommunityScreen extends StatefulWidget {
  final LocalUser localUser;

  const CommunityScreen({super.key, required this.localUser});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Post> _posts = [];
  Set<int> _featuredIds = {};
  bool _loading = true;
  String? _error;

  String _titleFilter = '';
  String _addictionTypeFilter = 'All';

  int get _groupId => widget.localUser.groupId ?? 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        PostService().getGroupFeaturedPosts(_groupId),
        PostService().getPosts(
          addictionType:
              _addictionTypeFilter == 'All' ? null : _addictionTypeFilter,
          title: _titleFilter.isEmpty ? null : _titleFilter,
        ),
      ]);
      setState(() {
        _featuredIds = Set.from(results[0].map((p) => p.id));
        _posts = results[1];
      });
    } catch (e) {
      setState(() => _error = 'Could not load stories.');
    } finally {
      setState(() => _loading = false);
    }
  }

  void _onFeatureToggle(Post post, bool feature) async {
    try {
      if (feature) {
        await PostService().featurePostForGroup(
          groupId: _groupId,
          postId: post.id,
          featurerId: widget.localUser.userId ?? 0,
          featurerRole: widget.localUser.rank,
        );
      } else {
        await PostService().unfeaturePostForGroup(
          groupId: _groupId,
          postId: post.id,
          featurerRole: widget.localUser.rank,
        );
      }
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  void _showSearchSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SearchSheet(
        titleFilter: _titleFilter,
        onApply: (title) {
          setState(() => _titleFilter = title);
          _load();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final canWrite = _canPost.contains(widget.localUser.rank);
    final canFeatureUser = _canFeature.contains(widget.localUser.rank);

    return Scaffold(
      backgroundColor: cs.surface,
      floatingActionButton: canWrite
          ? Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).padding.bottom + 20,
              ),
              child: FloatingActionButton.extended(
                onPressed: () async {
                  final created = await Navigator.push<bool>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CreatePostScreen(user: widget.localUser),
                    ),
                  );
                  if (created == true) _load();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Write'),
              ),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 32, 16, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Community',
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stories from sponsors, leaders, and graduates.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Badge(
                      isLabelVisible: _titleFilter.isNotEmpty,
                      child: const Icon(Icons.search_outlined),
                    ),
                    tooltip: 'Search',
                    onPressed: _showSearchSheet,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Addiction type chips ─────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _addictionTypes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final type = _addictionTypes[i];
                  final selected = _addictionTypeFilter == type;
                  return ChoiceChip(
                    label: Text(type),
                    selected: selected,
                    onSelected: (_) {
                      if (_addictionTypeFilter != type) {
                        setState(() => _addictionTypeFilter = type);
                        _load();
                      }
                    },
                    showCheckmark: false,
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── Body ─────────────────────────────────────────────────────────
            Expanded(
              child: _buildBody(canFeatureUser),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(bool canFeatureUser) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No stories yet. Check back soon.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ),
      );
    }

    final featured = _posts.where((p) => _featuredIds.contains(p.id)).toList();
    final rest = _posts.where((p) => !_featuredIds.contains(p.id)).toList();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          20, 4, 20, 20 + MediaQuery.of(context).padding.bottom,
        ),
        children: [
          if (featured.isNotEmpty) ...[
            _SectionLabel(label: 'Featured this week'),
            const SizedBox(height: 10),
            ...featured.map((p) => _PostTile(
                  post: p,
                  localUser: widget.localUser,
                  isFeatured: true,
                  canFeature: canFeatureUser,
                  onFeatureToggle: _onFeatureToggle,
                )),
            const SizedBox(height: 8),
          ],
          if (rest.isNotEmpty) ...[
            if (featured.isNotEmpty) ...[
              _SectionLabel(label: 'All stories'),
              const SizedBox(height: 10),
            ],
            ...rest.map((p) => _PostTile(
                  post: p,
                  localUser: widget.localUser,
                  isFeatured: false,
                  canFeature: canFeatureUser,
                  onFeatureToggle: _onFeatureToggle,
                )),
          ],
        ],
      ),
    );
  }
}

// ── Section label ──────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

// ── Post tile ──────────────────────────────────────────────────────────────────

class _PostTile extends StatelessWidget {
  final Post post;
  final LocalUser localUser;
  final bool isFeatured;
  final bool canFeature;
  final void Function(Post, bool) onFeatureToggle;

  const _PostTile({
    required this.post,
    required this.localUser,
    required this.isFeatured,
    required this.canFeature,
    required this.onFeatureToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isFeatured ? cs.primaryContainer : cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PostDetailScreen(post: post, localUser: localUser),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isFeatured
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          post.authorAlias,
                          if (post.addictionType.isNotEmpty) post.addictionType,
                        ].join(' · '),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isFeatured
                              ? cs.onPrimaryContainer.withValues(alpha: 0.7)
                              : cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canFeature)
                  IconButton(
                    icon: Icon(
                      isFeatured ? Icons.bookmark : Icons.bookmark_border,
                      size: 20,
                      color: isFeatured ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                    ),
                    tooltip: isFeatured ? 'Unfeature' : 'Feature this week',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => onFeatureToggle(post, !isFeatured),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: isFeatured
                          ? cs.onPrimaryContainer.withValues(alpha: 0.5)
                          : cs.onSurfaceVariant.withValues(alpha: 0.5),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Search bottom sheet ────────────────────────────────────────────────────────

class _SearchSheet extends StatefulWidget {
  final String titleFilter;
  final void Function(String title) onApply;

  const _SearchSheet({required this.titleFilter, required this.onApply});

  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.titleFilter);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Search stories',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) {
                  widget.onApply(_controller.text.trim());
                  Navigator.pop(context);
                },
                decoration: InputDecoration(
                  hintText: 'e.g. hope, recovery, courage...',
                  prefixIcon: const Icon(Icons.search_outlined),
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
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        widget.onApply('');
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        widget.onApply(_controller.text.trim());
                        Navigator.pop(context);
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Search'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
