import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../config/app_config.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'local_commerce_store.dart';
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
      final data = parseRemoteCheckout(res.data);
      if (data != null) return data;
    } catch (_) {}

    return placeOfflineCheckout(
      items: items,
      shipping: shipping,
      paymentMethods: paymentMethods,
      streamId: streamId,
      oneTap: oneTap,
      user: _sessionUser(),
    );
  }

  /// Next.js `/api/checkout` returns `orderId`. HTML from Firebase Hosting
  /// rewrites, error JSON, and empty bodies are not a successful charge.
  static Map<String, dynamic>? parseRemoteCheckout(dynamic data) {
    final map = ApiResponse.asMap(data);
    if (map == null || map['error'] != null) return null;
    final nested = map['order'];
    final nestedId = nested is Map ? nested['id'] : null;
    final id = map['orderId'] ?? map['id'] ?? nestedId;
    if (id == null || '$id'.trim().isEmpty) return null;
    return map;
  }

  static String checkoutOrderId(Map<String, dynamic> res) {
    final nested = res['order'];
    final nestedId = nested is Map ? nested['id'] : null;
    final id = res['orderId'] ?? res['id'] ?? nestedId;
    return id == null || '$id'.trim().isEmpty ? 'ok' : '$id';
  }

  static int? parseLineQuantity(dynamic raw) {
    if (raw is int) return raw >= 1 && raw <= 1000 ? raw : null;
    if (raw is num) {
      if (raw != raw.roundToDouble()) return null;
      final n = raw.toInt();
      return n >= 1 && n <= 1000 ? n : null;
    }
    return null;
  }

  static double catalogUnitPrice(Product product, {DateTime? now}) {
    final sale = product.flashSale;
    if (sale == null) return product.priceGhs < 0 ? 0 : product.priceGhs;
    final ends = DateTime.tryParse(sale.endsAt);
    if (ends != null && !ends.isAfter(now ?? DateTime.now())) {
      return product.priceGhs < 0 ? 0 : product.priceGhs;
    }
    final pct = sale.discountPct.clamp(0, 100);
    final unit = product.priceGhs * (1 - pct / 100);
    return unit < 0 ? 0 : unit;
  }

  /// Hosting fallback when `/api/checkout` is rewritten to HTML.
  /// Never marks the order paid, never trusts cart prices, never accepts
  /// non-positive quantities.
  static Future<Map<String, dynamic>> placeOfflineCheckout({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic> shipping,
    required List<String> paymentMethods,
    String? streamId,
    bool oneTap = false,
    HubsomUser? user,
  }) async {
    if (items.isEmpty) {
      throw StateError('items required');
    }

    final lines = <OrderLine>[];
    final reserved = <({String id, int qty})>[];
    try {
      for (final item in items) {
        final productId = '${item['productId'] ?? ''}';
        final qty = parseLineQuantity(item['quantity']);
        if (productId.isEmpty || qty == null) {
          throw StateError('Quantity must be a positive integer');
        }
        final product = LocalCommerceStore.getProduct(productId);
        if (product == null) {
          throw StateError('Unknown product $productId');
        }
        if (product.stock < qty) {
          throw StateError('Insufficient stock for ${product.name}');
        }
        final unit = catalogUnitPrice(product);
        lines.add(
          OrderLine(
            productId: product.id,
            sellerId: product.sellerId,
            name: product.name,
            image: product.images.isNotEmpty ? product.images.first : null,
            quantity: qty,
            unitPriceGhs: unit,
            lineTotalGhs: unit * qty,
            category: product.category,
          ),
        );
        await LocalCommerceStore.updateProduct(
          product.copyWith(stock: product.stock - qty),
        );
        reserved.add((id: product.id, qty: qty));
      }
    } catch (error) {
      for (final taken in reserved) {
        final product = LocalCommerceStore.getProduct(taken.id);
        if (product == null) continue;
        await LocalCommerceStore.updateProduct(
          product.copyWith(stock: product.stock + taken.qty),
        );
      }
      rethrow;
    }

    final subtotal = lines.fold<double>(0, (sum, line) => sum + line.lineTotalGhs);
    final dest = OrderShipping.fromJson(shipping);
    final order = Order(
      id: 'ord_${const Uuid().v4().replaceAll('-', '').substring(0, 10)}',
      subtotalGhs: subtotal,
      status: 'pending_payment',
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
    return {
      'ok': true,
      'orderId': order.id,
      'id': order.id,
      'status': order.status,
      'subtotalGhs': order.subtotalGhs,
      'order': order.toJson(),
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
