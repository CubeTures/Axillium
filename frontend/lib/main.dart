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
  late final Future<LocalUser?> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = LocalStorageService().getUser();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axillium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: FutureBuilder<LocalUser?>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data == null) {
            return OnboardingScreen(
              onComplete: (user) => _launch(context, user),
            );
          }
          return MainScreen(initialUser: snapshot.data!);
        },
      ),
    );
  }

  void _launch(BuildContext context, LocalUser user) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialUser: user)),
    );
  }
}

class MainScreen extends StatefulWidget {
  final LocalUser initialUser;

  const MainScreen({super.key, required this.initialUser});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late LocalUser _user;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.initialUser;
  }

  Widget _buildTab(int index) {
    switch (index) {
      case 0:
        return const HomeScreen();
      case 1:
        return ChatScreen(
          groupId: 1,
          userId: _user.userId ?? 0,
          alias: _user.alias,
        );
      case 2:
        return const CommunityScreen();
      case 3:
        return ProfileScreen(
          user: _user,
          onRankedUp: (updated) => setState(() => _user = updated),
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
