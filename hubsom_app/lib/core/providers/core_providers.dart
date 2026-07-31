import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cart.dart';
import '../../models/user.dart';
import '../repositories/auth_repository.dart';
import '../repositories/catalog_repository.dart';
import '../repositories/live_repository.dart';
import '../repositories/message_repository.dart';
import '../repositories/order_repository.dart';
import '../repositories/seller_repository.dart';
import '../services/agora_service.dart';
import '../services/api_client.dart';
import '../services/local_store.dart';
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

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(apiClientProvider)),
);

final catalogRepositoryProvider = Provider<CatalogRepository>(
  (ref) => CatalogRepository(ref.watch(apiClientProvider)),
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

final sellerRepositoryProvider = Provider<SellerRepository>(
  (ref) => SellerRepository(ref.watch(apiClientProvider)),
);

final agoraServiceProvider = Provider<AgoraService>(
  (ref) => AgoraService(ref.watch(apiClientProvider)),
);

final mapsServiceProvider = Provider<MapsService>((ref) => MapsService());

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
    if (local != null) {
      // Validate / refresh profile in background.
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
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  Future<void> signUp({
    required String email,
    required String password,
    required String name,
    String role = 'buyer',
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = await _repo.signUp(
        email: email,
        password: password,
        name: name,
        role: role,
      );
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

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
}

final cartProvider = StateNotifierProvider<CartController, List<CartItem>>((ref) {
  return CartController();
});

class CartController extends StateNotifier<List<CartItem>> {
  CartController() : super(LocalStore.loadCart());

  Future<void> _persist() => LocalStore.saveCart(state);

  Future<void> add(CartItem item) async {
    final idx =
        state.indexWhere((e) => e.productId == item.productId && e.source == item.source);
    if (idx >= 0) {
      final next = [...state];
      next[idx] = next[idx].copyWith(quantity: next[idx].quantity + item.quantity);
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
