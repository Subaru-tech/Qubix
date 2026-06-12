import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/router.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _obscurePassword = true;

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      setState(() => _error = 'Please fill in all required fields');
      return;
    }
    if (_passwordController.text.length < 8) {
      setState(() => _error = 'Password must be at least 8 characters');
      return;
    }

    setState(() { _isLoading = true; _error = null; });

    try {
      final dio = ref.read(dioProvider);
      final response = await dio.post(AppConstants.pathRegister, data: {
        'email': _emailController.text.trim(),
        'password': _passwordController.text,
        if (_nameController.text.isNotEmpty) 'displayName': _nameController.text.trim(),
      });

      final token = response.data['token'] as String;
      final user = response.data['user'] as Map<String, dynamic>;

      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setString(AppConstants.keyAuthToken, token);
      await prefs.setString(AppConstants.keyUserId, user['id'] as String);
      await prefs.setString(AppConstants.keyUserEmail, user['email'] as String);

      ref.read(authTokenProvider.notifier).update(token);

      if (mounted) context.go(Routes.chatList);
    } catch (e) {
      setState(() => _error = 'Registration failed. Email may already be in use.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
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
              Text('Create Account', style: QubixTypography.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Set up your Qubix developer console',
                style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _nameController,
                style: QubixTypography.bodyLarge,
                decoration: const InputDecoration(
                  labelText: 'Display Name (optional)',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
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
                  labelText: 'Password (min 8 chars)',
                  prefixIcon: const Icon(Icons.lock_outlined),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: QubixTypography.bodySmall.copyWith(color: QubixColors.error)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Create Account'),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => context.go(Routes.login),
                  child: RichText(
                    text: TextSpan(
                      text: 'Already have an account? ',
                      style: QubixTypography.bodySmall,
                      children: [
                        TextSpan(
                          text: 'Sign In',
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
            ],
          ),
        ),
      ),
    );
  }
}
