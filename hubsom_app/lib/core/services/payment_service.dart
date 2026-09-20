import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';

import '../../models/order.dart';
import '../../models/payment_account.dart';
import '../../models/user.dart';
import '../config/app_config.dart';
import 'admin_treasury_store.dart';
import 'api_client.dart';
import 'api_response.dart';
import 'cloud_store.dart';
import 'local_commerce_store.dart';
import 'local_huber_store.dart';
import 'local_message_store.dart';
import 'local_store.dart';
import 'payment_account_store.dart';
import 'shipment_fee.dart';

/// Payment rails preserved from Hubsom: Stripe, Paystack, MTN MoMo,
/// Telecel Cash, AirtelTigo Money.
///
/// Product checkout always settles on the admin receive account.
/// Seller/user accounts are withdraw-only after a 6% commission.
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
      if (data != null && (data['order'] != null || data['id'] != null)) {
        await _holdWithAdmin(data);
        return data;
      }
    } catch (_) {}

    final user = _sessionUser();
    final dest = OrderShipping.fromJson(shipping);
    final quotes = <ShipmentQuote>[];
    final lines = items.map((e) {
      final qty = (e['quantity'] as num?)?.toInt() ?? 1;
      final price = (e['priceGhs'] as num?)?.toDouble() ?? 0;
      final product = LocalCommerceStore.getProduct('${e['productId'] ?? ''}');
      final quote = product == null
          ? null
          : ShipmentFee.quote(
              product,
              city: dest.city,
              region: dest.region,
              location: dest.location,
            );
      if (quote != null) quotes.add(quote);
      final ship = quote?.feeGhs ?? (e['shipmentFeeGhs'] as num?)?.toDouble() ?? 0;
      return OrderLine(
        productId: '${e['productId'] ?? ''}',
        sellerId: e['sellerId'] as String? ?? product?.sellerId,
        name: '${e['name'] ?? product?.name ?? 'Item'}',
        image: e['image'] as String?,
        quantity: qty,
        unitPriceGhs: price,
        lineTotalGhs: price * qty,
        category: '${e['category'] ?? product?.category ?? 'miscellaneous'}',
        shipmentFeeGhs: ship < 0 ? 0 : ship,
      );
    }).toList();
    final merchandise = lines.fold<double>(0, (s, e) => s + e.lineTotalGhs);
    final shipmentFee =
        lines.fold<double>(0, (s, e) => s + e.shipmentLineTotal);
    final liveStreamId = (streamId != null && streamId.trim().isNotEmpty)
        ? streamId.trim()
        : items
            .map((e) => '${e['streamId'] ?? ''}'.trim())
            .firstWhere((id) => id.isNotEmpty, orElse: () => '');
    // Take units from the live bag only once payment is happening. Adding to
    // cart used to decrement immediately, so closing the room without paying
    // left the show sold out and no order.
    await _consumeLiveBag(items);
    final orderId =
        'ord_${const Uuid().v4().replaceAll('-', '').substring(0, 10)}';
    try {
      if (paymentMethods.contains('wallet')) {
        final payer = user;
        if (payer == null) {
          throw StateError('Sign in to pay from your payment account');
        }
        await PaymentAccountStore.spendFromWithdrawAccount(
          user: payer,
          amountGhs: merchandise + shipmentFee,
          ref: orderId,
        );
      }
    } catch (e) {
      await _releaseLiveBag(items);
      rethrow;
    }
    final order = Order(
      id: orderId,
      subtotalGhs: merchandise + shipmentFee,
      shipmentFeeGhs: shipmentFee,
      shipmentZoneLabel: _zoneLabelFor(quotes),
      status: 'paid',
      userId: user?.id,
      buyerName: dest.recipientName,
      buyerEmail: user?.email,
      streamId: liveStreamId.isEmpty ? streamId : liveStreamId,
      oneTap: oneTap,
      lines: lines,
      shipping: dest,
      paymentMethods: paymentMethods,
      paidToAccountId: PaymentAccount.adminId,
      deliveryEstimate: shipmentFee > 0
          ? ShipmentFee.customerNotice(
              orderId: orderId,
              quotes: quotes,
              totalGhs: shipmentFee,
            )
          : '',
      createdAt: DateTime.now().toUtc().toIso8601String(),
    );
    await LocalHuberStore.saveOrder(order);
    await AdminTreasuryStore.recordPaidOrder(order);
    await _sendShipmentToBuyer(order: order, quotes: quotes);
    return {'ok': true, 'order': order.toJson()};
  }

  /// Decrement the live bag for paid cart lines. Roll back if any line is
  /// already sold out so a partial checkout cannot keep units.
  Future<void> _consumeLiveBag(List<Map<String, dynamic>> items) async {
    final consumed = <({String streamId, String productId, int by})>[];
    try {
      for (final e in items) {
        final liveId = '${e['streamId'] ?? ''}'.trim();
        final productId = '${e['productId'] ?? ''}'.trim();
        final qty = _liveConsumeQty(e);
        if (liveId.isEmpty || productId.isEmpty || qty < 1) continue;
        final updated = await LocalCommerceStore.decrementLiveQuantity(
          streamId: liveId,
          productId: productId,
          by: qty,
        );
        consumed.add((streamId: liveId, productId: productId, by: qty));
        try {
          await CloudStore.upsertDocs(CloudStore.streams, [updated.toJson()]);
        } catch (_) {}
      }
    } catch (err) {
      for (final row in consumed.reversed) {
        await _releaseOne(row.streamId, row.productId, row.by);
      }
      rethrow;
    }
  }

  Future<void> _releaseLiveBag(List<Map<String, dynamic>> items) async {
    for (final e in items.reversed) {
      final liveId = '${e['streamId'] ?? ''}'.trim();
      final productId = '${e['productId'] ?? ''}'.trim();
      final qty = _liveConsumeQty(e);
      if (liveId.isEmpty || productId.isEmpty || qty < 1) continue;
      await _releaseOne(liveId, productId, qty);
    }
  }

  /// Shop units merged onto a live line must not drain the bag.
  static int _liveConsumeQty(Map<String, dynamic> item) {
    final liveId = '${item['streamId'] ?? ''}'.trim();
    if (liveId.isEmpty) return 0;
    if (item.containsKey('liveQuantity')) {
      final claimed = (item['liveQuantity'] as num?)?.toInt() ?? 0;
      return claimed < 0 ? 0 : claimed;
    }
    return (item['quantity'] as num?)?.toInt() ?? 1;
  }

  Future<void> _releaseOne(String streamId, String productId, int by) async {
    try {
      final restored = await LocalCommerceStore.releaseLiveQuantity(
        streamId: streamId,
        productId: productId,
        by: by,
      );
      if (restored != null) {
        await CloudStore.upsertDocs(CloudStore.streams, [restored.toJson()]);
      }
    } catch (_) {}
  }

  Future<void> _holdWithAdmin(Map<String, dynamic> data) async {
    try {
      final raw = data['order'] is Map
          ? Map<String, dynamic>.from(data['order'] as Map)
          : data;
      if (raw['id'] == null) return;
      final order = Order.fromJson(raw);
      await LocalHuberStore.saveOrder(order);
      await AdminTreasuryStore.recordPaidOrder(order);
    } catch (_) {}
  }

  static String _zoneLabelFor(List<ShipmentQuote> quotes) {
    if (quotes.isEmpty) return '';
    if (quotes.every((q) => q.outOfRegion)) return ShipmentFee.outOfRegionLabel;
    if (quotes.every((q) => !q.outOfRegion)) {
      final cities = quotes.map((q) => q.zoneLabel).where((e) => e.isNotEmpty);
      return cities.isEmpty ? '' : cities.first;
    }
    return '${quotes.firstWhere((q) => !q.outOfRegion).zoneLabel} · ${ShipmentFee.outOfRegionLabel}';
  }

  Future<void> _sendShipmentToBuyer({
    required Order order,
    required List<ShipmentQuote> quotes,
  }) async {
    final buyerId = order.userId?.trim() ?? '';
    if (buyerId.isEmpty || quotes.isEmpty || order.shipmentFeeGhs <= 0) return;
    final text = order.deliveryEstimate.trim().isNotEmpty
        ? order.deliveryEstimate
        : ShipmentFee.customerNotice(
            orderId: order.id,
            quotes: quotes,
            totalGhs: order.shipmentFeeGhs,
          );
    final sellerIds = order.lines
        .map((l) => l.sellerId?.trim() ?? '')
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final sellerId in sellerIds) {
      final seller = LocalCommerceStore.getSeller(sellerId);
      final fromId = (seller?.ownerUserId ?? seller?.id ?? '').trim();
      if (fromId.isEmpty || fromId == buyerId) continue;
      try {
        await LocalMessageStore.send(
          from: HubsomUser(
            id: fromId,
            email: '',
            name: seller?.name ?? 'Seller',
            role: 'seller',
            sellerId: sellerId,
          ),
          toUserId: buyerId,
          text: text,
          toUserName: order.buyerName,
        );
      } catch (_) {}
    }
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
