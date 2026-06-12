import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../../core/router.dart';
import '../../viewmodels/settings_notifier.dart';
import '../../../core/utils/api_client.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(settingsProvider.notifier).loadUser());
  }

  Future<void> _confirmLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text("You'll need to sign in again."),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Log Out', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(settingsProvider.notifier).logout();
      if (mounted) context.go(Routes.login);
    }
  }

  Future<void> _confirmDeleteAccount() async {
    String confirmationText = '';
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Delete Account?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This will permanently delete your account, all agents, threads, and messages.'),
                  const SizedBox(height: 16),
                  Text('Type DELETE to confirm:', style: QubixTypography.bodySmall),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    onChanged: (val) {
                      setState(() {
                        confirmationText = val;
                      });
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: confirmationText == 'DELETE'
                      ? () => Navigator.of(context).pop(true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                    foregroundColor: Theme.of(context).colorScheme.onError,
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true && mounted) {
      await ref.read(settingsProvider.notifier).deleteAccount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account deleted permanently')),
        );
        context.go(Routes.login);
      }
    }
  }

  void _showThemeSelector() {
    final currentThemeState = ref.read(themeProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).padding.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Choose Theme', style: QubixTypography.displaySmall),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F0F12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.dark_mode, color: Color(0xFF6366F1)),
                ),
                title: const Text('Dark Dev'),
                trailing: currentThemeState.name == 'Dark Dev' ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme('Dark Dev');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFDEE2E6)),
                  ),
                  child: const Icon(Icons.light_mode, color: Color(0xFF6366F1)),
                ),
                title: const Text('Light Minimal'),
                trailing: currentThemeState.name == 'Light Minimal' ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme('Light Minimal');
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D0221),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Color(0xFFFF00FF)),
                ),
                title: const Text('Synthwave'),
                trailing: currentThemeState.name == 'Synthwave' ? const Icon(Icons.check) : null,
                onTap: () {
                  ref.read(themeProvider.notifier).setTheme('Synthwave');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [QubixColors.primary, QubixColors.accent],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.hub_outlined, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 16),
            Text('Qubix', style: QubixTypography.displayMedium),
            const SizedBox(height: 4),
            Text('Version ${AppConstants.appVersion}', style: QubixTypography.bodySmall),
            const SizedBox(height: 16),
            Text('Self-hosted AI agent command center.', style: QubixTypography.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('Built with Flutter, Fastify, and PostgreSQL.', style: QubixTypography.labelSmall, textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);
    final themeState = ref.watch(themeProvider);

    return Scaffold(
      backgroundColor: QubixColors.background,
      appBar: AppBar(
        title: Text('Settings', style: QubixTypography.displayMedium),
        centerTitle: false,
      ),
      body: settingsAsync.when(
        data: (state) {
          final user = state.user;
          // Fallback to local prefs if network user isn't loaded yet
          final prefs = ref.read(sharedPreferencesProvider);
          final fallbackEmail = prefs.getString(AppConstants.keyUserEmail) ?? 'user@qubix.local';
          final fallbackName = prefs.getString(AppConstants.keyUserDisplayName) ?? fallbackEmail;

          final displayEmail = user?.email ?? fallbackEmail;
          final displayName = user?.displayName ?? fallbackName;

          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            children: [
              // Profile Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'U',
                        style: QubixTypography.displayMedium,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayName,
                            style: QubixTypography.bodyLarge,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            displayEmail,
                            style: QubixTypography.bodySmall.copyWith(color: QubixColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(indent: 24, endIndent: 24, height: 32),

              // Appearance Section
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text('Theme', style: QubixTypography.bodyLarge),
                      subtitle: Text('Current: ${themeState.name}', style: QubixTypography.bodySmall.copyWith(color: QubixColors.textSecondary)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showThemeSelector,
                    ),
                    ListTile(
                      leading: const Icon(Icons.color_lens_outlined),
                      title: Text('Accent Color', style: QubixTypography.bodyLarge),
                      trailing: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary,
                          border: Border.all(color: Theme.of(context).colorScheme.outline, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Account Section
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                      title: Text('Log Out', style: QubixTypography.bodyLarge.copyWith(color: Theme.of(context).colorScheme.error)),
                      onTap: state.isLoading ? null : _confirmLogout,
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: Theme.of(context).colorScheme.error),
                      title: Text('Delete Account', style: QubixTypography.bodyLarge.copyWith(color: Theme.of(context).colorScheme.error)),
                      onTap: state.isLoading ? null : _confirmDeleteAccount,
                    ),
                  ],
                ),
              ),

              // About Section
              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text('About Qubix', style: QubixTypography.bodyLarge),
                      onTap: _showAboutDialog,
                    ),
                    ListTile(
                      leading: const Icon(Icons.code),
                      title: Text('Open Source', style: QubixTypography.bodyLarge),
                      subtitle: Text('MIT License • View on GitHub', style: QubixTypography.bodySmall.copyWith(color: QubixColors.textSecondary)),
                      onTap: () async {
                        final uri = Uri.parse('https://github.com/Subaru-tech/Qubix');
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
