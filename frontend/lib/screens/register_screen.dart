import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/local_storage_service.dart';

class RegisterScreen extends StatefulWidget {
  final String currentAlias;
  final String? message; // shown at top when registration is required for a reason

  const RegisterScreen({super.key, required this.currentAlias, this.message});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _aliasController;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(text: widget.currentAlias == 'Anonymous' ? '' : widget.currentAlias);
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final alias = _aliasController.text.trim().isEmpty ? 'Anonymous' : _aliasController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text;

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone number and password are required.')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final groupId = await LocalStorageService().getGroupId();
      final apiUser = await AuthService().register(phone, password, alias, groupId: groupId ?? 0);
      final localUser = await LocalStorageService().saveRegistration(
        apiUser.id, apiUser.alias,
        groupId: apiUser.groupId > 0 ? apiUser.groupId : null,
        role: apiUser.role,
      );
      if (mounted) Navigator.pop(context, localUser);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Become an Apprentice')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.message != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.message!,
                  style: TextStyle(color: Theme.of(context).colorScheme.onPrimaryContainer),
                ),
              ),
              const SizedBox(height: 24),
            ],
            Text(
              'Finalise your alias',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Your phone number is used only to log in — it is never shared with anyone.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _aliasController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Alias',
                hintText: 'Anonymous',
                helperText: 'This is the only name others will ever see.',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _loading ? null : _register,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
