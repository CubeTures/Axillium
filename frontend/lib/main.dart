import 'package:flutter/material.dart';
import 'models/local_user.dart';
import 'screens/chat_screen.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'services/local_storage_service.dart';
import 'services/risk_detection_service.dart';

void main() {
  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  LocalUser? _user;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await LocalStorageService().getUser();
    setState(() {
      _user = user;
      _initialized = true;
    });
  }

  void _onAuthenticated(LocalUser user) => setState(() => _user = user);

  void _onLogout() => setState(() => _user = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axillium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEF7068),
        ),
        useMaterial3: true,
      ),
      home: !_initialized
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _user == null
              ? OnboardingScreen(onComplete: _onAuthenticated)
              : MainScreen(
                  user: _user!,
                  onUserUpdated: _onAuthenticated,
                  onLogout: _onLogout,
                ),
    );
  }
}

class MainScreen extends StatefulWidget {
  final LocalUser user;
  final void Function(LocalUser) onUserUpdated;
  final VoidCallback onLogout;

  const MainScreen({
    super.key,
    required this.user,
    required this.onUserUpdated,
    required this.onLogout,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  String? _riskWarning;
  final _riskService = RiskDetectionService();

  static const _icons = [
    (outline: Icons.home_outlined,          filled: Icons.home_rounded),
    (outline: Icons.chat_bubble_outline,    filled: Icons.chat_bubble),
    (outline: Icons.group_outlined,          filled: Icons.group),
    (outline: Icons.notifications_outlined, filled: Icons.notifications),
    (outline: Icons.person_outline,         filled: Icons.person),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Delay slightly so the UI is settled before running checks
    Future.delayed(const Duration(seconds: 2), _runRiskCheck);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _runRiskCheck();
  }

  Future<void> _runRiskCheck() async {
    final user = widget.user;
    if (!mounted) return;
    if (user.userId == null) return;
    if (user.sponsorId == null) return; // no sponsor — nobody to alert
    final addictionType = user.addictionType;
    if (addictionType == null || addictionType.isEmpty) return;

    final riskType =
        await _riskService.runDetection(user.userId!, addictionType);
    if (!mounted || riskType == null) return;

    if (riskType == 'needs_usage_permission') {
      _showUsagePermissionDialog();
      return;
    }

    final msg = switch (riskType) {
      'gambling_app' =>
        'We noticed you opened Kalshi. Your sponsor has been notified. You\'ve got this.',
      'bar_location' =>
        'We noticed you may be near a bar. Your sponsor has been notified. Reach out if you need support.',
      _ => 'Your sponsor has been notified. Reach out if you need support.',
    };
    setState(() => _riskWarning = msg);
  }

  Future<void> _showUsagePermissionDialog() async {
    if (!mounted) return;
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('One permission needed'),
        content: const Text(
          'To alert your sponsor if you open a gambling app, '
          'Axillium needs Usage Access. '
          'You\'ll be taken to Settings — enable Axillium in the list.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    if (go == true) await _riskService.requestUsagePermission();
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return HomeScreen(
          user: widget.user,
          onNavigate: (i) => setState(() => _selectedIndex = i),
          onUserUpdated: widget.onUserUpdated,
        );
      case 1:
        return ChatScreen(user: widget.user);
      case 2:
        return CommunityScreen(localUser: widget.user);
      case 3:
        return NotificationsScreen(user: widget.user);
      case 4:
        return ProfileScreen(
          user: widget.user,
          onRankedUp: widget.onUserUpdated,
          onLogout: widget.onLogout,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          _buildTab(_selectedIndex),
          if (_riskWarning != null)
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: _RiskWarningBanner(
                message: _riskWarning!,
                onDismiss: () => setState(() => _riskWarning = null),
              ),
            ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: cs.surfaceContainer,
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.10),
                  blurRadius: 20,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_icons.length, (i) {
                final selected = _selectedIndex == i;
                return _NavItem(
                  icon: selected ? _icons[i].filled : _icons[i].outline,
                  selected: selected,
                  onTap: () => setState(() => _selectedIndex = i),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Risk warning banner ────────────────────────────────────────────────────────

class _RiskWarningBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _RiskWarningBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded,
                color: cs.onErrorContainer, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onErrorContainer),
              ),
            ),
            IconButton(
              icon: Icon(Icons.close, size: 18, color: cs.onErrorContainer),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: onDismiss,
            ),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(
          icon,
          size: 22,
          color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
        ),
      ),
    );
  }
}
