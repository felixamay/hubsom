import '../../models/order.dart';
import '../../models/shipment.dart';
import '../services/api_client.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  Future<Order> checkout(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>('/api/checkout', data: body);
    final order = res.data?['order'] as Map? ?? res.data;
    return Order.fromJson(Map<String, dynamic>.from(order as Map));
  }

  Future<List<Order>> sellerOrders() async {
    final res = await _api.get<dynamic>('/api/seller/orders');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['orders'] is List)
            ? data['orders'] as List
            : <dynamic>[];
    return list
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Order> updateOrder(String orderId, Map<String, dynamic> patch) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/api/seller/orders/$orderId',
      data: patch,
    );
    return Order.fromJson(res.data ?? {});
  }

  Future<List<Shipment>> listShipments() async {
    final res = await _api.get<dynamic>('/api/seller/shipments');
    final data = res.data;
    final list = data is List
        ? data
        : (data is Map && data['shipments'] is List)
            ? data['shipments'] as List
            : <dynamic>[];
    return list
        .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Shipment> createShipment(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/seller/shipments',
      data: body,
    );
    return Shipment.fromJson(res.data ?? {});
  }

  Future<Shipment> updateShipment(String id, Map<String, dynamic> patch) async {
    final res = await _api.patch<Map<String, dynamic>>(
      '/api/seller/shipments/$id',
      data: patch,
    );
    return Shipment.fromJson(res.data ?? {});
  }

  /// Dispatch Hubers (rider offers) for a shipment.
  Future<Shipment> offerToHubers(String shipmentId, {List<String>? huberIds}) async {
    final res = await _api.post<Map<String, dynamic>>(
      '/api/seller/shipments/$shipmentId/hubers',
      data: {if (huberIds != null) 'huberIds': huberIds},
    );
    final shipment = res.data?['shipment'] as Map? ?? res.data;
    return Shipment.fromJson(Map<String, dynamic>.from(shipment as Map));
  }
}
