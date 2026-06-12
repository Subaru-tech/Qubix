import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:uuid/uuid.dart';

import '../utils/api_client.dart';

final telemetryServiceProvider = Provider<TelemetryService>((ref) {
  return TelemetryService(
    ref.read(dioProvider),
    ref.read(sharedPreferencesProvider),
  );
});

class TelemetryService {
  final Dio _dio;
  final SharedPreferences _prefs;
  static const _keyTelemetryEnabled = 'telemetry_enabled';
  static const _keyInstallId = 'telemetry_install_id';

  TelemetryService(this._dio, this._prefs);

  bool get isEnabled => _prefs.getBool(_keyTelemetryEnabled) ?? true;

  Future<void> setEnabled(bool enabled) async {
    await _prefs.setBool(_keyTelemetryEnabled, enabled);
    if (enabled) {
      logEvent('telemetry_enabled');
    }
  }

  String get _installId {
    String? id = _prefs.getString(_keyInstallId);
    if (id == null) {
      id = const Uuid().v4();
      _prefs.setString(_keyInstallId, id);
    }
    return id;
  }

  Future<void> logEvent(String eventName, [Map<String, dynamic>? properties]) async {
    if (!isEnabled) return;

    try {
      String os = Platform.operatingSystem;
      String osVersion = Platform.operatingSystemVersion;
      
      Map<String, dynamic> payload = {
        'installId': _installId,
        'event': eventName,
        'os': os,
        'osVersion': osVersion,
        'timestamp': DateTime.now().toIso8601String(),
      };
      if (properties != null) {
        payload['properties'] = properties;
      }

      // Best effort send
      await _dio.post('/telemetry', data: payload).catchError((_) {
        // Ignore telemetry errors
        return Response(requestOptions: RequestOptions(path: '/telemetry'));
      });
    } catch (e) {
      // Ignore
    }
  }
}
