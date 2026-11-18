import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _name = TextEditingController();
  bool _register = false;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final auth = FirebaseAuth.instance;
      if (_register) {
        final cred = await auth.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
        // Everyone who registers here is a student. Admins are set by hand in Firestore.
        await FirebaseFirestore.instance.collection('users').doc(cred.user!.uid).set({
          'name': _name.text.trim(),
          'email': _email.text.trim(),
          'role': 'student',
        });
      } else {
        await auth.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _pass.text,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_library, size: 72),
                  const SizedBox(height: 12),
                  const Text('Smart Library',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 28),
                  if (_register) ...[
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                          labelText: 'Full name', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                        labelText: 'Email', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _pass,
                    obscureText: true,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                        labelText: 'Password (min 6 characters)',
                        border: OutlineInputBorder()),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(_busy
                            ? 'Please wait...'
                            : (_register ? 'Create account' : 'Login')),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _register = !_register;
                      _error = null;
                    }),
                    child: Text(_register
                        ? 'Already have an account? Login'
                        : 'New student? Create account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
