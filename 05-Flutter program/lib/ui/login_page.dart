import 'package:flutter/material.dart';

import '../auth/cognito_auth.dart';
import '../config/app_config.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.onLoggedIn});

  final void Function(CognitoSession session) onLoggedIn;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = CognitoAuth();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  bool _registerMode = false;
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    if (!AppConfig.isConfigured) {
      setState(() => _error = 'Set AppConfig values after sam deploy.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final session = _registerMode
          ? await _auth.register(
              _nameCtrl.text.trim(),
              _emailCtrl.text.trim(),
              _passwordCtrl.text,
            )
          : await _auth.login(
              _emailCtrl.text.trim(),
              _passwordCtrl.text,
            );
      widget.onLoggedIn(session);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WalkEEG Cloud')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _registerMode ? 'Create account' : 'Sign in',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            if (_registerMode)
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            TextField(
              controller: _passwordCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: Colors.redAccent)),
            ],
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: Text(_loading
                  ? 'Please wait…'
                  : (_registerMode ? 'Register' : 'Sign in')),
            ),
            TextButton(
              onPressed: _loading
                  ? null
                  : () => setState(() => _registerMode = !_registerMode),
              child: Text(_registerMode
                  ? 'Already have an account? Sign in'
                  : 'Need an account? Register'),
            ),
          ],
        ),
      ),
    );
  }
}
