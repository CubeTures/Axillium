import 'package:flutter/material.dart';
import 'screens/chat_screen.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Axillium',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const ChatScreen(
        groupId: 1,
        userId: 1,
        alias: 'Me',
      ),
    );
  }
}
