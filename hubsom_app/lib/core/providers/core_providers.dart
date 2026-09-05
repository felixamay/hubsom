import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cart.dart';
import '../../models/huber.dart';
import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/shop_video.dart';
import '../../models/user.dart';
import '../auth/passkey_bridge.dart';
import '../auth/passkey_models.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/huber_repository.dart';
import '../repositories/live_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/seller_repository.dart';
import '../services/agora_service.dart';
import '../services/api_client.dart';
import '../services/cloud_store.dart';
import '../services/local_store.dart';
import '../services/location_service.dart';
import '../services/maps_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';

final _unauthorizedTickProvider = StateProvider<int>((ref) => 0);

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(
    onUnauthorized: () async {
      ref.read(_unauthorizedTickProvider.notifier).state++;
    },
  );
});

final passkeyBridgeProvider = Provider<PasskeyBridge>(
  (ref) => PasskeyBridge.instance,
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(apiClientProvider),
    passkeys: ref.watch(passkeyBridgeProvider),
  ),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(
    ref.watch(apiClientProvider),
    onUserChanged: (user) {
      ref.read(authStateProvider.notifier).applyLocalUser(user);
    },
  ),
);

final liveRepositoryProvider = Provider<LiveRepository>(
  (ref) => LiveRepository(ref.watch(apiClientProvider)),
);

final orderRepositoryProvider = Provider<OrderRepository>(
  (ref) => OrderRepository(ref.watch(apiClientProvider)),
);

final messageRepositoryProvider = Provider<MessageRepository>(
  (ref) => MessageRepository(ref.watch(apiClientProvider)),
);

/// Unread direct-message count for the signed-in user (header badge).
final unreadMessagesCountProvider = Provider<int>((ref) {
  ref.watch(authStateProvider);
  ref.watch(messagesTickProvider);
  return ref.watch(messageRepositoryProvider).unreadCount();
});

/// Bump to refresh inbox / unread badge after send or read.
final messagesTickProvider = StateProvider<int>((ref) => 0);

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => SellerRepository(ref.watch(apiClientProvider)),
);

final huberRepositoryProvider = Provider<HuberRepository>(
  (ref) => HuberRepository(),
);

final agoraServiceProvider = Provider<AgoraService>(
  (ref) => AgoraService(ref.watch(apiClientProvider)),
);

final mapsServiceProvider = Provider<MapsService>((ref) => MapsService());

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);

final paymentServiceProvider = Provider<PaymentService>(
  (ref) => PaymentService(ref.watch(apiClientProvider)),
);

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);

final authStateProvider =
    StateNotifierProvider<AuthController, AsyncValue<HubsomUser?>>((ref) {
  final controller = AuthController(ref.watch(authRepositoryProvider));
  ref.listen<int>(_unauthorizedTickProvider, (prev, next) {
    if (prev != next) {
      controller.forceSignedOut();
    }
  });
  return controller;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authStateProvider).valueOrNull != null;
});

class AuthController extends StateNotifier<AsyncValue<HubsomUser?>> {
  AuthController(this._repo) : super(const AsyncValue.loading()) {
    _hydrate();
  }

  final AuthRepository _repo;

  Future<void> _hydrate() async {
    final local = _repo.currentUser();
    state = AsyncValue.data(local);
    await CloudStore.hydrateLocalCache();
    if (local != null) {
      final fresh = await _repo.fetchProfile();
      if (fresh != null) {
        state = AsyncValue.data(fresh);
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signIn(email: email, password: password);
      state = AsyncValue.data(user);
    } catch (e, st) {
      // Keep Account usable — never stick Dio/HTML dumps into auth state.
      state = const AsyncValue.data(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'buyer',
    HuberSignUpDetails? huber,
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
        huber: huber,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = const AsyncValue.data(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<void> enableHuber({HuberSignUpDetails? details}) async {
    final user = await _repo.enableHuber(details: details);
    state = AsyncValue.data(user);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) {
    return _repo.changePassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
    );
  }

  Future<void> signInWithPasskey({String? email}) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signInWithPasskey(email: email);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = const AsyncValue.data(null);
      Error.throwWithStackTrace(e, st);
    }
  }

  Future<PasskeyRecord> registerPasskey() => _repo.registerPasskey();

  Future<void> removePasskey(String credentialId) =>
      _repo.removePasskey(credentialId);

  List<PasskeyRecord> listPasskeys() => _repo.listPasskeys();

  bool get passkeysSupported => _repo.passkeysSupported;

  Future<void> signOut() async {
    await _repo.signOut();
    state = const AsyncValue.data(null);
  }

  void forceSignedOut() {
    state = const AsyncValue.data(null);
  }

  Future<void> refresh() async {
    final user = await _repo.fetchProfile();
    state = AsyncValue.data(user ?? _repo.currentUser());
  }

  /// Apply a locally-updated user (follows, likes, saves) without a network round-trip.
  void applyLocalUser(HubsomUser user) {
    state = AsyncValue.data(user);
  }

  Future<void> reloadFromLocal() async {
    state = AsyncValue.data(_repo.currentUser());
  }
}

final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController();
});

/// Total quantity across all cart lines (header badge).
final cartCountProvider = Provider<int>((ref) {
  return ref.watch(cartProvider).fold<int>(0, (s, e) => s + e.quantity);
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(_mergeByProduct(LocalStore.loadCart()));

  static List<CartItem> _mergeByProduct(List<CartItem> items) {
    final byId = <String, CartItem>{};
    for (final item in items) {
      final existing = byId[item.productId];
      if (existing == null) {
        byId[item.productId] = item;
      } else {
        byId[item.productId] = existing.copyWith(
          quantity: existing.quantity + item.quantity,
          source: item.source,
          streamId: item.streamId ?? existing.streamId,
          name: item.name.isNotEmpty ? item.name : existing.name,
          priceGhs: item.priceGhs,
          image: item.image ?? existing.image,
          category: item.category ?? existing.category,
        );
      }
    }
    return byId.values.toList();
  }

  Future<void> _persist() => LocalStore.saveCart(state);

  /// Add any platform product (live, shop, flash, category) into the shared cart.
  Future<CartItem> addProduct(
    Product product, {
    int quantity = 1,
    String source = 'buy-now',
    String? streamId,
  }) async {
    final qty = quantity <= 0 ? 1 : quantity;
    final resolvedSource = product.hasActiveFlashSale && source == 'buy-now'
        ? 'flash-sale'
        : source;
    final item = CartItem(
      productId: product.id,
      quantity: qty,
      source: resolvedSource,
      streamId: streamId,
      name: product.name,
      priceGhs: product.effectivePrice,
      image: product.images.isNotEmpty ? product.images.first : null,
      category: product.category,
    );
    await add(item);
    return item;
  }

  Future<void> add(CartItem item) async {
    // One line per product so live / shop / flash all feed the same header cart.
    final idx = state.indexWhere((e) => e.productId == item.productId);
    if (idx >= 0) {
      final existing = state[idx];
      final next = [...state];
      next[idx] = existing.copyWith(
        quantity: existing.quantity + item.quantity,
        source: item.source,
        streamId: item.streamId ?? existing.streamId,
        name: item.name.isNotEmpty ? item.name : existing.name,
        priceGhs: item.priceGhs,
        image: item.image ?? existing.image,
        category: item.category ?? existing.category,
      );
      state = next;
    } else {
      state = [...state, item];
    }
    await _persist();
  }

  Future<void> setQuantity(String productId, int qty) async {
    if (qty <= 0) {
      state = state.where((e) => e.productId != productId).toList();
    } else {
      state = [
        for (final e in state)
          if (e.productId == productId) e.copyWith(quantity: qty) else e,
      ];
    }
    await _persist();
  }

  Future<void> remove(String productId) async {
    state = state.where((e) => e.productId != productId).toList();
    await _persist();
  }

  Future<void> clear() async {
    state = [];
    await _persist();
  }

  double get subtotal => state.fold(0, (sum, e) => sum + e.lineTotal);
  int get count => state.fold(0, (sum, e) => sum + e.quantity);
}

final productsProvider = FutureProvider.autoDispose
    .family<List<dynamic>, ({String? category, String? q})>((ref, args) async {
  final repo = ref.watch(catalogRepositoryProvider);
  return repo.listProducts(category: args.category, q: args.q);
});

final streamsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  return ref.watch(liveRepositoryProvider).listStreams();
});

final promotionsProvider =
    FutureProvider.autoDispose.family<List<dynamic>, String>((ref, placement) async {
  return ref.watch(catalogRepositoryProvider).listPromotions(placement);
});

final shopVideosProvider =
    FutureProvider<List<ShopVideo>>((ref) async {
  return ref.watch(catalogRepositoryProvider).listShopVideos();
});

/// Bump when the Timeline tab is selected so the feed reloads with latest videos.
final timelineTabTickProvider = StateProvider<int>((ref) => 0);

final sellersProvider = FutureProvider.autoDispose<List<Seller>>((ref) async {
  return ref.watch(catalogRepositoryProvider).listSellers();
});
