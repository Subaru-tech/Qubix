import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/typography.dart';
import '../viewmodels/connectivity_notifier.dart';

class ConnectivityBanner extends ConsumerStatefulWidget {
  const ConnectivityBanner({super.key});

  @override
  ConsumerState<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends ConsumerState<ConnectivityBanner> {
  bool _showReconnecting = false;
  AppConnectionState? _prevState;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(connectivityProvider);
    
    // Detect transition from Offline to Online
    if (_prevState is AppConnectionOffline && state is AppConnectionOnline) {
      _showReconnecting = true;
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _showReconnecting = false;
          });
        }
      });
    }
    _prevState = state;

    final bool isOffline = state is AppConnectionOffline;
    final bool isVisible = isOffline || _showReconnecting;
    
    final color = isOffline ? QubixColors.warning : QubixColors.success;
    final icon = isOffline ? Icons.wifi_off : Icons.wifi;
    final text = isOffline ? 'Waiting for network...' : 'Back online';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      height: isVisible ? 32.0 : 0.0,
      width: double.infinity,
      color: color,
      child: isVisible
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: const Color(0xFF0F0F12)),
                const SizedBox(width: 8),
                Text(
                  text,
                  style: QubixTypography.bodySmall.copyWith(
                    color: const Color(0xFF0F0F12),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            )
          : const SizedBox.shrink(),
    );
  }
}
