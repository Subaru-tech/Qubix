import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/api_client.dart';
import '../../../core/router.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.read(sharedPreferencesProvider);
    final email = prefs.getString(AppConstants.keyUserEmail) ?? 'Unknown';
    final name = prefs.getString(AppConstants.keyUserDisplayName) ?? '';
    final serverUrl = ref.read(serverUrlProvider);

    return Scaffold(
      backgroundColor: QubixColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: QubixColors.primary.withValues(alpha: 0.2),
                    child: Text(
                      (name.isNotEmpty ? name[0] : email[0]).toUpperCase(),
                      style: QubixTypography.displayMedium.copyWith(color: QubixColors.primary),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (name.isNotEmpty)
                          Text(name, style: QubixTypography.labelLarge),
                        Text(
                          email,
                          style: QubixTypography.bodySmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Server info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.dns_outlined, color: QubixColors.textSecondary),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Server', style: QubixTypography.labelMedium),
                        Text(
                          serverUrl,
                          style: QubixTypography.codeSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // App info
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: QubixColors.textSecondary),
                  const SizedBox(width: 16),
                  Text('Qubix v${AppConstants.appVersion}',
                      style: QubixTypography.bodyMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          // Logout
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await prefs.remove(AppConstants.keyAuthToken);
                await prefs.remove(AppConstants.keyUserId);
                ref.read(authTokenProvider.notifier).update(null);
                if (context.mounted) context.go(Routes.login);
              },
              icon: const Icon(Icons.logout, color: QubixColors.error),
              label: Text('Sign Out',
                  style: QubixTypography.button.copyWith(color: QubixColors.error)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: QubixColors.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
