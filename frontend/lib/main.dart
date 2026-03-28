import 'package:flutter/material.dart';
import 'models/local_user.dart';
import 'screens/chat_screen.dart';
import 'screens/community_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
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

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return ChatScreen(
          groupId: 1,
          userId: widget.user.userId ?? 0,
          alias: widget.user.alias,
        );
      case 2:
        return const CommunityScreen();
      case 3:
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
    return Scaffold(
      body: _buildTab(_selectedIndex),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Community'),
          NavigationDestination(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}
