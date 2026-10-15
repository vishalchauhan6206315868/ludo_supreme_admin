import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme.dart';
import 'shell.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final url = TextEditingController(text: ApiService.baseUrl);
  final email = TextEditingController();
  final pass = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    url.dispose();
    email.dispose();
    pass.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final e = email.text.trim();
    final p = pass.text;
    if (e.isEmpty || p.isEmpty) {
      setState(() => error = 'Please enter both email and password');
      return;
    }

    setState(() {
      loading = true;
      error = null;
    });
    try {
      await ApiService.login(url.text.trim(), e, p);
      await ApiService.fetchProfile();
      if (!mounted) return;
      _go();
    } catch (err) {
      if (mounted) setState(() => error = '$err');
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _go() => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const Shell()),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNavy,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'assets/icons/admin_logo.png',
                  width: 72,
                  height: 72,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 14),
              const Text.rich(
                TextSpan(children: [
                  TextSpan(text: 'Ludo', style: TextStyle(color: kNavy)),
                  TextSpan(text: 'Supreme', style: TextStyle(color: kBlue)),
                ]),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('ADMIN PANEL', style: TextStyle(letterSpacing: 3, color: Colors.grey)),
              const SizedBox(height: 24),
              TextField(
                controller: url,
                decoration: const InputDecoration(
                  labelText: 'API Base URL',
                  hintText: 'http://192.168.1.20:4000/api',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pass,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                onSubmitted: (_) => _login(),
              ),
              if (error != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: kRed.withValues(alpha: 0.3)),
                  ),
                  child: Text(error!, style: const TextStyle(color: kRed, fontSize: 13)),
                ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: loading ? null : _login,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Login to Dashboard', style: TextStyle(fontSize: 15)),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: loading
                    ? null
                    : () {
                        ApiService.enterDemo();
                        _go();
                      },
                child: const Text('Demo Mode (Explore without backend)'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
