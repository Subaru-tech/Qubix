import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

sealed class AppConnectionState {}
class AppConnectionOnline extends AppConnectionState {}
class AppConnectionOffline extends AppConnectionState {}
class AppConnectionUnknown extends AppConnectionState {}

final connectivityProvider = NotifierProvider<ConnectivityNotifier, AppConnectionState>(() {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends Notifier<AppConnectionState> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _debounceTimer;

  @override
  AppConnectionState build() {
    _init();
    ref.onDispose(() {
      _subscription?.cancel();
      _debounceTimer?.cancel();
    });
    return AppConnectionUnknown();
  }

  Future<void> _init() async {
    final results = await _connectivity.checkConnectivity();
    _handleStatusChange(results);

    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 2), () {
        _handleStatusChange(results);
      });
    });
  }

  void _handleStatusChange(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.wifi) ||
        results.contains(ConnectivityResult.mobile) ||
        results.contains(ConnectivityResult.ethernet)) {
      if (state is! AppConnectionOnline) {
        state = AppConnectionOnline();
      }
    } else if (results.contains(ConnectivityResult.none)) {
      if (state is! AppConnectionOffline) {
        state = AppConnectionOffline();
      }
    }
  }
}
