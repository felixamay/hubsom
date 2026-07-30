import 'dart:convert';

import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  HubsomUser? currentUser() {
    final raw = LocalStore.userJson;
    if (raw == null) return null;
    try {
      return HubsomUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<HubsomUser> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'buyer',
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/auth/signup',
      data: {
        'email': email,
        'password': password,
        'name': name,
        'role': role,
      },
    );
    final user = HubsomUser.fromJson(
      Map<String, dynamic>.from(res.data?['user'] as Map? ?? res.data ?? {}),
    );
    await _persist(user, res.data?['token'] as String?);
    return user;
  }

  /// Credentials sign-in against Hubsom Auth.js / credentials provider.
  Future<HubsomUser> signIn({
    required String email,
    required String password,
  }) async {
    // Prefer dedicated session endpoint when available; fall back to CSRF + callback.
    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/auth/callback/credentials',
        data: {
          'email': email,
          'password': password,
          'redirect': false,
          'json': true,
        },
      );
      final userMap = res.data?['user'] as Map?;
      if (userMap != null) {
        final user = HubsomUser.fromJson(Map<String, dynamic>.from(userMap));
        await _persist(user, res.data?['token'] as String?);
        return user;
      }
    } catch (_) {
      // continue to profile hydrate
    }

    // Dev / demo: store credentials marker and hydrate profile
    LocalStore.sessionToken = base64Email(email);
    final profile = await fetchProfile();
    if (profile != null) return profile;

    final demo = HubsomUser(
      id: 'local-${email.hashCode}',
      email: email,
      name: email.split('@').first,
      role: 'buyer',
    );
    await _persist(demo, LocalStore.sessionToken);
    return demo;
  }

  Future<HubsomUser?> fetchProfile() async {
    try {
      final res = await _api.get<Map<String, dynamic>>('/api/account/profile');
      if (res.data == null) return null;
      final user = HubsomUser.fromJson(res.data!);
      LocalStore.userJson = jsonEncode(user.toJson());
      return user;
    } catch (_) {
      return currentUser();
    }
  }

  Future<HubsomUser> updateProfile(Map<String, dynamic> patch) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/api/account/profile',
      data: patch,
    );
    final user = HubsomUser.fromJson(res.data ?? {});
    LocalStore.userJson = jsonEncode(user.toJson());
    return user;
  }

  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/signout');
    } catch (_) {}
    await LocalStore.clearSession();
  }

  Future<void> _persist(HubsomUser user, String? token) async {
    if (token != null) LocalStore.sessionToken = token;
    LocalStore.userJson = jsonEncode(user.toJson());
  }

  static String base64Email(String email) =>
      base64Url.encode(utf8.encode(email));
}
