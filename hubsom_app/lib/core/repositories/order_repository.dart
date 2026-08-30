import 'dart:convert';

import '../../models/order.dart';
import '../../models/shipment.dart';
import '../../models/user.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';
import '../services/cloud_store.dart';
import '../services/local_huber_store.dart';
import '../services/local_store.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  HubsomUser? get _sessionUser {
    final raw = LocalStore.userJson;
    if (raw == null || raw.isEmpty) return null;
    try {
      return HubsomUser.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  Future<Order> checkout(Map<String, dynamic> body) async {
    try {
      final res = await _api.post('/api/checkout', data: body);
      final data = ApiResponse.asMap(res.data);
      final order = data?['order'] as Map? ?? data;
      if (order != null && order['id'] != null) {
        return Order.fromJson(Map<String, dynamic>.from(order));
      }
    } catch (_) {}
    throw StateError('Checkout failed');
  }

  Future<List<Order>> sellerOrders() async {
    try {
      final res = await _api.get('/api/seller/orders');
      final remote = ApiResponse.asList(res.data, key: 'orders');
      if (remote.isNotEmpty) {
        return remote
            .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (ApiResponse.asMap(res.data) != null) {
        return const [];
      }
    } catch (_) {}

    final sellerId = _sessionUser?.sellerId;
    final byId = <String, Order>{
      for (final o in LocalHuberStore.listOrders()) o.id: o,
    };
    try {
      final rows = await CloudStore.listDocs(CloudStore.orders);
      for (final row in rows) {
        try {
          final o = Order.fromJson(row);
          if (sellerId != null &&
              sellerId.isNotEmpty &&
              !o.lines.any((l) => l.sellerId == sellerId)) {
            continue;
          }
          byId[o.id] = o;
          await LocalHuberStore.saveOrder(o);
        } catch (_) {}
      }
    } catch (_) {}

    var orders = byId.values.toList();
    if (sellerId != null && sellerId.isNotEmpty) {
      orders = orders
          .where((o) => o.lines.any((l) => l.sellerId == sellerId))
          .toList();
    }
    orders.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return orders;
  }

  Future<Order> updateOrder(String orderId, Map<String, dynamic> patch) async {
    try {
      final res = await _api.patch('/api/seller/orders/$orderId', data: patch);
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['id'] != null) {
        return Order.fromJson(data);
      }
    } catch (_) {}
    throw StateError('Order update failed');
  }

  Future<List<Shipment>> listShipments() async {
    try {
      final res = await _api.get('/api/seller/shipments');
      final remote = ApiResponse.asList(res.data, key: 'shipments');
      if (remote.isNotEmpty) {
        return remote
            .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      }
      if (ApiResponse.asMap(res.data) != null) {
        return const [];
      }
    } catch (_) {}
    return LocalHuberStore.listShipments();
  }

  Future<Shipment> createShipment(Map<String, dynamic> body) async {
    try {
      final res = await _api.post('/api/seller/shipments', data: body);
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['id'] != null) {
        return Shipment.fromJson(data);
      }
    } catch (_) {}
    final user = _sessionUser;
    final ids = (body['orderIds'] as List?)?.map((e) => '$e').toList() ?? const [];
    return LocalHuberStore.createShipmentFromOrders(
      orderIds: ids,
      sellerId: user?.sellerId ?? user?.id ?? 'seller-local',
      createdByUserId: user?.id ?? 'local',
    );
  }

  Future<Shipment> updateShipment(String id, Map<String, dynamic> patch) async {
    try {
      final res = await _api.patch('/api/seller/shipments/$id', data: patch);
      final data = ApiResponse.asMap(res.data);
      if (data != null && data['id'] != null) {
        return Shipment.fromJson(data);
      }
    } catch (_) {}
    final current = LocalHuberStore.getShipment(id);
    if (current == null) throw StateError('Shipment update failed');
    return LocalHuberStore.saveShipment(
      current.copyWith(
        status: patch['status'] as String? ?? current.status,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  /// Dispatch Hubers (rider offers) for a shipment.
  Future<Shipment> offerToHubers(String shipmentId, {List<String>? huberIds}) async {
    try {
      final res = await _api.post(
        '/api/seller/shipments/$shipmentId/hubers',
        data: {if (huberIds != null) 'huberIds': huberIds},
      );
      final data = ApiResponse.asMap(res.data);
      final shipment = data?['shipment'] as Map? ?? data;
      if (shipment != null && shipment['id'] != null) {
        return Shipment.fromJson(Map<String, dynamic>.from(shipment));
      }
    } catch (_) {}
    final local = LocalHuberStore.getShipment(shipmentId);
    if (local == null) {
      throw StateError(
        'Shipment not found. Consolidate paid orders first, then tap Hubers.',
      );
    }
    final result = await LocalHuberStore.dispatchToHubers(local);
    return result.shipment;
  }
}
