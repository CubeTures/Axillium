import 'package:flutter/material.dart';
import 'models/local_user.dart';
import 'screens/chat_screen.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/profile_screen.dart';
import 'services/local_storage_service.dart';

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

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  static const _icons = [
    (outline: Icons.home_outlined,          filled: Icons.home_rounded),
    (outline: Icons.chat_bubble_outline,    filled: Icons.chat_bubble),
    (outline: Icons.group_outlined,          filled: Icons.group),
    (outline: Icons.notifications_outlined, filled: Icons.notifications),
    (outline: Icons.person_outline,         filled: Icons.person),
  ];

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
      body: _buildTab(_selectedIndex),
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
