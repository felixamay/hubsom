import '../../models/seller.dart';
import '../services/api_client.dart';
import '../services/api_response.dart';

class SellerRepository {
  SellerRepository(this._api);

  final ApiClient _api;

  Future<Seller?> myStore() async {
    final res = await _api.get('/api/seller/store');
    final data = ApiResponse.asMap(res.data);
    if (data == null || data.isEmpty) return null;
    return Seller.fromJson(data);
  }

  Future<Seller> updateStore(Map<String, dynamic> body) async {
    final res = await _api.put('/api/seller/store', data: body);
    final data = ApiResponse.asMap(res.data);
    if (data == null) throw StateError('Store update failed');
    return Seller.fromJson(data);
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async {
    final res = await _api.post('/api/products', data: body);
    return ApiResponse.asMap(res.data) ?? {};
  }

  Future<Map<String, dynamic>> social(String sellerId) async {
    final res = await _api.get('/api/sellers/$sellerId/social');
    return ApiResponse.asMap(res.data) ?? {};
  }
}
