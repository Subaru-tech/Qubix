import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/router.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all fields');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(AppConstants.pathLogin, data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
      });

      final token = response.data['token'] as String;
      final user = response.data['user'] as Map<String, dynamic>;

      // Save auth data
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(AppConstants.keyAuthToken, token);
      await prefs.setString(AppConstants.keyUserId, user['id'] as String);
      await prefs.setString(AppConstants.keyUserEmail, user['email'] as String);
      if (user['displayName'] != null) {
        await prefs.setString(AppConstants.keyUserDisplayName, user['displayName'] as String);
      }

      // Update providers
      ref.read(authTokenProvider.notifier).update(token);

      if (mounted) context.go(Routes.chatList);
    } catch (e) {
      setState(() => _error = 'Invalid email or password');
    } finally {
      setState(() => _isLoading = false);
    }
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
      backgroundColor: QubixColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              // Logo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [QubixColors.primary, QubixColors.accent],
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.hub_outlined, size: 32, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text('Welcome back', style: QubixTypography.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Sign in to your Qubix console',
                style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _emailController,
                style: QubixTypography.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                style: QubixTypography.bodyLarge,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _login(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: QubixTypography.bodySmall.copyWith(color: QubixColors.error)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Sign In'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Routes.register),
                  child: RichText(
                    text: TextSpan(
                      text: "Don't have an account? ",
                      style: QubixTypography.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Sign Up',
                          style: QubixTypography.bodySmall.copyWith(
                            color: QubixColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Routes.serverConfig),
                  child: Text(
                    'Change server',
                    style: QubixTypography.bodySmall.copyWith(color: QubixColors.textTertiary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
