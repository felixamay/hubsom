import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../../models/huber.dart';
import '../../models/seller.dart';
import '../../models/user.dart';
import '../auth/auth_routes.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_store.dart';
import '../services/local_commerce_store.dart';
import '../services/local_huber_store.dart';
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
    HuberSignUpDetails? huber,
  }) async {
    final normalized = CloudStore.accountDocId(email);
    _validateCredentials(normalized, password, name: name);
    if (AuthRoutes.isHuberRole(role) &&
        (huber == null || huber.phone.trim().isEmpty)) {
      throw AuthException('Phone number is required for a Huber driver account');
    }

    final cloudExisting = await CloudStore.getAccount(normalized);
    if (cloudExisting != null) {
      throw AuthException(
        'An account with this email already exists. Please sign in.',
      );
    }
    final existing = LocalStore.loadCredentialVault()[normalized];
    if (existing is Map) {
      throw AuthException(
        'An account with this email already exists. Please sign in.',
      );
    }

    // Prefer remote Auth.js API when it returns real JSON.
    try {
      final res = await _api.post(
        '/api/auth/signup',
        data: {
          'email': normalized,
          'password': password,
          'name': name.trim(),
          'role': role,
        },
      );
      final data = ApiResponse.asMap(res.data);
      if (data != null) {
        if (data['error'] != null) {
          throw AuthException('${data['error']}');
        }
        final userMap = data['user'] as Map? ?? data;
        final user = HubsomUser.fromJson(Map<String, dynamic>.from(userMap));
        final token = data['token'] as String? ?? _issueLocalToken(user);
        await _persist(user, token);
        await _storeLocalCredentials(
          email: normalized,
          password: password,
          user: user,
        );
        await _ensureHuberProfile(user, huber);
        return user;
      }
      // HTML / empty from Firebase Hosting SPA rewrite → local vault.
      return await _localSignUp(
        email: normalized,
        password: password,
        name: name.trim(),
        role: role,
        huber: huber,
      );
    } on AuthException {
      rethrow;
    } catch (_) {
      return await _localSignUp(
        email: normalized,
        password: password,
        name: name.trim(),
        role: role,
        huber: huber,
      );
    }
  }

  Future<HubsomUser> signIn({
    required String email,
    required String password,
  }) async {
    final normalized = CloudStore.accountDocId(email);
    _validateCredentials(normalized, password);

    try {
      final cloudUser = await _cloudSignIn(
        email: normalized,
        password: password,
      );
      if (cloudUser != null) return cloudUser;
    } on AuthException {
      rethrow;
    } catch (_) {
      final vault = LocalStore.loadCredentialVault();
      if (!vault.containsKey(normalized)) {
        throw AuthException(
          'Could not sign in right now. Check your connection and try again.',
        );
      }
    }

    final vault = LocalStore.loadCredentialVault();
    if (vault.containsKey(normalized)) {
      return _localSignIn(email: normalized, password: password);
    }

    throw AuthException(
      'No account found for that email. Check the email or create an account.',
    );
  }

  Future<HubsomUser?> fetchProfile() async {
    try {
      final res = await _api.get('/api/account/profile');
      final data = ApiResponse.asMap(res.data);
      if (data == null || data['error'] != null) return currentUser();
      final user = HubsomUser.fromJson(data);
      await LocalStore.setUserJson(jsonEncode(user.toJson()));
      return user;
    } catch (_) {
      return currentUser();
    }
  }

  Future<HubsomUser> updateProfile(Map<String, dynamic> patch) async {
    try {
      final res = await _api.patch('/api/account/profile', data: patch);
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['error'] == null && data['id'] != null) {
        final user = HubsomUser.fromJson(data);
        await LocalStore.setUserJson(jsonEncode(user.toJson()));
        await _syncStoreAvatarFromUser(user);
        return user;
      }
    } catch (_) {
      // fall through to local update
    }

    final current = currentUser();
    if (current == null) throw AuthException('Sign in required');
    final updated = HubsomUser(
      id: current.id,
      email: current.email,
      name: patch['name'] as String? ?? current.name,
      image: patch.containsKey('image')
          ? patch['image'] as String?
          : current.image,
      phone: patch['phone'] as String? ?? current.phone,
      city: patch['city'] as String? ?? current.city,
      region: current.region,
      bio: patch['bio'] as String? ?? current.bio,
      role: current.role,
      sellerId: current.sellerId,
      huberId: current.huberId,
      followingSellerIds: current.followingSellerIds,
      savedProductIds: current.savedProductIds,
      likedProductIds: current.likedProductIds,
      addresses: current.addresses,
      emailVerified: current.emailVerified,
      walletBalanceGhs: current.walletBalanceGhs,
    );
    await LocalStore.setUserJson(jsonEncode(updated.toJson()));
    final vault = LocalStore.loadCredentialVault();
    final entry = vault[current.email.toLowerCase()];
    if (entry is Map) {
      entry['userJson'] = updated.toJson();
      vault[current.email.toLowerCase()] = entry;
      await LocalStore.saveCredentialVault(vault);
      try {
        await CloudStore.putAccount(updated.email.toLowerCase(), {
          'salt': entry['salt'],
          'hash': entry['hash'],
          'userJson': updated.toJson(),
          'email': updated.email.toLowerCase(),
        });
      } catch (_) {}
    }
    await _syncStoreAvatarFromUser(updated);
    return updated;
  }

  /// Keep seller store photo in sync with the account profile photo.
  Future<void> _syncStoreAvatarFromUser(HubsomUser user) async {
    final isSeller = user.role == 'seller' ||
        user.role == 'both' ||
        user.role == 'admin' ||
        (user.sellerId != null && user.sellerId!.isNotEmpty);
    if (!isSeller) return;
    try {
      final seller = await LocalCommerceStore.ensureSellerForUser(user);
      final nextAvatar = user.image ?? '';
      if (seller.avatar == nextAvatar) return;
      final synced = Seller(
        id: seller.id,
        slug: seller.slug,
        name: seller.name,
        city: seller.city,
        region: seller.region,
        bio: seller.bio,
        avatar: nextAvatar,
        cover: seller.cover,
        rating: seller.rating,
        followers: seller.followers,
        verified: seller.verified,
        categories: seller.categories,
        ownerUserId: seller.ownerUserId ?? user.id,
      );
      await LocalCommerceStore.upsertSeller(synced);
      try {
        await CloudStore.upsertDocs(CloudStore.sellers, [synced.toJson()]);
      } catch (_) {}
    } catch (_) {}
  }

  /// Attach Huber driving to the signed-in Hubsom account (same vault).
  Future<HubsomUser> enableHuber({HuberSignUpDetails? details}) async {
    final current = currentUser();
    if (current == null) throw AuthException('Sign in required');
    if (current.isHuber) {
      await LocalHuberStore.ensureProfileForUser(current, details: details);
      return current;
    }
    final updated = HubsomUser(
      id: current.id,
      email: current.email,
      name: current.name,
      image: current.image,
      phone: details?.phone ?? current.phone,
      city: details?.city ?? current.city,
      region: details?.region ?? current.region,
      bio: current.bio,
      role: current.role == 'buyer' ? 'huber' : current.role,
      sellerId: current.sellerId,
      huberId: 'huber-${current.id}',
      followingSellerIds: current.followingSellerIds,
      savedProductIds: current.savedProductIds,
      addresses: current.addresses,
      emailVerified: current.emailVerified,
      walletBalanceGhs: current.walletBalanceGhs,
    );
    await LocalStore.setUserJson(jsonEncode(updated.toJson()));
    final vault = LocalStore.loadCredentialVault();
    final entry = vault[updated.email.toLowerCase()];
    if (entry is Map) {
      entry['userJson'] = updated.toJson();
      vault[updated.email.toLowerCase()] = entry;
      await LocalStore.saveCredentialVault(vault);
    }
    await LocalHuberStore.ensureProfileForUser(updated, details: details);
    if (entry is Map) {
      try {
        await CloudStore.putAccount(updated.email.toLowerCase(), {
          'salt': entry['salt'],
          'hash': entry['hash'],
          'userJson': updated.toJson(),
          'email': updated.email.toLowerCase(),
        });
      } catch (_) {}
    }
    return updated;
  }

  Future<void> signOut() async {
    try {
      await _api.post('/api/auth/signout');
    } catch (_) {}
    await LocalStore.clearSession();
  }

  Future<void> invalidateSession() => LocalStore.clearSession();

  Future<HubsomUser> _localSignUp({
    required String email,
    required String password,
    required String name,
    required String role,
    HuberSignUpDetails? huber,
  }) async {
    final vault = LocalStore.loadCredentialVault();
    if (vault.containsKey(email)) {
      throw AuthException('An account with this email already exists. Please sign in.');
    }
    if (AuthRoutes.isHuberRole(role) &&
        (huber == null || huber.phone.trim().isEmpty)) {
      throw AuthException('Phone number is required for a Huber driver account');
    }
    final id = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final isHuber = AuthRoutes.isHuberRole(role);
    final user = HubsomUser(
      id: id,
      email: email,
      name: name,
      phone: huber?.phone,
      city: huber?.city,
      region: huber?.region,
      role: isHuber ? 'huber' : role,
      huberId: isHuber ? 'huber-$id' : null,
    );
    await _storeLocalCredentials(email: email, password: password, user: user);
    await _persist(user, _issueLocalToken(user));
    await _ensureHuberProfile(user, huber);
    await CloudStore.hydrateLocalCache();
    return user;
  }

  Future<HubsomUser?> _cloudSignIn({
    required String email,
    required String password,
  }) async {
    final remote = await CloudStore.getAccount(email);
    if (remote == null) return null;
    final salt = remote['salt'] as String? ?? '';
    final hash = remote['hash'] as String? ?? '';
    if (salt.isEmpty || hash.isEmpty || !_verifyPassword(password, salt, hash)) {
      throw AuthException('Invalid email or password');
    }
    final userJson = remote['userJson'];
    if (userJson is! Map) {
      throw AuthException('Could not sign in. Please create your account again.');
    }
    final HubsomUser user;
    try {
      user = HubsomUser.fromJson(Map<String, dynamic>.from(userJson));
    } catch (_) {
      throw AuthException('Could not sign in. Please create your account again.');
    }
    final vault = LocalStore.loadCredentialVault();
    vault[email] = {
      'salt': salt,
      'hash': hash,
      'userJson': user.toJson(),
    };
    await LocalStore.saveCredentialVault(vault);
    await _persist(user, _issueLocalToken(user));
    await CloudStore.hydrateLocalCache();
    if (user.isHuber) {
      await LocalHuberStore.ensureProfileForUser(user);
    }
    return user;
  }

  Future<void> _ensureHuberProfile(HubsomUser user, HuberSignUpDetails? huber) async {
    if (!AuthRoutes.isHuberRole(user.role)) return;
    await LocalHuberStore.ensureProfileForUser(user, details: huber);
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
    await _backfillCloudAccount(
      email: email,
      salt: salt,
      hash: hash,
      user: user,
    );
    if (AuthRoutes.isHuberRole(user.role)) {
      await LocalHuberStore.ensureProfileForUser(user);
    }
    return user;
  }

  Future<void> _storeLocalCredentials({
    required String email,
    required String password,
    required HubsomUser user,
  }) async {
    final salt = _randomSalt();
    final hash = _hashPassword(password, salt);
    final record = {
      'salt': salt,
      'hash': hash,
      'userJson': user.toJson(),
      'email': email,
      'name': user.name,
      'role': user.role,
    };

    // Database first — do not create a browser-only account.
    try {
      await CloudStore.putAccount(email, record);
    } catch (e) {
      throw AuthException(
        'Could not create your account. Check your connection and try again.',
      );
    }

    final vault = LocalStore.loadCredentialVault();
    vault[email] = record;
    await LocalStore.saveCredentialVault(vault);
  }

  Future<void> _backfillCloudAccount({
    required String email,
    required String salt,
    required String hash,
    required HubsomUser user,
  }) async {
    try {
      await CloudStore.putAccount(email, {
        'salt': salt,
        'hash': hash,
        'userJson': user.toJson(),
        'email': email,
        'name': user.name,
        'role': user.role,
      });
    } catch (_) {}
  }

  void _validateCredentials(String email, String password, {String? name}) {
    final normalized = CloudStore.accountDocId(email);
    if (normalized.isEmpty || !normalized.contains('@')) {
      throw AuthException('Enter a valid email address');
    }
    if (password.length < 8) {
      throw AuthException('Password must be at least 8 characters');
    }
    if (name != null && name.trim().isEmpty) {
      throw AuthException('Name is required');
    }
  }

  Future<void> _persist(HubsomUser user, String token) async {
    await LocalStore.setSessionToken(token);
    await LocalStore.setUserJson(jsonEncode(user.toJson()));
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

}
