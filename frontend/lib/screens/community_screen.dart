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
    setState(() { _loading = true; _error = null; });
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

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => _FilterSheet(
        selectedType: _addictionTypeFilter,
        titleFilter: _titleFilter,
        onApply: (type, title) {
          setState(() {
            _addictionTypeFilter = type;
            _titleFilter = title;
          });
          _load();
        },
      ),
    );
  }

  bool get _isFiltered =>
      _addictionTypeFilter != 'All' || _titleFilter.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final canWrite = _canPost.contains(widget.localUser.rank);
    final canFeatureUser = _canFeature.contains(widget.localUser.rank);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Stories'),
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _isFiltered,
              child: const Icon(Icons.filter_list),
            ),
            tooltip: 'Filter',
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      floatingActionButton: canWrite
          ? FloatingActionButton.extended(
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
            )
          : null,
      body: _buildBody(canFeatureUser),
    );
  }

  Widget _buildBody(bool canFeatureUser) {
    if (_loading) return const Center(child: CircularProgressIndicator());

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

    if (_posts.isEmpty) {
      return const Center(child: Text('No stories yet. Check back soon.'));
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        children: [
          if (featured.isNotEmpty) ...[
            _SectionHeader(label: 'Featured This Week'),
            ...featured.map((p) => _PostRow(
                  post: p,
                  localUser: widget.localUser,
                  isFeatured: true,
                  canFeature: canFeatureUser,
                  onFeatureToggle: _onFeatureToggle,
                )),
            const Divider(height: 1),
          ],
          if (rest.isNotEmpty) ...[
            if (featured.isNotEmpty) _SectionHeader(label: 'All Stories'),
            ...rest.map((p) => _PostRow(
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

// ── Filter bottom sheet ────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final String selectedType;
  final String titleFilter;
  final void Function(String type, String title) onApply;

  const _FilterSheet({
    required this.selectedType,
    required this.titleFilter,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String _type;
  late TextEditingController _titleController;

  @override
  void initState() {
    super.initState();
    _type = widget.selectedType;
    _titleController = TextEditingController(text: widget.titleFilter);
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Filter stories',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 20),
          Text('Addiction type',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            items: _addictionTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (v) => setState(() => _type = v!),
          ),
          const SizedBox(height: 16),
          Text('Search by title',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              hintText: 'e.g. recovery, hope...',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    widget.onApply('All', '');
                    Navigator.pop(context);
                  },
                  child: const Text('Clear'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    widget.onApply(_type, _titleController.text.trim());
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Section header ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
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

// ── Post row ───────────────────────────────────────────────────────────────────

class _PostRow extends StatelessWidget {
  final Post post;
  final LocalUser localUser;
  final bool isFeatured;
  final bool canFeature;
  final void Function(Post, bool) onFeatureToggle;

  const _PostRow({
    required this.post,
    required this.localUser,
    required this.isFeatured,
    required this.canFeature,
    required this.onFeatureToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PostDetailScreen(post: post, localUser: localUser),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (post.addictionType.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      post.addictionType,
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ],
                ],
              ),
            ),
            if (canFeature)
              IconButton(
                icon: Icon(
                  isFeatured ? Icons.star : Icons.star_border,
                  size: 20,
                  color: isFeatured
                      ? theme.colorScheme.secondary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                tooltip: isFeatured ? 'Unfeature' : 'Feature',
                visualDensity: VisualDensity.compact,
                onPressed: () => onFeatureToggle(post, !isFeatured),
              )
            else if (isFeatured)
              Icon(Icons.star, size: 16, color: theme.colorScheme.secondary),
          ],
        ),
      ),
    );
  }
}
