import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../models/huber.dart';
import '../../models/order.dart';
import '../../models/seller.dart';
import '../../models/shipment.dart';
import '../../models/user.dart';
import 'cloud_store.dart';
import 'ghana_places.dart';
import 'local_store.dart';

/// Device-local Huber riders, Hubsom offers, and deliveries when Hosting
/// has no API. No seeded demo riders — only accounts created via sign-up.
class LocalHuberStore {
  LocalHuberStore._();

  static const _profilesKey = 'huberProfiles';
  static const _offersKey = 'huberOffers';
  static const _deliveriesKey = 'huberDeliveries';
  static const _ordersKey = 'localOrders';
  static const _shipmentsKey = 'localShipments';
  static const _uuid = Uuid();

  static const defaultFeeGhs = 15.0;
  static const offerTtl = Duration(minutes: 15);

  static List<Map<String, dynamic>> _readList(String key) {
    final raw = LocalStore.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Seller? _sellerForShipment(String sellerId) {
    if (sellerId.isEmpty) return null;
    final raw = LocalStore.getString('localSellers');
    if (raw == null || raw.isEmpty) return null;
    try {
      final list = jsonDecode(raw) as List;
      for (final row in list) {
        if (row is! Map) continue;
        final data = Map<String, dynamic>.from(row);
        final id = '${data['id'] ?? ''}';
        final slug = '${data['slug'] ?? ''}';
        if (id == sellerId || slug == sellerId) {
          return Seller.fromJson(data);
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> _writeList(String key, List<Map<String, dynamic>> rows) async {
    await LocalStore.setString(key, jsonEncode(rows));
    final collection = switch (key) {
      _profilesKey => CloudStore.hubers,
      _offersKey => CloudStore.offers,
      _deliveriesKey => CloudStore.deliveries,
      _ordersKey => CloudStore.orders,
      _shipmentsKey => CloudStore.shipments,
      _ => null,
    };
    if (collection != null) {
      await CloudStore.upsertDocs(collection, rows);
    }
  }

  // --- profiles ---

  static List<HuberProfile> listProfiles() =>
      _readList(_profilesKey).map(HuberProfile.fromJson).toList();

  static HuberProfile? profileForUser(String userId) {
    for (final p in listProfiles()) {
      if (p.userId == userId || p.id == userId) return p;
    }
    return null;
  }

  static HuberProfile? profileById(String id) {
    for (final p in listProfiles()) {
      if (p.id == id) return p;
    }
    return null;
  }

  static Future<HuberProfile> upsertProfile(HuberProfile profile) async {
    final rows = listProfiles();
    final idx = rows.indexWhere((p) => p.id == profile.id || p.userId == profile.userId);
    if (idx >= 0) {
      rows[idx] = profile;
    } else {
      rows.add(profile);
    }
    await _writeList(_profilesKey, rows.map((e) => e.toJson()).toList());
    return profile;
  }

  static Future<HuberProfile> ensureProfileForUser(
    HubsomUser user, {
    HuberSignUpDetails? details,
  }) async {
    final existing = profileForUser(user.id);
    if (existing != null) return existing;
    final created = HuberProfile.fromUser(
      user,
      details: details ??
          HuberSignUpDetails(
            phone: user.phone ?? '',
            city: user.city ?? 'Accra',
            region: user.region ?? 'Greater Accra',
          ),
    );
    return upsertProfile(created);
  }

  static Future<HuberProfile> setOnline(String huberId, bool online) async {
    final profile = profileById(huberId);
    if (profile == null) {
      throw StateError('Huber profile not found');
    }
    if (online && !profile.isVerified) {
      throw StateError('Verify your identity before using Hub Now');
    }
    return upsertProfile(
      profile.copyWith(
        availability: online ? 'available' : 'offline',
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  static Future<HuberProfile> verifyIdentity({
    required String huberId,
    required String idType,
    required String idNumber,
  }) async {
    final profile = profileById(huberId);
    if (profile == null) throw StateError('Huber profile not found');
    if (idNumber.trim().length < 4) {
      throw StateError('Enter a valid ID number');
    }
    return upsertProfile(
      profile.copyWith(
        verificationStatus: 'approved',
        idType: idType,
        idNumber: idNumber.trim(),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  // --- orders / shipments (seller local fallback) ---

  static List<Order> listOrders() =>
      _readList(_ordersKey).map(Order.fromJson).toList();

  static Future<Order> saveOrder(Order order) async {
    final rows = listOrders();
    final idx = rows.indexWhere((o) => o.id == order.id);
    if (idx >= 0) {
      rows[idx] = order;
    } else {
      rows.insert(0, order);
    }
    await _writeList(_ordersKey, rows.map((e) => e.toJson()).toList());
    try {
      await CloudStore.upsertDocs(CloudStore.orders, [order.toJson()]);
    } catch (_) {}
    return order;
  }

  static Order? getOrder(String id) {
    for (final o in listOrders()) {
      if (o.id == id) return o;
    }
    return null;
  }

  static Future<Order> updateOrderStatus(String orderId, String status) async {
    final current = getOrder(orderId);
    if (current == null) throw StateError('Order not found');
    return saveOrder(current.copyWith(status: status));
  }

  static Future<void> syncOrdersForShipment(
    Shipment shipment,
    String orderStatus,
  ) async {
    for (final orderId in shipment.orderIds) {
      final order = getOrder(orderId);
      if (order == null) continue;
      if (order.status == orderStatus) continue;
      // Don't regress delivered / cancelled.
      if (order.status == 'delivered' || order.status == 'cancelled') continue;
      await saveOrder(order.copyWith(status: orderStatus));
    }
  }

  static Future<Shipment> markShipmentShipped(String shipmentId) async {
    final shipment = getShipment(shipmentId);
    if (shipment == null) throw StateError('Shipment not found');
    if (shipment.status != 'assigned') {
      throw StateError(
        'Wait for a Huber to accept, then ship. Current status: ${shipment.status}',
      );
    }
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = await saveShipment(
      shipment.copyWith(status: 'shipped', updatedAt: now),
    );
    await syncOrdersForShipment(updated, 'shipped');
    return updated;
  }

  static List<Shipment> listShipments() =>
      _readList(_shipmentsKey).map(Shipment.fromJson).toList();

  static Shipment? getShipment(String id) {
    for (final s in listShipments()) {
      if (s.id == id) return s;
    }
    return null;
  }

  static Future<Shipment> saveShipment(Shipment shipment) async {
    final rows = listShipments();
    final idx = rows.indexWhere((s) => s.id == shipment.id);
    if (idx >= 0) {
      rows[idx] = shipment;
    } else {
      rows.insert(0, shipment);
    }
    await _writeList(_shipmentsKey, rows.map((e) => e.toJson()).toList());
    try {
      await CloudStore.upsertDocs(CloudStore.shipments, [shipment.toJson()]);
    } catch (_) {}
    return shipment;
  }

  static Future<Shipment> createShipmentFromOrders({
    required List<String> orderIds,
    required String sellerId,
    required String createdByUserId,
  }) async {
    final orders = listOrders().where((o) => orderIds.contains(o.id)).toList();
    if (orders.isEmpty) {
      throw StateError('Select paid orders to consolidate');
    }
    final items = <ShipmentItem>[];
    for (final order in orders) {
      for (final line in order.lines) {
        items.add(
          ShipmentItem(
            orderId: order.id,
            productId: line.productId,
            name: line.name,
            quantity: line.quantity,
            image: line.image,
            lineTotalGhs: line.lineTotalGhs,
          ),
        );
      }
    }
    final shipping = orders
            .map((o) => o.shipping)
            .firstWhere((s) => s != null, orElse: () => null) ??
        const OrderShipping(
          recipientName: 'Buyer',
          phone: '',
          line1: 'Accra',
          city: 'Accra',
          region: 'Greater Accra',
          location: GeoLocation(
            latitude: 5.6037,
            longitude: -0.187,
            source: 'map-pin',
          ),
        );
    final dest = shipping.location == null
        ? OrderShipping(
            recipientName: shipping.recipientName,
            phone: shipping.phone,
            line1: shipping.line1,
            line2: shipping.line2,
            city: shipping.city,
            region: shipping.region,
            notes: shipping.notes,
            label: shipping.label,
            location: const GeoLocation(
              latitude: 5.6037,
              longitude: -0.187,
              source: 'map-pin',
            ),
          )
        : shipping;
    final now = DateTime.now().toUtc().toIso8601String();
    final created = await saveShipment(
      Shipment(
        id: 'shp_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
        sellerId: sellerId,
        createdByUserId: createdByUserId,
        orderIds: orderIds,
        items: items,
        destination: dest,
        status: 'ready',
        createdAt: now,
        updatedAt: now,
      ),
    );
    await syncOrdersForShipment(created, 'processing');
    return created;
  }

  // --- offers / deliveries ---

  static List<HuberOffer> listOffers() =>
      _readList(_offersKey).map(HuberOffer.fromJson).toList();

  static Future<void> _saveOffers(List<HuberOffer> offers) =>
      _writeList(_offersKey, offers.map((e) => e.toJson()).toList());

  static List<HuberOffer> openOffersForDriver(String huberId) {
    return listOffers()
        .where((o) => o.huberId == huberId && o.isOpen && !o.isExpired)
        .toList();
  }

  static List<HuberDelivery> listDeliveries() =>
      _readList(_deliveriesKey).map(HuberDelivery.fromJson).toList();

  static Future<void> _saveDeliveries(List<HuberDelivery> rows) =>
      _writeList(_deliveriesKey, rows.map((e) => e.toJson()).toList());

  static HuberDelivery? activeDeliveryFor(String huberId) {
    for (final d in listDeliveries()) {
      if (d.huberId == huberId && d.isActive) return d;
    }
    return null;
  }

  static HuberDelivery? deliveryById(String id) {
    for (final d in listDeliveries()) {
      if (d.id == id || d.shipmentId == id) return d;
    }
    return null;
  }

  static List<HuberDelivery> completedFor(String huberId) => listDeliveries()
      .where((d) => d.huberId == huberId && d.status == 'delivered')
      .toList();

  /// Fan out a Hubsom shipment to every registered Huber (no demo riders).
  static Future<({Shipment shipment, List<HuberOffer> offers})> dispatchToHubers(
    Shipment shipment, {
    double? preferredFeeGhs,
  }) async {
    if (shipment.status == 'cancelled' || shipment.status == 'delivered') {
      throw StateError('This shipment can’t accept new rider offers');
    }
    final riders = listProfiles();
    if (riders.isEmpty) {
      throw StateError(
        'No Huber drivers have signed up yet. Ask a rider to create a Huber account.',
      );
    }
    final now = DateTime.now().toUtc();
    final expiresAt = now.add(offerTtl).toIso8601String();
    final fee = preferredFeeGhs ??
        (defaultFeeGhs + shipment.items.length * 2).clamp(15, 80).toDouble();
    final dest = shipment.destination;
    final seller = _sellerForShipment(shipment.sellerId);
    final pickup = GhanaPlaces.resolve(
      address: seller?.address,
      city: seller?.city,
      region: seller?.region,
      latitude: seller?.latitude,
      longitude: seller?.longitude,
    );
    final pickupLabel = (seller?.address.trim().isNotEmpty == true)
        ? seller!.address.trim()
        : (seller?.displayLocation.isNotEmpty == true
            ? seller!.displayLocation
            : 'Seller pickup');
    final pickupCity = (seller?.city.trim().isNotEmpty == true)
        ? seller!.city.trim()
        : 'Accra';
    final sellerName = (seller?.name.trim().isNotEmpty == true)
        ? seller!.name.trim()
        : 'Hubsom seller';
    final offers = <HuberOffer>[];
    for (var i = 0; i < riders.length; i++) {
      final rider = riders[i];
      final riderPoint = GhanaPlaces.resolve(
        city: rider.city,
        region: rider.region,
      );
      final km = GhanaPlaces.distanceKm(riderPoint, pickup);
      offers.add(
        HuberOffer(
          id: 'off_${now.millisecondsSinceEpoch.toRadixString(36)}_$i',
          shipmentId: shipment.id,
          huberId: rider.id,
          huberName: rider.fullName,
          status: 'sent',
          offeredFeeGhs: fee,
          providerReference: 'hubsom:${shipment.id}:${rider.id}',
          createdAt: now.toIso8601String(),
          expiresAt: expiresAt,
          sellerName: sellerName,
          pickupLabel: pickupLabel,
          pickupCity: pickupCity,
          recipientName: dest.recipientName,
          dropoffLine1: dest.line1,
          dropoffCity: dest.city,
          itemCount: shipment.items.fold<int>(0, (s, e) => s + e.quantity),
          weightLbs: (shipment.items.length * 4).clamp(4, 40).toDouble(),
          pickupLatitude: pickup.latitude,
          pickupLongitude: pickup.longitude,
          dropoffLatitude: dest.location?.latitude,
          dropoffLongitude: dest.location?.longitude,
          pickupDistanceKm: km,
        ),
      );
    }

    final existing = listOffers()
        .where((o) => o.shipmentId != shipment.id)
        .toList();
    await _saveOffers([...offers, ...existing]);

    final contractOffers = offers
        .map(
          (o) => DeliveryOffer(
            id: o.id,
            shipmentId: o.shipmentId,
            huberId: o.huberId,
            huberName: o.huberName,
            status: o.status,
            offeredFeeGhs: o.offeredFeeGhs,
            providerReference: o.providerReference,
            createdAt: o.createdAt,
            expiresAt: o.expiresAt,
          ),
        )
        .toList();
    final updated = await saveShipment(
      shipment.copyWith(
        status: 'offering',
        offers: [...shipment.offers, ...contractOffers],
        updatedAt: now.toIso8601String(),
      ),
    );
    return (shipment: updated, offers: offers);
  }

  static Future<HuberDelivery> acceptOffer({
    required String offerId,
    required HuberProfile driver,
  }) async {
    final offers = listOffers();
    final idx = offers.indexWhere((o) => o.id == offerId);
    if (idx < 0) throw StateError('Offer not found');
    final offer = offers[idx];
    if (offer.huberId != driver.id) {
      throw StateError('This offer is for another rider');
    }
    if (offer.isExpired) throw StateError('This offer has expired');
    if (!offer.isOpen) throw StateError('This offer is no longer open');

    final now = DateTime.now().toUtc().toIso8601String();
    for (var i = 0; i < offers.length; i++) {
      if (offers[i].id == offerId) {
        offers[i] = offers[i].copyWith(status: 'accepted');
      } else if (offers[i].shipmentId == offer.shipmentId && offers[i].isOpen) {
        offers[i] = offers[i].copyWith(status: 'declined');
      }
    }
    await _saveOffers(offers);

    final shipment = getShipment(offer.shipmentId);
    if (shipment != null) {
      await saveShipment(
        shipment.copyWith(
          status: 'assigned',
          assignedHuberId: driver.id,
          assignedHuberName: driver.fullName,
          offers: shipment.offers
              .map(
                (o) => DeliveryOffer(
                  id: o.id,
                  shipmentId: o.shipmentId,
                  huberId: o.huberId,
                  huberName: o.huberName,
                  status: o.id == offerId
                      ? 'accepted'
                      : (o.shipmentId == offer.shipmentId &&
                              (o.status == 'sent' || o.status == 'queued')
                          ? 'declined'
                          : o.status),
                  offeredFeeGhs: o.offeredFeeGhs,
                  providerReference: o.providerReference,
                  createdAt: o.createdAt,
                  expiresAt: o.expiresAt,
                ),
              )
              .toList(),
          updatedAt: now,
        ),
      );
    }

    final decided = driver.completedCount + driver.declinedCount + 1;
    await upsertProfile(
      driver.copyWith(
        availability: 'busy',
        acceptanceRate: decided == 0 ? 1 : (driver.completedCount + 1) / decided,
        updatedAt: now,
      ),
    );

    final delivery = HuberDelivery(
      id: 'del_${_uuid.v4().replaceAll('-', '').substring(0, 10)}',
      offerId: offer.id,
      shipmentId: offer.shipmentId,
      huberId: driver.id,
      status: 'accepted',
      sellerName: offer.sellerName,
      pickupAddress: '${offer.pickupLabel}, ${offer.pickupCity}',
      customerName: offer.recipientName,
      dropoffAddress: '${offer.dropoffLine1}, ${offer.dropoffCity}',
      feeGhs: offer.offeredFeeGhs ?? defaultFeeGhs,
      pickupLatitude: offer.pickupLatitude,
      pickupLongitude: offer.pickupLongitude,
      dropoffLatitude: offer.dropoffLatitude,
      dropoffLongitude: offer.dropoffLongitude,
      createdAt: now,
      updatedAt: now,
    );
    final deliveries = listDeliveries();
    deliveries.insert(0, delivery);
    await _saveDeliveries(deliveries);
    final assignedShipment = getShipment(offer.shipmentId);
    if (assignedShipment != null) {
      await syncOrdersForShipment(assignedShipment, 'processing');
    }
    return delivery;
  }

  static Future<void> declineOffer({
    required String offerId,
    required HuberProfile driver,
  }) async {
    final offers = listOffers();
    final idx = offers.indexWhere((o) => o.id == offerId);
    if (idx < 0) throw StateError('Offer not found');
    offers[idx] = offers[idx].copyWith(status: 'declined');
    await _saveOffers(offers);
    final decided = driver.completedCount + driver.declinedCount + 1;
    await upsertProfile(
      driver.copyWith(
        declinedCount: driver.declinedCount + 1,
        acceptanceRate: driver.completedCount / decided,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );
  }

  static Future<HuberDelivery> advanceDelivery(String deliveryId) async {
    final rows = listDeliveries();
    final idx = rows.indexWhere((d) => d.id == deliveryId);
    if (idx < 0) throw StateError('Delivery not found');
    final current = rows[idx];
    final nextStatus = switch (current.status) {
      'accepted' => 'en_route_pickup',
      'en_route_pickup' => 'arrived_pickup',
      'arrived_pickup' => 'picked_up',
      'picked_up' => 'en_route_dropoff',
      'en_route_dropoff' => 'arrived_dropoff',
      'arrived_dropoff' => 'delivered',
      _ => current.status,
    };
    final now = DateTime.now().toUtc().toIso8601String();
    final updated = current.copyWith(status: nextStatus, updatedAt: now);
    rows[idx] = updated;
    await _saveDeliveries(rows);

    final shipment = getShipment(current.shipmentId);
    if (shipment != null) {
      final mapped = switch (nextStatus) {
        'picked_up' || 'en_route_dropoff' || 'arrived_dropoff' =>
          'out_for_delivery',
        'delivered' => 'delivered',
        _ => shipment.status,
      };
      final updatedShipment =
          await saveShipment(shipment.copyWith(status: mapped, updatedAt: now));
      if (mapped == 'out_for_delivery' || mapped == 'shipped') {
        await syncOrdersForShipment(updatedShipment, 'shipped');
      } else if (mapped == 'delivered') {
        await syncOrdersForShipment(updatedShipment, 'delivered');
      }
    }

    if (nextStatus == 'delivered') {
      final driver = profileById(current.huberId);
      if (driver != null) {
        final completed = driver.completedCount + 1;
        final decided = completed + driver.declinedCount;
        await upsertProfile(
          driver.copyWith(
            availability: 'available',
            completedCount: completed,
            walletBalanceGhs: driver.walletBalanceGhs + current.feeGhs,
            todayEarningsGhs: driver.todayEarningsGhs + current.feeGhs,
            acceptanceRate: decided == 0 ? 1 : completed / decided,
            rating: driver.rating == 0 ? 5 : driver.rating,
            updatedAt: now,
          ),
        );
      }
    }
    return updated;
  }

  static Future<HuberDelivery> completeWithPod(String deliveryId) async {
    var delivery = deliveryById(deliveryId);
    if (delivery == null) throw StateError('Delivery not found');
    while (delivery!.status != 'delivered') {
      delivery = await advanceDelivery(delivery.id);
      if (delivery.status == 'arrived_dropoff') {
        delivery = await advanceDelivery(delivery.id);
        break;
      }
    }
    return delivery;
  }
}
