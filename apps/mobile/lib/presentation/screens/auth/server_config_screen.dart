import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/router.dart';

class ServerConfigScreen extends ConsumerStatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  ConsumerState<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends ConsumerState<ServerConfigScreen> {
  final _urlController = TextEditingController(text: AppConstants.defaultServerUrl);
  bool _isChecking = false;
  String? _error;
  bool _isConnected = false;

  Future<void> _checkConnection() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'Please enter a server URL');
      return;
    }

    setState(() { _isChecking = true; _error = null; _isConnected = false; });

    try {
      final dio = Dio(BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: 5),
        receiveTimeout: const Duration(seconds: 5),
      ));
      final response = await dio.get(AppConstants.pathHealth);
      if (response.data['status'] == 'ok') {
        setState(() => _isConnected = true);
      } else {
        setState(() => _error = 'Server responded but health check failed');
      }
    } on DioException catch (e) {
      setState(() => _error = 'Cannot reach server: ${e.message}');
    } catch (e) {
      setState(() => _error = 'Connection failed: $e');
    } finally {
      setState(() => _isChecking = false);
    }
  }

  Future<void> _saveAndContinue() async {
    final url = _urlController.text.trim();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(AppConstants.keyServerUrl, url);
    ref.read(serverUrlProvider.notifier).update(url);
    if (mounted) context.go(Routes.login);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: QubixColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 60),
              Text('Connect Server', style: QubixTypography.displayLarge),
              const SizedBox(height: 8),
              Text(
                'Enter your self-hosted Qubix server URL',
                style: QubixTypography.bodyMedium.copyWith(color: QubixColors.textSecondary),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _urlController,
                style: QubixTypography.bodyLarge,
                decoration: InputDecoration(
                  labelText: 'Server URL',
                  hintText: 'https://your-server.com',
                  prefixIcon: const Icon(Icons.dns_outlined),
                  suffixIcon: _isConnected
                      ? const Icon(Icons.check_circle, color: QubixColors.success)
                      : null,
                ),
                keyboardType: TextInputType.url,
                autocorrect: false,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: QubixTypography.bodySmall.copyWith(color: QubixColors.error)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: _isConnected
                    ? ElevatedButton(
                        onPressed: _saveAndContinue,
                        child: const Text('Continue'),
                      )
                    : OutlinedButton(
                        onPressed: _isChecking ? null : _checkConnection,
                        child: _isChecking
                            ? const SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Test Connection'),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
