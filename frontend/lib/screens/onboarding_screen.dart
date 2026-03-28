import 'package:flutter/material.dart';
import '../models/group.dart';
import '../models/local_user.dart';
import '../services/groups_service.dart';
import '../services/local_storage_service.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class OnboardingScreen extends StatefulWidget {
  final void Function(LocalUser user) onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _aliasController = TextEditingController();
  final _locationController = TextEditingController();
  final _customAddictionController = TextEditingController();

  List<Group> _foundGroups = [];
  String? _selectedAddictionType;
  int? _selectedGroupId;
  bool _isLeader = false;
  bool _locationSearching = false;
  bool _finishing = false;
  int _currentPage = 0;
  LocalUser? _registeredUser; // set when leader registers mid-onboarding

  @override
  void dispose() {
    _pageController.dispose();
    _aliasController.dispose();
    _locationController.dispose();
    _customAddictionController.dispose();
    super.dispose();
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _searchLocation() async {
    final location = _locationController.text.trim();
    if (location.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your location to continue.')),
      );
      return;
    }
    setState(() => _locationSearching = true);
    try {
      final groups = await GroupsService().getGroupsByLocation(location);
      setState(() => _foundGroups = groups);
    } catch (_) {
      setState(() => _foundGroups = []);
    } finally {
      setState(() => _locationSearching = false);
      _nextPage();
    }
  }

  void _onSelectAddictionType(String type) {
    final idx = _foundGroups.indexWhere((g) => g.addictionType == type);
    setState(() {
      _selectedAddictionType = type;
      _selectedGroupId = idx >= 0 ? _foundGroups[idx].id : null;
      _isLeader = false;
      _customAddictionController.clear();
    });
  }

  void _onCustomAddictionChanged(String value) {
    setState(() {
      if (value.trim().isNotEmpty) {
        _selectedAddictionType = null;
        _selectedGroupId = null;
        _isLeader = true;
      } else {
        _isLeader = false;
      }
    });
  }

  Future<void> _onAddictionContinue() async {
    if (_isLeader) {
      final customText = _customAddictionController.text.trim();
      // Persist location + community data before registration so saveRegistration picks it up
      await LocalStorageService().saveLocationAndCommunity(
        location: _locationController.text,
        addictionType: customText.isNotEmpty ? customText : null,
        isLeader: true,
      );
      if (!mounted) return;
      final registered = await Navigator.push<LocalUser>(
        context,
        MaterialPageRoute(
          builder: (_) => RegisterScreen(
            currentAlias: _aliasController.text,
            message: 'Group leaders need an account — leaders cannot remain anonymous.',
          ),
        ),
      );
      if (registered != null) {
        setState(() => _registeredUser = registered);
        _nextPage();
      }
      // If they dismiss without registering, stay on the addiction page
    } else {
      _nextPage();
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);

    // Leader already registered mid-onboarding — nothing left to save
    if (_registeredUser != null) {
      widget.onComplete(_registeredUser!);
      return;
    }

    final customText = _customAddictionController.text.trim();
    final addiction = _selectedAddictionType ?? (customText.isNotEmpty ? customText : null);
    final user = await LocalStorageService().completeOnboarding(
      alias: _aliasController.text,
      location: _locationController.text,
      addictionType: addiction,
      groupId: _selectedGroupId,
      isLeader: false,
    );
    widget.onComplete(user);
  }

  Future<void> _openLogin() async {
    final user = await Navigator.push<LocalUser>(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (user != null) widget.onComplete(user);
  }

  List<String> get _uniqueAddictionTypes {
    final seen = <String>{};
    return _foundGroups
        .map((g) => g.addictionType)
        .where((t) => seen.add(t))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _StepIndicator(current: _currentPage, total: 4),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _AliasPage(
                    controller: _aliasController,
                    onContinue: _nextPage,
                    onLogin: _openLogin,
                  ),
                  _LocationPage(
                    controller: _locationController,
                    searching: _locationSearching,
                    onSearch: _searchLocation,
                  ),
                  _AddictionPage(
                    location: _locationController.text.trim(),
                    uniqueTypes: _uniqueAddictionTypes,
                    selectedType: _selectedAddictionType,
                    customController: _customAddictionController,
                    isLeader: _isLeader,
                    onSelectType: _onSelectAddictionType,
                    onCustomChanged: _onCustomAddictionChanged,
                    onContinue: _onAddictionContinue,
                  ),
                  _JourneyPage(
                    loading: _finishing,
                    onStart: _finish,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step indicator ─────────────────────────────────────────────────────────────

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;

  const _StepIndicator({required this.current, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(total, (i) {
          final active = i == current;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: active ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(4),
            ),
          );
        }),
      ),
    );
  }
}

// ── Page 1: Alias ──────────────────────────────────────────────────────────────

class _AliasPage extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onContinue;
  final VoidCallback onLogin;

  const _AliasPage({
    required this.controller,
    required this.onContinue,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Welcome', style: Theme.of(context).textTheme.displaySmall, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('What should we call you?', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Your alias is the only name others will ever see. Leave it blank to stay anonymous.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: controller,
            textAlign: TextAlign.center,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(hintText: 'Alias (optional)', border: OutlineInputBorder()),
            onSubmitted: (_) => onContinue(),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
          const Spacer(flex: 2),
          Center(child: TextButton(onPressed: onLogin, child: const Text('Already registered? Log in'))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Page 2: Location ───────────────────────────────────────────────────────────

class _LocationPage extends StatelessWidget {
  final TextEditingController controller;
  final bool searching;
  final VoidCallback onSearch;

  const _LocationPage({
    required this.controller,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Where are you?', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'We\'ll look up existing support groups in your area. Your location is never shared publicly.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              hintText: 'City or region (optional)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
            onSubmitted: (_) => onSearch(),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: searching ? null : onSearch,
            child: searching
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Find groups'),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ── Page 3: Addiction selection ────────────────────────────────────────────────

class _AddictionPage extends StatelessWidget {
  final String location;
  final List<String> uniqueTypes;
  final String? selectedType;
  final TextEditingController customController;
  final bool isLeader;
  final void Function(String) onSelectType;
  final void Function(String) onCustomChanged;
  final VoidCallback onContinue;

  const _AddictionPage({
    required this.location,
    required this.uniqueTypes,
    required this.selectedType,
    required this.customController,
    required this.isLeader,
    required this.onSelectType,
    required this.onCustomChanged,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final hasResults = uniqueTypes.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 8),
          Text('Find your community', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          if (hasResults) ...[
            Text(
              'These groups exist in ${location.isNotEmpty ? location : 'your area'}. Select the one that fits you.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: uniqueTypes.map((type) {
                return FilterChip(
                  label: Text(type),
                  selected: type == selectedType,
                  onSelected: (_) => onSelectType(type),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            Text("Don't see yours?", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              'Type it below and you\'ll become the leader of a new group.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ] else ...[
            Text(
              location.isNotEmpty
                  ? 'No groups found in $location yet. Type your addiction below to start one — you\'ll be its leader.'
                  : 'Type the addiction you\'d like support with. If no group exists yet, you\'ll become its leader.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: customController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hasResults ? 'Other (e.g. Video games)' : 'E.g. Alcohol, Gambling…',
              border: const OutlineInputBorder(),
              suffixIcon: isLeader
                  ? Tooltip(
                      message: 'You\'ll be the leader of this new group',
                      child: Icon(Icons.star_outline,
                          color: Theme.of(context).colorScheme.primary),
                    )
                  : null,
            ),
            onChanged: onCustomChanged,
          ),
          if (isLeader) ...[
            const SizedBox(height: 8),
            Text(
              'You\'ll be the leader of this new group.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(onPressed: onContinue, child: const Text('Continue')),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Page 4: Journey overview ───────────────────────────────────────────────────

class _JourneyPage extends StatelessWidget {
  final bool loading;
  final VoidCallback onStart;

  const _JourneyPage({required this.loading, required this.onStart});

  static const _tiers = [
    ('Anonymous', 'Observe and learn'),
    ('Apprentice', 'Engage with the community'),
    ('Sponsor', 'Help others on their journey'),
    ('Leader', 'Guide and moderate groups'),
    ('Influencer', 'Inspire through your story'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          Text('Your Journey Ahead', style: Theme.of(context).textTheme.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            "You're starting as Anonymous. There's no pressure to move faster than you're ready.",
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ..._tiers.map((tier) => _TierRow(title: tier.$1, description: tier.$2)),
          const Spacer(),
          FilledButton(
            onPressed: loading ? null : onStart,
            child: loading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Start your journey'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final String title;
  final String description;

  const _TierRow({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('→',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: Theme.of(context).textTheme.bodyMedium,
                children: [
                  TextSpan(text: '$title: ', style: const TextStyle(fontWeight: FontWeight.bold)),
                  TextSpan(text: description),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
