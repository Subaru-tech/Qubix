import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';

final pushRepositoryProvider = Provider<PushRepository>((ref) {
  return PushRepository(ref.watch(dioProvider));
});

class PushRepository {
  final Dio _dio;

  PushRepository(this._dio);

  Future<void> registerPushToken(String token) async {
    try {
      await _dio.post('/push/register', data: {
        'token': token,
        'platform': Platform.operatingSystem,
      });
    } catch (e) {
      // It's okay if this fails (e.g. offline). We don't want to crash.
      // Can log error if needed.
    }
  }

  Future<void> unregisterPushToken(String token) async {
    try {
      await _dio.delete('/push/token', data: {
        'token': token,
      });
    } catch (e) {
      // Ignore errors
    }
  }
}
