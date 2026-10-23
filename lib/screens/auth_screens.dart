import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firebase_service.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isRegister = false;
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              primaryColor.withValues(alpha: isDark ? 0.16 : 0.08),
              isDark ? const Color(0xFF0A0A0C) : Colors.white,
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              Container(
                height: 150,
                width: 150,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kBrandGradient[0].withValues(alpha: 0.18), kBrandGradient[2].withValues(alpha: 0.10)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(36),
                  boxShadow: [
                    BoxShadow(color: kBrandGradient[0].withValues(alpha: 0.18), blurRadius: 24, offset: const Offset(0, 10)),
                  ],
                ),
                child: Icon(Icons.checklist_rtl, size: 76, color: primaryColor),
              ),
              const SizedBox(height: 36),
              Text(
                _isRegister ? 'Create Account 🚀' : 'Welcome Back 👋',
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                _isRegister ? 'Sign up to get started' : 'Sign in to continue',
                style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              ),
              const SizedBox(height: 36),
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
                const SizedBox(height: 28),
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('OR', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey[400], letterSpacing: 1.5)),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                if (_isRegister) ...[
                  _field(_nameController, 'Full name', Icons.person_outline_rounded, isDark),
                  const SizedBox(height: 14),
                ],
                _field(_emailController, 'Email', Icons.mail_outline_rounded, isDark, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 14),
                _field(_passwordController, 'Password', Icons.lock_outline_rounded, isDark, obscure: true),
                const SizedBox(height: 22),
                PrimaryButton(
                  text: _isRegister ? 'Create Account' : 'Sign In',
                  onPressed: () => _handleEmailAuth(authService),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _isRegister = !_isRegister),
                  child: Text(
                    _isRegister ? 'Already have an account? Sign in' : 'New here? Create an account',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              Text(
                'By continuing, you agree to Terms & Privacy Policy',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String hint, IconData icon, bool isDark, {bool obscure = false, TextInputType? keyboardType}) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(fontSize: 15, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 15),
        prefixIcon: Icon(icon, size: 20, color: isDark ? Colors.white38 : Colors.black38),
        filled: true,
        fillColor: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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

  Future<void> _handleEmailAuth(AuthService authService) async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty || (_isRegister && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill in all fields')));
      return;
    }
    if (_isRegister && password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password must be at least 6 characters')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final user = _isRegister
          ? await authService.registerWithEmail(email, password, name)
          : await authService.signInWithEmail(email, password);
      if (user != null && mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
