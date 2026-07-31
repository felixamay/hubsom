import '../../models/order.dart';
import '../../models/shipment.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';

class OrderRepository {
  OrderRepository(this._api);

  final ApiClient _api;

  Future<Order> checkout(Map<String, dynamic> body) async {
    final res = await _api.post('/api/checkout', data: body);
    final data = ApiResponse.asMap(res.data);
    final order = data?['order'] as Map? ?? data;
    if (order == null) throw StateError('Checkout failed');
    return Order.fromJson(Map<String, dynamic>.from(order));
  }

  Future<List<Order>> sellerOrders() async {
    final res = await _api.get('/api/seller/orders');
    return ApiResponse.asList(res.data, key: 'orders')
        .map((e) => Order.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Order> updateOrder(String orderId, Map<String, dynamic> patch) async {
    final res = await _api.patch('/api/seller/orders/$orderId', data: patch);
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Order update failed');
    return Order.fromJson(data);
  }

  Future<List<Shipment>> listShipments() async {
    final res = await _api.get('/api/seller/shipments');
    return ApiResponse.asList(res.data, key: 'shipments')
        .map((e) => Shipment.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Shipment> createShipment(Map<String, dynamic> body) async {
    final res = await _api.post('/api/seller/shipments', data: body);
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Shipment create failed');
    return Shipment.fromJson(data);
  }

  Future<Shipment> updateShipment(String id, Map<String, dynamic> patch) async {
    final res = await _api.patch('/api/seller/shipments/$id', data: patch);
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Shipment update failed');
    return Shipment.fromJson(data);
  }

  /// Dispatch Hubers (rider offers) for a shipment.
  Future<Shipment> offerToHubers(String shipmentId, {List<String>? huberIds}) async {
    final res = await _api.post(
      '/api/seller/shipments/$shipmentId/hubers',
      data: {if (huberIds != null) 'huberIds': huberIds},
    );
    final data = ApiResponse.asMap(res.data);
    final shipment = data?['shipment'] as Map? ?? data;
    if (shipment == null) throw StateError('Huber offer failed');
    return Shipment.fromJson(Map<String, dynamic>.from(shipment));
  }
}
