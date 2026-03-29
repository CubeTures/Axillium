import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/auth_service.dart';
import '../services/local_storage_service.dart';

class RegisterScreen extends StatefulWidget {
  final String currentAlias;
  final String? message;

  const RegisterScreen({super.key, required this.currentAlias, this.message});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  late final TextEditingController _aliasController;
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _loading = false;
  int _step = 0; // 0 = credentials, 1 = photo
  int? _newUserId;
  String? _newAlias;

  @override
  void initState() {
    super.initState();
    _aliasController = TextEditingController(
      text: widget.currentAlias == 'Anonymous' ? '' : widget.currentAlias,
    );
  }

  @override
  void dispose() {
    _aliasController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final alias = _aliasController.text.trim().isEmpty
        ? 'Anonymous'
        : _aliasController.text.trim();
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
      final apiUser = await AuthService()
          .register(phone, password, alias, groupId: groupId ?? 0);
      _newUserId = apiUser.id;
      _newAlias = apiUser.alias;
      if (mounted) setState(() { _loading = false; _step = 1; });
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  Future<void> _finish({String? profilePicture}) async {
    final groupId = await LocalStorageService().getGroupId();
    final localUser = await LocalStorageService().saveRegistration(
      _newUserId!,
      _newAlias!,
      groupId: groupId,
      role: 'apprentice',
      profilePicture: profilePicture,
    );
    if (mounted) Navigator.pop(context, localUser);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Become an Apprentice'),
        leading: _step == 1
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = 0),
              )
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _step == 0
            ? _CredentialsStep(
                key: const ValueKey(0),
                aliasController: _aliasController,
                phoneController: _phoneController,
                passwordController: _passwordController,
                loading: _loading,
                message: widget.message,
                onSubmit: _register,
              )
            : _PhotoStep(
                key: const ValueKey(1),
                userId: _newUserId!,
                onFinish: _finish,
              ),
      ),
    );
  }
}

// ── Step 1: credentials ────────────────────────────────────────────────────────

class _CredentialsStep extends StatelessWidget {
  final TextEditingController aliasController;
  final TextEditingController phoneController;
  final TextEditingController passwordController;
  final bool loading;
  final String? message;
  final VoidCallback onSubmit;

  const _CredentialsStep({
    super.key,
    required this.aliasController,
    required this.phoneController,
    required this.passwordController,
    required this.loading,
    required this.onSubmit,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (message != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(message!,
                  style: TextStyle(color: cs.onPrimaryContainer)),
            ),
            const SizedBox(height: 24),
          ],
          Text('Finalise your alias', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Your phone number is used only to log in — it is never shared with anyone.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          TextField(
            controller: aliasController,
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
            controller: phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone number',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Continue'),
          ),
        ],
      ),
    );
  }
}

// ── Step 2: profile photo ──────────────────────────────────────────────────────

class _PhotoStep extends StatefulWidget {
  final int userId;
  final Future<void> Function({String? profilePicture}) onFinish;

  const _PhotoStep({super.key, required this.userId, required this.onFinish});

  @override
  State<_PhotoStep> createState() => _PhotoStepState();
}

class _PhotoStepState extends State<_PhotoStep> {
  final _picker = ImagePicker();
  File? _image;
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _image = File(picked.path));
  }

  Future<void> _upload() async {
    if (_image == null) return;
    setState(() => _uploading = true);
    try {
      final bytes = await _image!.readAsBytes();
      final ext = _image!.path.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      final dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      await AuthService().uploadProfilePicture(widget.userId, dataUrl);
      if (mounted) await widget.onFinish(profilePicture: dataUrl);
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Add a profile photo', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(
            'Only your group members and sponsor will see this. You can skip it for now.',
            style:
                theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 40),
          Center(
            child: GestureDetector(
              onTap: () => _pick(ImageSource.gallery),
              child: CircleAvatar(
                radius: 72,
                backgroundColor: cs.surfaceContainerHigh,
                backgroundImage:
                    _image != null ? FileImage(_image!) : null,
                child: _image == null
                    ? Icon(Icons.add_a_photo_outlined,
                        size: 36, color: cs.onSurfaceVariant)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _uploading ? null : () => _pick(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
              ),
            ],
          ),
          const SizedBox(height: 40),
          FilledButton(
            onPressed: _uploading || _image == null ? null : _upload,
            child: _uploading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save photo'),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _uploading ? null : () => widget.onFinish(),
            child: const Text('Skip for now'),
          ),
        ],
      ),
    );
  }
}
