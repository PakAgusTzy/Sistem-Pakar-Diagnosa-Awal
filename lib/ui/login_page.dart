// ui/login_page.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 120, 20, 32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cs.primary, cs.secondaryContainer],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(28), bottomRight: Radius.circular(28),
              ),
            ),
            child: Column(
              children: const [
                Icon(Icons.medical_information, size: 84, color: Colors.white),
                SizedBox(height: 12),
                Text('Sistem Pakar Diagnosa',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                SizedBox(height: 4),
                Text('Masuk untuk mulai mendiagnosa', style: TextStyle(color: Colors.white70)),
              ],
            ),
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity, height: 56,
              child: FilledButton.icon(
                icon: const Icon(Icons.login),
                label: const Text('Masuk dengan Google'),
                onPressed: () async {
                  try { await authService.signInWithGoogle(); }
                  catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Gagal login: $e')));
                    }
                  }
                },
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
