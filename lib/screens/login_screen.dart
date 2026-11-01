import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/common_widgets.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authService = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _submitting = false;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showError('Email aur password dono bharo');
      return;
    }
    setState(() => _submitting = true);
    try {
      await _authService.signIn(email: email, password: password);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } on AuthException catch (e) {
      _showError(e.message);
    } catch (_) {
      _showError('Kuch galat ho gaya, dobara try karo');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showError('Pehle apna email daalo, phir "Forgot Password?" dabao');
      return;
    }
    try {
      await _authService.sendPasswordReset(email);
      if (!mounted) return;
      _showError('Password reset link $email pe bhej diya');
    } on AuthException catch (e) {
      _showError(e.message);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _comingSoon(String provider) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$provider login jald aa raha hai')),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.goldGradient,
                  ),
                  child:ClipRRect(
                      borderRadius: BorderRadius.circular(18.0),
                      child: Image.asset("assets/icon/logo.png",
                          errorBuilder: (_, __, ___) => const Icon(Icons.diamond_outlined, color: AppColors.black, size: 30))),
                ),
              ),
              const SizedBox(height: 18),
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 40, height: 1, color: AppColors.gold.withOpacity(0.5)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.diamond_outlined, size: 10, color: AppColors.goldDark),
                    ),
                    Container(width: 40, height: 1, color: AppColors.gold.withOpacity(0.5)),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Center(
                child: Text(
                  'Welcome Back',
                  style: AppText.heading.copyWith(color: AppColors.black, fontSize: 24),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Sign in to continue to your account',
                  style: AppText.bodyMuted.copyWith(color: Colors.black54),
                ),
              ),
              const SizedBox(height: 30),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.gold.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 15, offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  children: [
                    _LightTextField(
                      hint: 'Email',
                      icon: Icons.person_outline,
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    _LightTextField(
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscure: _obscure,
                      controller: _passwordController,
                      suffix: IconButton(
                        icon: Icon(
                          _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: AppColors.goldDark,
                          size: 20,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _forgotPassword,
                        child: Text('Forgot Password?', style: TextStyle(color: AppColors.goldDark, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    GoldButton(
                      label: _submitting ? 'Logging in...' : 'Login',
                      onTap: _submitting ? null : _login,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(child: Container(height: 1, color: AppColors.gold.withOpacity(0.3))),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                  Expanded(child: Container(height: 1, color: AppColors.gold.withOpacity(0.3))),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _LightOutlineButton(
                      label: 'Continue with Google',
                      icon: const Text('G', style: TextStyle(color: AppColors.goldDark, fontWeight: FontWeight.w700)),
                      onTap: () => _comingSoon('Google'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _LightOutlineButton(
                      label: 'Continue with Apple',
                      icon: const Icon(Icons.apple, color: AppColors.goldDark, size: 18),
                      onTap: () => _comingSoon('Apple'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                  ),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.black54, fontSize: 13),
                      children: [
                        const TextSpan(text: 'New to Surpatne Jewellers? '),
                        TextSpan(
                          text: 'Create Account',
                          style: TextStyle(color: AppColors.goldDark, fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

/// Text field styled for the light/cream background — GoldTextField in
/// common_widgets.dart uses light-colored text meant for dark screens,
/// so it's invisible here.
class _LightTextField extends StatelessWidget {
  final String hint;
  final IconData icon;
  final bool obscure;
  final Widget? suffix;
  final TextEditingController? controller;
  final TextInputType? keyboardType;

  const _LightTextField({
    required this.hint,
    required this.icon,
    this.obscure = false,
    this.suffix,
    this.controller,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: const TextStyle(color: AppColors.black, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Colors.black38),
        prefixIcon: Icon(icon, color: AppColors.goldDark, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: AppColors.cream,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: const BorderSide(color: AppColors.gold, width: 1.4),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColors.gold.withOpacity(0.4)),
        ),
      ),
    );
  }
}

/// Outline button styled for the light background.
class _LightOutlineButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback? onTap;

  const _LightOutlineButton({required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 50,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.gold.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            icon,
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.black, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}