import 'dart:convert';

import 'local_store.dart';

/// Product ids this device has deleted. Hydrate used to replace `localProducts`
/// with the Firestore list, so a failed `deleteDoc` put the SKU back on Home
/// and checkout could write another paid order.
const deletedProductIdsKey = 'deletedProductIds';

Set<String> readDeletedProductIds() {
  final raw = LocalStore.getString(deletedProductIdsKey);
  if (raw == null || raw.isEmpty) return <String>{};
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return <String>{};
    return {
      for (final e in decoded)
        if ('$e'.trim().isNotEmpty) '$e'.trim(),
    };
  } catch (_) {
    return <String>{};
  }
}

bool isDeletedProductId(String productId) {
  final id = productId.trim();
  if (id.isEmpty) return false;
  return readDeletedProductIds().contains(id);
}

Future<void> tombstoneProductId(String productId) async {
  final id = productId.trim();
  if (id.isEmpty) return;
  final ids = readDeletedProductIds()..add(id);
  await LocalStore.setString(deletedProductIdsKey, jsonEncode(ids.toList()));
}
