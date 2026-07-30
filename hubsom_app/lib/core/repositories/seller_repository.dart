import '../../models/seller.dart';
import '../services/api_client.dart';

class SellerRepository {
  SellerRepository(this._api);

  final ApiClient _api;

  Future<Seller?> myStore() async {
    final res = await _api.get<Map<String, dynamic>>('/api/seller/store');
    if (res.data == null || res.data!.isEmpty) return null;
    return Seller.fromJson(res.data!);
  }

  Future<Seller> updateStore(Map<String, dynamic> body) async {
    final res = await _api.put<Map<String, dynamic>>('/api/seller/store', data: body);
    return Seller.fromJson(res.data ?? {});
  }

  Future<Map<String, dynamic>> createProduct(Map<String, dynamic> body) async {
    final res = await _api.post<Map<String, dynamic>>('/api/products', data: body);
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> social(String sellerId) async {
    final res = await _api.get<Map<String, dynamic>>('/api/sellers/$sellerId/social');
    return res.data ?? {};
  }
}
