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

  final _searchController = TextEditingController();

  int get _groupId => widget.localUser.groupId ?? 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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

  void _onFeatureToggle(Post post, bool wasFeature) async {
    try {
      if (wasFeature) {
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
          SnackBar(
              content:
                  Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final canWrite = _canPost.contains(widget.localUser.rank);
    return Scaffold(
      appBar: AppBar(title: const Text('Community Stories')),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
              onPressed: () async {
                final created = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        CreatePostScreen(user: widget.localUser),
                  ),
                );
                if (created == true) _load();
              },
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Write'),
            )
          : null,
      body: Column(
        children: [
          _FilterBar(
            searchController: _searchController,
            selectedType: _addictionTypeFilter,
            onSearch: (v) {
              _titleFilter = v;
              _load();
            },
            onTypeChanged: (v) {
              setState(() => _addictionTypeFilter = v);
              _load();
            },
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final featured = _posts.where((p) => _featuredIds.contains(p.id)).toList();
    final rest = _posts.where((p) => !_featuredIds.contains(p.id)).toList();
    final canFeatureUser = _canFeature.contains(widget.localUser.rank);

    if (_posts.isEmpty) {
      return const Center(child: Text('No stories yet. Check back soon.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (featured.isNotEmpty) ...[
            _SectionHeader(label: 'Featured This Week'),
            ...featured.map((p) => _PostCard(
                  post: p,
                  localUser: widget.localUser,
                  isFeatured: true,
                  canFeature: canFeatureUser,
                  onFeatureToggle: _onFeatureToggle,
                )),
            const Divider(height: 32, thickness: 1),
          ],
          if (rest.isNotEmpty) ...[
            if (featured.isNotEmpty) _SectionHeader(label: 'All Stories'),
            ...rest.map((p) => _PostCard(
                  post: p,
                  localUser: widget.localUser,
                  isFeatured: false,
                  canFeature: canFeatureUser,
                  onFeatureToggle: _onFeatureToggle,
                )),
          ],
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedType;
  final void Function(String) onSearch;
  final void Function(String) onTypeChanged;

  const _FilterBar({
    required this.searchController,
    required this.selectedType,
    required this.onSearch,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'Search by title...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onSubmitted: onSearch,
              onChanged: (v) {
                if (v.isEmpty) onSearch('');
              },
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String>(
            value: selectedType,
            underline: const SizedBox.shrink(),
            isDense: true,
            items: _addictionTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => onTypeChanged(v!),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              letterSpacing: 1.1,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}

class _PostCard extends StatefulWidget {
  final Post post;
  final LocalUser localUser;
  final bool isFeatured;
  final bool canFeature;
  final void Function(Post post, bool feature) onFeatureToggle;

  const _PostCard({
    required this.post,
    required this.localUser,
    required this.isFeatured,
    required this.canFeature,
    required this.onFeatureToggle,
  });

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excerpt = widget.post.content.length > 160
        ? '${widget.post.content.substring(0, 160).trimRight()}...'
        : widget.post.content;

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(
              post: widget.post, localUser: widget.localUser),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (widget.post.addictionType.isNotEmpty)
                  Text(
                    widget.post.addictionType.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      letterSpacing: 1.1,
                    ),
                  ),
                if (widget.isFeatured) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.star,
                      size: 13, color: theme.colorScheme.secondary),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Text(
              widget.post.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              excerpt,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Text(widget.post.authorAlias,
                    style: theme.textTheme.labelSmall),
                const Spacer(),
                if (widget.canFeature)
                  _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : GestureDetector(
                          onTap: () async {
                            setState(() => _busy = true);
                            await Future.microtask(() =>
                                widget.onFeatureToggle(
                                    widget.post, !widget.isFeatured));
                            if (mounted) setState(() => _busy = false);
                          },
                          child: Row(
                            children: [
                              Icon(
                                widget.isFeatured
                                    ? Icons.star
                                    : Icons.star_outline,
                                size: 14,
                                color: theme.colorScheme.secondary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                widget.isFeatured
                                    ? 'Unfeature'
                                    : 'Feature this week',
                                style: theme.textTheme.labelSmall?.copyWith(
                                    color: theme.colorScheme.secondary),
                              ),
                            ],
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
