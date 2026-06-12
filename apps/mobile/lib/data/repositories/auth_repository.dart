import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../models/user.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.read(sharedPreferencesProvider),
    ref,
  );
});

class AuthRepository {
  final Dio _dio;
  final dynamic _prefs; // SharedPreferences
  final Ref _ref;

  AuthRepository(this._dio, this._prefs, this._ref);

  Future<User> getMe() async {
    final response = await _dio.get(AppConstants.pathMe);
    return User.fromJson(response.data['user']);
  }

  Future<void> logout() async {
    // Clear secure storage / prefs
    await _prefs.remove(AppConstants.keyAuthToken);
    await _prefs.remove(AppConstants.keyUserId);
    await _prefs.remove(AppConstants.keyUserEmail);
    await _prefs.remove(AppConstants.keyUserDisplayName);
    
    // Update providers
    _ref.read(authTokenProvider.notifier).update(null);
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/auth/me'); // Assuming endpoint is /auth/me for delete
    await logout();
  }
}
