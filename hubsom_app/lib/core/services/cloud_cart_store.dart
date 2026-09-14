import '../../models/cart.dart';
import 'cloud_store.dart';

/// Signed-in shopping cart, stored in Firestore so Chrome and Safari share it.
class CloudCartStore {
  CloudCartStore._();

  static Future<void> save(String userId, List<CartItem> items) async {
    if (userId.isEmpty || !CloudStore.useNetwork) return;
    try {
      await CloudStore.upsertDocs(CloudStore.carts, [
        {
          'id': userId,
          'userId': userId,
          'items': items.map((e) => e.toJson()).toList(),
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);
    } catch (_) {}
  }

  static Future<List<CartItem>?> load(String userId) async {
    if (userId.isEmpty || !CloudStore.useNetwork) return null;
    try {
      final row = await CloudStore.getDoc(CloudStore.carts, userId);
      if (row == null) return null;
      final raw = row['items'];
      if (raw is! List) return const [];
      return [
        for (final e in raw)
          if (e is Map) CartItem.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return null;
    }
  }
}
