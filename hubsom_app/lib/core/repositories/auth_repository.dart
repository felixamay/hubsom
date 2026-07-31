import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';

class AuthException implements Exception {
  AuthException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  HubsomUser? currentUser() {
    final token = LocalStore.sessionToken;
    final raw = LocalStore.userJson;
    if (token == null || token.isEmpty || raw == null) return null;
    try {
      return HubsomUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  bool get isAuthenticated => currentUser() != null;

  Future<HubsomUser> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'buyer',
  }) async {
    final normalized = email.trim().toLowerCase();
    _validateCredentials(normalized, password, name: name);

    try {
      final res = await _api.post<Map<String, dynamic>>(
        '/api/auth/signup',
        data: {
          'email': normalized,
          'password': password,
          'name': name.trim(),
          'role': role,
        },
      );
      final data = res.data;
      if (data != null && data['error'] != null) {
        throw AuthException('${data['error']}');
      }
      final userMap = data?['user'] as Map? ?? data;
      if (userMap is! Map) {
        throw AuthException('Signup failed');
      }
      final user = HubsomUser.fromJson(Map<String, dynamic>.from(userMap));
      final token = data?['token'] as String? ?? _issueLocalToken(user);
      await _persist(user, token);
      await _storeLocalCredentials(
        email: normalized,
        password: password,
        user: user,
      );
      return user;
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      // Hosting / offline: secure local account vault.
      if (_shouldUseLocalAuth(e)) {
        return _localSignUp(
          email: normalized,
          password: password,
          name: name.trim(),
          role: role,
        );
      }
      final msg = e.response?.data is Map
          ? '${(e.response!.data as Map)['error'] ?? e.message}'
          : (e.message ?? 'Signup failed');
      throw AuthException(msg);
    }
  }

  Future<HubsomUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = email.trim().toLowerCase();
    _validateCredentials(normalized, password);

    try {
      // Auth.js credentials flow (CSRF + callback) when API is available.
      final csrf = await _api.get<dynamic>('/api/auth/csrf');
      final csrfData = _asMap(csrf.data);
      final csrfToken = csrfData?['csrfToken'] as String?;

      final res = await _api.post<dynamic>(
        '/api/auth/callback/credentials',
        data: {
          'email': normalized,
          'password': password,
          'redirect': false,
          'json': true,
          if (csrfToken != null) 'csrfToken': csrfToken,
        },
      );

      final data = _asMap(res.data) ?? (res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null);
      Map? userMap;
      if (data != null) {
        userMap = data['user'] as Map? ?? data['data'] as Map?;
        if (data['error'] != null) {
          throw AuthException('${data['error']}');
        }
      }

      if (userMap != null) {
        final user = HubsomUser.fromJson(Map<String, dynamic>.from(userMap));
        final token = data?['token'] as String? ?? _issueLocalToken(user);
        await _persist(user, token);
        await _storeLocalCredentials(
          email: normalized,
          password: password,
          user: user,
        );
        final profile = await fetchProfile();
        return profile ?? user;
      }

      // Some Auth.js setups set cookie only — hydrate profile.
      final profile = await fetchProfile();
      if (profile != null) {
        await _storeLocalCredentials(
          email: normalized,
          password: password,
          user: profile,
        );
        return profile;
      }

      // Fall through to local vault if remote auth didn't yield a session.
      return _localSignIn(email: normalized, password: password);
    } on AuthException {
      rethrow;
    } on DioException catch (e) {
      if (_shouldUseLocalAuth(e)) {
        return _localSignIn(email: normalized, password: password);
      }
      // Invalid credentials from API
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        throw AuthException('Invalid email or password');
      }
      // Try local vault as secondary (device accounts)
      try {
        return _localSignIn(email: normalized, password: password);
      } on AuthException {
        throw AuthException('Invalid email or password');
      }
    }
  }

  Future<HubsomUser?> fetchProfile() async {
    try {
      final res = await _api.get<dynamic>('/api/account/profile');
      final data = res.data;
      if (data is String && data.trimLeft().startsWith('<')) return currentUser();
      if (data is! Map) return currentUser();
      if (data['error'] != null) return null;
      final user = HubsomUser.fromJson(Map<String, dynamic>.from(data));
      LocalStore.userJson = jsonEncode(user.toJson());
      return user;
    } catch (_) {
      return currentUser();
    }
  }

  Future<HubsomUser> updateProfile(Map<String, dynamic> patch) async {
    try {
      final res = await _api.patch<Map<String, dynamic>>(
        '/api/account/profile',
        data: patch,
      );
      final user = HubsomUser.fromJson(res.data ?? {});
      LocalStore.userJson = jsonEncode(user.toJson());
      return user;
    } on DioException {
      final current = currentUser();
      if (current == null) throw AuthException('Sign in required');
      final updated = HubsomUser(
        id: current.id,
        email: current.email,
        name: patch['name'] as String? ?? current.name,
        image: current.image,
        phone: patch['phone'] as String? ?? current.phone,
        city: patch['city'] as String? ?? current.city,
        region: current.region,
        bio: patch['bio'] as String? ?? current.bio,
        role: current.role,
        sellerId: current.sellerId,
        followingSellerIds: current.followingSellerIds,
        savedProductIds: current.savedProductIds,
        addresses: current.addresses,
        emailVerified: current.emailVerified,
        walletBalanceGhs: current.walletBalanceGhs,
      );
      LocalStore.userJson = jsonEncode(updated.toJson());
      final vault = LocalStore.loadCredentialVault();
      final entry = vault[current.email.toLowerCase()];
      if (entry is Map) {
        entry['userJson'] = updated.toJson();
        vault[current.email.toLowerCase()] = entry;
        await LocalStore.saveCredentialVault(vault);
      }
      return updated;
    }
  }

  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/signout');
    } catch (_) {}
    await LocalStore.clearSession();
  }

  Future<void> invalidateSession() => LocalStore.clearSession();

  // --- local secure vault (used when Firebase Hosting has no Auth.js API) ---

  Future<HubsomUser> _localSignUp({
    required String email,
    required String password,
    required String name,
    required String role,
  }) async {
    final vault = LocalStore.loadCredentialVault();
    if (vault.containsKey(email)) {
      throw AuthException('An account with this email already exists');
    }
    final user = HubsomUser(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      role: role,
    );
    await _storeLocalCredentials(email: email, password: password, user: user);
    await _persist(user, _issueLocalToken(user));
    return user;
  }

  Future<HubsomUser> _localSignIn({
    required String email,
    required String password,
  }) async {
    final vault = LocalStore.loadCredentialVault();
    final entry = vault[email];
    if (entry is! Map) {
      throw AuthException('Invalid email or password');
    }
    final salt = entry['salt'] as String? ?? '';
    final hash = entry['hash'] as String? ?? '';
    if (!_verifyPassword(password, salt, hash)) {
      throw AuthException('Invalid email or password');
    }
    final userJson = entry['userJson'];
    final user = HubsomUser.fromJson(Map<String, dynamic>.from(userJson as Map));
    await _persist(user, _issueLocalToken(user));
    return user;
  }

  Future<void> _storeLocalCredentials({
    required String email,
    required String password,
    required HubsomUser user,
  }) async {
    final vault = LocalStore.loadCredentialVault();
    final salt = _randomSalt();
    vault[email] = {
      'salt': salt,
      'hash': _hashPassword(password, salt),
      'userJson': user.toJson(),
    };
    await LocalStore.saveCredentialVault(vault);
  }

  void _validateCredentials(String email, String password, {String? name}) {
    if (email.isEmpty || !email.contains('@')) {
      throw AuthException('Enter a valid email address');
    }
    if (password.length < 8) {
      throw AuthException('Password must be at least 8 characters');
    }
    if (name != null && name.trim().isEmpty) {
      throw AuthException('Name is required');
    }
  }

  bool _shouldUseLocalAuth(DioException e) {
    final data = e.response?.data;
    if (data is String && data.trimLeft().startsWith('<')) return true;
    final code = e.response?.statusCode;
    if (code == null) return true; // network
    if (code >= 500) return true;
    return e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout;
  }

  Future<void> _persist(HubsomUser user, String token) async {
    LocalStore.sessionToken = token;
    LocalStore.userJson = jsonEncode(user.toJson());
  }

  String _issueLocalToken(HubsomUser user) {
    final payload = base64Url.encode(
      utf8.encode(jsonEncode({
        'sub': user.id,
        'email': user.email,
        'iat': DateTime.now().millisecondsSinceEpoch,
      })),
    );
    return 'hubsom.$payload';
  }

  static String _randomSalt() {
    final r = Random.secure();
    final bytes = List<int>.generate(16, (_) => r.nextInt(256));
    return base64Url.encode(bytes);
  }

  static String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password::hubsom');
    return sha256.convert(bytes).toString();
  }

  static bool _verifyPassword(String password, String salt, String hash) {
    return _hashPassword(password, salt) == hash;
  }

  static Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final t = data.trim();
      if (t.startsWith('{') || t.startsWith('[')) {
        try {
          final decoded = jsonDecode(t);
          if (decoded is Map) return Map<String, dynamic>.from(decoded);
        } catch (_) {}
      }
    }
    return null;
  }
}
