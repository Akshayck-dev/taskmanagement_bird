import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                height: 180,
                width: 180,
                decoration: BoxDecoration(
                  color: const Color(0xFF6C63FF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.checklist_rtl, size: 90, color: Color(0xFF6C63FF)),
              ),
              const SizedBox(height: 48),
              const Text('Welcome Back 👋', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Sign in to continue', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
              const SizedBox(height: 48),
              if (_isLoading)
                const CircularProgressIndicator()
              else ...[
                PrimaryButton(
                  text: 'Continue with Google',
                  gradientColors: [Colors.white, Colors.white],
                  textColor: Colors.black87,
                  icon: Image.network(
                    'https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/1200px-Google_%22G%22_logo.svg.png', 
                    height: 20,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.login, size: 20, color: Colors.black87),
                  ),
                  onPressed: () => _handleGoogleLogin(authService),
                ),
                const SizedBox(height: 40),
                _buildTesterSection(authService),
              ],
              const Spacer(),
              Text(
                'By continuing, you agree to Terms & Privacy Policy',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleGoogleLogin(AuthService authService) async {
    setState(() => _isLoading = true);
    try {
      final user = await authService.signInWithGoogle();
      if (user != null && mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildTesterSection(AuthService authService) {
    return Column(
      children: [
        Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('TESTER DEMO ACCOUNTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
            ),
            const Expanded(child: Divider()),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 90,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 8,
            itemBuilder: (context, index) {
              final testerId = index + 1;
              final name = 'Tester $testerId';
              return GestureDetector(
                onTap: () => _handleTesterLogin(authService, testerId, name),
                child: Container(
                  width: 70,
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: const Color(0xFF6C63FF).withOpacity(0.1),
                        child: Text('$testerId', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6C63FF))),
                      ),
                      const SizedBox(height: 6),
                      Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _handleTesterLogin(AuthService auth, int id, String name) async {
    setState(() => _isLoading = true);
    final email = 'tester$id@taskflow.com';
    const password = 'password123';
    
    try {
      // 1. Try to sign in
      User? user;
      try {
        user = await auth.signInWithEmail(email, password);
      } catch (e) {
        // 2. If fails, try to register
        user = await auth.registerWithEmail(email, password, name);
      }

      if (user != null && mounted) {
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Demo Login Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
