import 'package:flutter/material.dart';
import '../models/local_user.dart';
import '../services/local_storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  final void Function(LocalUser user) onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _aliasController = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    setState(() => _loading = true);
    final user = await LocalStorageService()
        .completeOnboarding(_aliasController.text);
    widget.onComplete(user);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Text(
                'Welcome',
                style: Theme.of(context).textTheme.displaySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'What should we call you?',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'This is your alias — the only name others will see. You can leave it blank to stay anonymous.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _aliasController,
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Alias (optional)',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _continue(),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _continue,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Continue'),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}
