import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../models/user.dart';
import '../config/app_config.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'local_huber_store.dart';
import 'local_store.dart';

/// Payment rails preserved from Hubsom: Stripe, Paystack, MTN MoMo,
/// Telecel Cash, AirtelTigo Money.
class PaymentService {
  PaymentService(this._api);

  final ApiClient _api;

  static const supportedMethods = <String>[
    'stripe',
    'paystack',
    'mtn-momo',
    'telecel-cash',
    'airteltigo-money',
    'wallet',
    'cash-on-delivery',
  ];

  Future<Map<String, dynamic>> checkout({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shipping,
    required List<String> paymentMethods,
    String? streamId,
    bool oneTap = false,
  }) async {
    try {
      final res = await _api.post(
        '/api/checkout',
        data: {
          'items': items,
          'shipping': shipping,
          'paymentMethods': paymentMethods,
          if (streamId != null) 'streamId': streamId,
          'oneTap': oneTap,
        },
      );
      final data = ApiResponse.asMap(res.data);
      final status = res.statusCode ?? 0;

      if (data != null) {
        final error = data['error'];
        if (error != null || status >= 400) {
          throw StateError(error == null ? 'Checkout failed' : '$error');
        }
        final orderJson = orderJsonFromCheckoutResponse(data);
        if (orderJson != null) {
          final order = Order.fromJson(orderJson);
          await LocalHuberStore.saveOrder(order);
          return {'ok': true, 'id': order.id, 'order': order.toJson()};
        }
        // Real JSON without an order is a failed checkout, not offline mode.
        throw StateError('Checkout failed');
      }

      if (status >= 400) {
        throw StateError('Checkout failed');
      }
      // HTML / empty 2xx from SPA hosting → local fallback below.
    } on StateError {
      rethrow;
    } catch (_) {
      // Network failure — local fallback below.
    }

    final user = _sessionUser();
    final lines = items.map((e) {
      final qty = (e['quantity'] as num?)?.toInt() ?? 1;
      final price = (e['priceGhs'] as num?)?.toDouble() ?? 0;
      return OrderLine(
        productId: '${e['productId'] ?? ''}',
        sellerId: e['sellerId'] as String?,
        name: '${e['name'] ?? 'Item'}',
        image: e['image'] as String?,
        quantity: qty,
        unitPriceGhs: price,
        lineTotalGhs: price * qty,
        category: '${e['category'] ?? 'miscellaneous'}',
      );
    }).toList();
    final subtotal = lines.fold<double>(0, (s, e) => s + e.lineTotalGhs);
    final dest = OrderShipping.fromJson(shipping);
    final order = Order(
      id: 'ord_${const Uuid().v4().replaceAll('-', '').substring(0, 10)}',
      subtotalGhs: subtotal,
      status: 'paid',
      userId: user?.id,
      buyerName: dest.recipientName,
      buyerEmail: user?.email,
      streamId: streamId,
      oneTap: oneTap,
      lines: lines,
      shipping: dest,
      paymentMethods: paymentMethods,
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await LocalHuberStore.saveOrder(order);
    return {'ok': true, 'order': order.toJson()};
  }

  /// Maps `/api/checkout` bodies that use `order`, `id`, or `orderId`.
  @visibleForTesting
  static Map<String, dynamic>? orderJsonFromCheckoutResponse(
    Map<String, dynamic> data,
  ) {
    final nested = data['order'];
    if (nested is Map) {
      final map = Map<String, dynamic>.from(nested);
      final id = map['id'] ?? data['id'] ?? data['orderId'];
      if (id == null) return null;
      map['id'] = '$id';
      return map;
    }
    final id = data['id'] ?? data['orderId'];
    if (id == null) return null;
    return {
      ...data,
      'id': '$id',
    };
  }

  HubsomUser? _sessionUser() {
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

  Future<void> openStripeCheckout(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (kDebugMode) {
      debugPrint('Cannot launch Stripe URL: $url');
    }
  }

  bool get stripeConfigured => AppConfig.stripePublishableKey.isNotEmpty;
  bool get paystackConfigured => AppConfig.paystackPublicKey.isNotEmpty;
}
