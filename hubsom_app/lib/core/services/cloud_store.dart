import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/firebase_options.dart';
import 'firebase_bootstrap.dart';
import 'local_store.dart';
import 'shop_video_merge.dart';

/// Firestore-backed Hubsom data so accounts work on any browser/device.
///
/// Uses the FlutterFire SDK when it is ready, and always falls back to the
/// public Firestore REST API. Sign-up must succeed against this database —
/// the on-device vault is only a cache.
class CloudStore {
  CloudStore._();

  static const accounts = 'accounts';
  static const hubers = 'hubers';
  static const offers = 'huberOffers';
  static const purchaseOffers = 'purchaseOffers';
  static const promotions = 'promotions';
  static const adminControls = 'adminControls';
  static const adminPayouts = 'adminPayouts';
  static const adminIntakes = 'adminIntakes';
  static const paymentAccounts = 'paymentAccounts';
  static const deliveries = 'huberDeliveries';
  static const orders = 'orders';
  static const shipments = 'shipments';
  static const products = 'products';
  static const sellers = 'sellers';
  static const streams = 'streams';
  static const liveSignals = 'liveSignals';
  static const productComments = 'productComments';
  static const timelinePosts = 'timelinePosts';
  static const productLikes = 'productLikes';
  static const productReviews = 'productReviews';
  static const shopVideos = 'shopVideos';
  static const directMessages = 'directMessages';
  static const notifications = 'notifications';
  static const withdrawals = 'withdrawals';
  static const giftLedger = 'giftLedger';
  static const giftHostEarnings = 'giftHostEarnings';

  /// Tests set this to false so they do not write to production Firestore.
  static bool useNetwork = true;

  /// Test-only account documents returned by [getAccount] without the network.
  @visibleForTesting
  static final Map<String, Map<String, dynamic>> debugAccounts = {};

  static final Dio _rest = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 12),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      validateStatus: (s) => s != null && s < 500,
    ),
  );

  static String get _projectId => DefaultFirebaseOptions.web.projectId;
  static String get _apiKey => DefaultFirebaseOptions.web.apiKey;

  static String get _root =>
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  static FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.ready) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get available => useNetwork;

  /// Stable account document id: lowercase email with invisible chars stripped.
  static String accountDocId(String email) {
    return email
        .replaceAll(RegExp(r'[\u200B-\u200D\uFEFF]'), '')
        .trim()
        .toLowerCase();
  }

  static Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data == null) return null;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty || trimmed.startsWith('<')) return null;
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return null;
  }

  static Map<String, dynamic>? _accountFromResponse(dynamic data) {
    final map = _asJsonMap(data);
    if (map == null) return null;
    if (map['error'] != null) {
      final err = map['error'];
      final code = err is Map ? err['code'] : null;
      final status = err is Map ? '${err['status']}' : '';
      if (code == 404 || status == 'NOT_FOUND') return null;
      throw StateError('Could not read Hubsom account: ${map['error']}');
    }
    final decoded = decodeDocument(map);
    return decoded.isEmpty ? null : decoded;
  }

  /// Reads an account from the live Firestore REST API (document id, then email query).
  ///
  /// The FlutterFire SDK is not used for auth: it can succeed against IndexedDB
  /// without the server, which made new browsers look like they had no account.
  static Future<Map<String, dynamic>?> getAccount(String email) async {
    final id = accountDocId(email);
    if (id.isEmpty || !id.contains('@')) return null;
    final debug = debugAccounts[id];
    if (debug != null) return Map<String, dynamic>.from(debug);
    if (!useNetwork) return null;

    Object? lastError;
    for (final pathId in <String>[Uri.encodeComponent(id), id]) {
      try {
        final res = await _rest.get<dynamic>(
          '$_root/$accounts/$pathId',
          queryParameters: {'key': _apiKey},
        );
        if (res.statusCode == 404) continue;
        final account = _accountFromResponse(res.data);
        if (account != null) return account;
      } on DioException catch (e) {
        if (e.response?.statusCode == 404) continue;
        lastError = e;
      } catch (e) {
        lastError = e;
      }
    }

    try {
      final queried = await _queryAccountByEmail(id);
      if (queried != null) return queried;
    } catch (e) {
      lastError = e;
    }

    if (lastError != null) {
      throw StateError(
        'Could not reach Hubsom right now. Check your connection.',
      );
    }
    return null;
  }

  static Future<Map<String, dynamic>?> _queryAccountByEmail(String email) async {
    final res = await _rest.post<dynamic>(
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery',
      queryParameters: {'key': _apiKey},
      data: {
        'structuredQuery': {
          'from': [
            {'collectionId': accounts},
          ],
          'where': {
            'fieldFilter': {
              'field': {'fieldPath': 'email'},
              'op': 'EQUAL',
              'value': {'stringValue': email},
            },
          },
          'limit': 1,
        },
      },
    );
    final data = res.data;
    if (data is! List) return null;
    for (final row in data) {
      if (row is! Map) continue;
      final doc = row['document'];
      if (doc == null) continue;
      final account = _accountFromResponse(doc);
      if (account != null) return account;
    }
    return null;
  }

  static const alreadyExistsCode = 'account_already_exists';

  /// Writes an account and refuses to return until the server can read it back.
  ///
  /// When [createOnly] is true, an existing Firestore account is not overwritten.
  static Future<void> putAccount(
    String email,
    Map<String, dynamic> data, {
    bool createOnly = false,
  }) async {
    if (!useNetwork) {
      throw StateError('Account database is disabled in this environment');
    }
    final id = accountDocId(email);
    final payload = {
      ...data,
      'email': id,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    };

    if (createOnly) {
      final existing = await getAccount(id);
      if (existing != null) {
        throw StateError(alreadyExistsCode);
      }
      // POST create — PATCH would overwrite if two signups raced.
      final res = await _rest.post<dynamic>(
        '$_root/$accounts',
        queryParameters: {
          'key': _apiKey,
          'documentId': id,
        },
        data: {'fields': encodeFields(payload)},
      );
      final code = res.statusCode ?? 0;
      final err = _asJsonMap(res.data)?['error'];
      final status = err is Map ? '${err['status']}' : '';
      if (code == 409 || status == 'ALREADY_EXISTS') {
        throw StateError(alreadyExistsCode);
      }
      if (code < 200 || code >= 300) {
        throw StateError(
          'Could not save your account'
          '${res.data != null ? ': ${res.data}' : ''}',
        );
      }
    } else {
      // Gift / follow / profile writes often send only salt+hash+userJson.
      // A REST PATCH without updateMask replaces the document and deletes
      // omitted fields — passkeys and admin suspension among them.
      final fields = encodeFields(payload);
      final res = await _rest.patch<dynamic>(
        '$_root/$accounts/${Uri.encodeComponent(id)}',
        queryParameters: accountPatchQuery(
          apiKey: _apiKey,
          fields: fields,
        ),
        data: {'fields': fields},
      );
      if (res.statusCode == null ||
          res.statusCode! < 200 ||
          res.statusCode! >= 300) {
        throw StateError(
          'Could not save your account'
          '${res.data != null ? ': ${res.data}' : ''}',
        );
      }
    }

    final verify = await getAccount(id);
    if (verify == null || accountDocId('${verify['email']}') != id) {
      throw StateError(
        'Could not verify your account was saved. Try again.',
      );
    }
  }

  static Future<void> upsertDocs(
    String collection,
    List<Map<String, dynamic>> rows,
  ) async {
    if (!useNetwork || rows.isEmpty) return;
    final sdk = _db;
    if (sdk != null) {
      try {
        // Firestore batches are capped (~500 ops / ~10MB). Commit in slices.
        const sliceSize = 20;
        for (var i = 0; i < rows.length; i += sliceSize) {
          final slice = rows.sublist(
            i,
            (i + sliceSize) > rows.length ? rows.length : i + sliceSize,
          );
          final batch = sdk.batch();
          var ops = 0;
          for (final row in slice) {
            final id = '${row['id'] ?? ''}';
            if (id.isEmpty) continue;
            batch.set(
              sdk.collection(collection).doc(id),
              row,
              SetOptions(merge: true),
            );
            ops++;
          }
          if (ops > 0) await batch.commit();
        }
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.upsertDocs sdk: $e');
      }
    }
    for (final row in rows) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      try {
        final res = await _rest.patch<dynamic>(
          '$_root/$collection/${Uri.encodeComponent(id)}',
          queryParameters: {'key': _apiKey},
          data: {'fields': encodeFields(row)},
        );
        final code = res.statusCode ?? 0;
        if (code < 200 || code >= 300) {
          // Create when patch cannot update a missing doc.
          await _rest.post<dynamic>(
            '$_root/$collection',
            queryParameters: {
              'key': _apiKey,
              'documentId': id,
            },
            data: {'fields': encodeFields(row)},
          );
        }
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.upsertDocs rest: $e');
      }
    }
  }

  static Future<void> deleteDoc(String collection, String id) async {
    if (!useNetwork || id.isEmpty) return;
    final sdk = _db;
    if (sdk != null) {
      try {
        await sdk.collection(collection).doc(id).delete();
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.deleteDoc sdk: $e');
      }
    }
    try {
      await _rest.delete<dynamic>(
        '$_root/$collection/${Uri.encodeComponent(id)}',
        queryParameters: {'key': _apiKey},
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.deleteDoc rest: $e');
    }
  }

  /// One document by id. Used for shop-video chunks so a slow phone does not
  /// download every video in the collection just to play one clip.
  static Future<Map<String, dynamic>?> getDoc(
    String collection,
    String id,
  ) async {
    if (!useNetwork || id.isEmpty) return null;
    final sdk = _db;
    if (sdk != null) {
      try {
        final snap = await sdk
            .collection(collection)
            .doc(id)
            .get()
            .timeout(const Duration(seconds: 20));
        if (!snap.exists) return null;
        final data = Map<String, dynamic>.from(snap.data() ?? const {});
        data.putIfAbsent('id', () => snap.id);
        return data;
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.getDoc sdk: $e');
      }
    }
    try {
      final res = await _rest.get<dynamic>(
        '$_root/$collection/${Uri.encodeComponent(id)}',
        queryParameters: {'key': _apiKey},
      );
      if (res.statusCode == 404) return null;
      final map = _asJsonMap(res.data);
      if (map == null || map['error'] != null) return null;
      final decoded = decodeDocument(map);
      if (decoded.isEmpty) return null;
      decoded.putIfAbsent('id', () => id);
      return decoded;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.getDoc rest: $e');
      return null;
    }
  }

  /// Docs where [field] == [value]. Used for shop-video chunks so a phone never
  /// downloads every clip's chunks to find one video.
  static Future<List<Map<String, dynamic>>> queryDocs(
    String collection, {
    required String field,
    required String value,
  }) async {
    if (!useNetwork || field.isEmpty || value.isEmpty) return const [];
    final sdk = _db;
    if (sdk != null) {
      try {
        final snap = await sdk
            .collection(collection)
            .where(field, isEqualTo: value)
            .get()
            .timeout(const Duration(seconds: 45));
        return snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data.putIfAbsent('id', () => d.id);
          return data;
        }).toList();
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.queryDocs sdk: $e');
      }
    }
    try {
      final res = await _rest.post<dynamic>(
        '$_root:runQuery',
        queryParameters: {'key': _apiKey},
        data: {
          'structuredQuery': {
            'from': [
              {'collectionId': collection},
            ],
            'where': {
              'fieldFilter': {
                'field': {'fieldPath': field},
                'op': 'EQUAL',
                'value': {'stringValue': value},
              },
            },
          },
        },
      );
      final data = res.data;
      if (data is! List) return const [];
      final out = <Map<String, dynamic>>[];
      for (final item in data) {
        if (item is! Map) continue;
        final doc = item['document'];
        if (doc is! Map) continue;
        final decoded = decodeDocument(doc);
        if (decoded.isEmpty) continue;
        final name = '${doc['name'] ?? ''}';
        final docId = name.split('/').last;
        if (docId.isNotEmpty) decoded.putIfAbsent('id', () => docId);
        out.add(decoded);
      }
      return out;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.queryDocs rest: $e');
      return const [];
    }
  }

  /// True when Firestore can push collection changes instead of being polled.
  static bool get canWatch => useNetwork && _db != null;

  /// Emits every time [collection] changes server-side.
  ///
  /// Callers use this to refresh instead of waiting out a poll interval, which
  /// is what made a seller going live take so long to show up for users.
  static Stream<void> watchCollection(String collection) {
    if (!canWatch) return const Stream.empty();
    final sdk = _db;
    if (sdk == null) return const Stream.empty();
    return sdk
        .collection(collection)
        .snapshots()
        .map<void>((_) {})
        .handleError((_) {});
  }

  static Future<List<Map<String, dynamic>>> listDocs(String collection) async {
    if (!useNetwork) return const [];
    final sdk = _db;
    if (sdk != null) {
      try {
        final snap = await sdk
            .collection(collection)
            .get()
            .timeout(const Duration(seconds: 30));
        return snap.docs.map((d) {
          final data = Map<String, dynamic>.from(d.data());
          data.putIfAbsent('id', () => d.id);
          return data;
        }).toList();
      } catch (e) {
        if (kDebugMode) debugPrint('CloudStore.listDocs sdk: $e');
      }
    }
    try {
      final res = await _rest.get<dynamic>(
        '$_root/$collection',
        queryParameters: {'key': _apiKey, 'pageSize': 300},
      );
      final data = res.data;
      if (data is! Map) return const [];
      final docs = data['documents'];
      if (docs is! List) return const [];
      return docs.whereType<Map>().map((d) {
        final decoded = decodeDocument(d);
        if (decoded.isEmpty) return <String, dynamic>{};
        // REST name ends with .../documents/collection/docId
        final name = '${d['name'] ?? ''}';
        final docId = name.split('/').isNotEmpty ? name.split('/').last : '';
        if (docId.isNotEmpty) decoded.putIfAbsent('id', () => docId);
        return decoded;
      }).where((d) => d.isNotEmpty).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.listDocs rest: $e');
      return const [];
    }
  }

  static Future<void> hydrateLocalCache() async {
    if (!useNetwork) return;
    final mapping = <String, String>{
      'huberProfiles': hubers,
      'huberOffers': offers,
      'huberDeliveries': deliveries,
      'localOrders': orders,
      'localShipments': shipments,
      'localProducts': products,
      'localSellers': sellers,
      'localStreams': streams,
      'localProductComments': productComments,
      'localTimelinePosts': timelinePosts,
      'localProductLikes': productLikes,
      'localProductReviews': productReviews,
      'localShopVideos': shopVideos,
      'localDirectMessages': directMessages,
      'localNotifications': notifications,
      'purchaseOffers': purchaseOffers,
      'promotions': promotions,
      'adminPayouts': adminPayouts,
      'adminIntakes': adminIntakes,
      'paymentAccounts': paymentAccounts,
      'withdrawals': withdrawals,
      'localGiftLedger': giftLedger,
    };
    await Future.wait(mapping.entries.map((entry) async {
      try {
        final rows = await listDocs(entry.value);
        if (rows.isEmpty) return;
        if (entry.key == 'localShopVideos') {
          final raw = LocalStore.getString(entry.key);
          final local = <Map<String, dynamic>>[];
          if (raw != null && raw.isNotEmpty) {
            try {
              final decoded = jsonDecode(raw);
              if (decoded is List) {
                for (final e in decoded) {
                  if (e is Map) {
                    local.add(Map<String, dynamic>.from(e));
                  }
                }
              }
            } catch (_) {}
          }
          await LocalStore.setString(
            entry.key,
            jsonEncode(mergeShopVideoDocs(local: local, incoming: rows)),
          );
          return;
        }
        if (entry.key == 'localGiftLedger') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(mergeDocsById(localKey: entry.key, incoming: rows)),
          );
          return;
        }
        if (entry.key == 'paymentAccounts') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergePaymentAccountDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'withdrawals') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeWithdrawalDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'localOrders') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeOrderDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'localShipments') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeShipmentDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'adminPayouts') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergePayoutDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'adminIntakes') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeIntakeDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'huberDeliveries') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeDeliveryDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'huberProfiles') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeHuberProfileDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        if (entry.key == 'localStreams') {
          await LocalStore.setString(
            entry.key,
            jsonEncode(
              mergeStreamDocs(localKey: entry.key, incoming: rows),
            ),
          );
          return;
        }
        await LocalStore.setString(entry.key, jsonEncode(rows));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CloudStore.hydrateLocalCache ${entry.value}: $e');
        }
      }
    }));
  }

  /// Union local + cloud rows by `id` so a partial snapshot cannot drop
  /// unsynced gift sends the host still needs to get paid.
  static List<Map<String, dynamic>> mergeDocsById({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    final raw = LocalStore.getString(localKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final e in decoded) {
            if (e is! Map) continue;
            final row = Map<String, dynamic>.from(e);
            final id = '${row['id'] ?? ''}';
            if (id.isNotEmpty) byId[id] = row;
          }
        }
      } catch (_) {}
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      byId.putIfAbsent(id, () => row);
    }
    return byId.values.toList();
  }

  /// Keep a cash-out that already debited the wallet when cloud is behind.
  ///
  /// Replacing `withdrawals` with the Firestore list dropped a pending
  /// request after `PaymentAccountStore.withdraw` had already reduced the
  /// balance. The money was gone and admin had nothing to process.
  static List<Map<String, dynamic>> mergeWithdrawalDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeWithdrawalRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeWithdrawalRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      if (current == null) {
        byId[id] = row;
        continue;
      }
      // Processed wins so an admin mark is not reverted, and a local
      // pending cash-out is not dropped when the snapshot is stale.
      if (_withdrawalProcessed(row) && !_withdrawalProcessed(current)) {
        byId[id] = row;
      }
    }
    return byId.values.toList();
  }

  static bool _withdrawalProcessed(Map<String, dynamic> row) {
    return '${row['status'] ?? ''}' == 'processed' ||
        '${row['processedAt'] ?? ''}'.trim().isNotEmpty;
  }

  /// Keep the spend/payout that actually happened when cloud is behind.
  ///
  /// Replacing `paymentAccounts` with the Firestore list let a stale snapshot
  /// restore a wallet after checkout or withdrawal. The next spend then
  /// paid with money that was already gone.
  static List<Map<String, dynamic>> mergePaymentAccountDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergePaymentAccountRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergePaymentAccountRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferFresherPaymentAccount(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferFresherPaymentAccount({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final localAt = _paymentAccountUpdatedAt(local);
    final incomingAt = _paymentAccountUpdatedAt(incoming);
    if (localAt != null && incomingAt != null) {
      if (incomingAt.isAfter(localAt)) return incoming;
      if (localAt.isAfter(incomingAt)) return local;
    } else if (incomingAt != null && localAt == null) {
      return incoming;
    } else if (localAt != null && incomingAt == null) {
      return local;
    }
    // No clock on either side: keep the local spend so hydrate cannot
    // resurrect the pre-checkout balance.
    return local;
  }

  static DateTime? _paymentAccountUpdatedAt(Map<String, dynamic> row) {
    final raw = '${row['updatedAt'] ?? ''}'.trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  /// Keep a paid order that already debited the wallet when cloud is behind.
  ///
  /// Replacing `localOrders` with the Firestore list dropped a checkout after
  /// `PaymentService.checkout` had already saved the order (and spent the
  /// wallet). The money was gone and the seller never saw the sale.
  static List<Map<String, dynamic>> mergeOrderDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeOrderRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeOrderRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferOrderRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferOrderRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final localTerminal = _orderTerminal(local);
    final incomingTerminal = _orderTerminal(incoming);
    // Do not resurrect a cancelled/refunded sale from a stale paid copy.
    if (localTerminal && !incomingTerminal) return local;
    if (incomingTerminal && !localTerminal) return incoming;
    return _orderFulfillmentRank(incoming) > _orderFulfillmentRank(local)
        ? incoming
        : local;
  }

  static const _terminalOrderStatus = {
    'cancelled',
    'canceled',
    'refunded',
  };

  static bool _orderTerminal(Map<String, dynamic> row) {
    return _terminalOrderStatus.contains('${row['status'] ?? ''}'.toLowerCase());
  }

  static int _orderFulfillmentRank(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}'.toLowerCase()) {
      case 'delivered':
        return 5;
      case 'shipped':
      case 'out_for_delivery':
        return 4;
      case 'processing':
        return 3;
      case 'paid':
        return 2;
      case 'cancelled':
      case 'canceled':
        return 1;
      default:
        return 0;
    }
  }

  /// Keep a consolidated lot that already occupies paid orders when cloud
  /// is behind.
  ///
  /// Replacing `localShipments` with the Firestore list dropped a shipment
  /// after `createShipmentFromOrders` had already marked the orders
  /// processing. Consolidate then created a second lot, and two riders
  /// could be paid for one order.
  static List<Map<String, dynamic>> mergeShipmentDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeShipmentRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeShipmentRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferShipmentRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferShipmentRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final localTerminal = _shipmentCancelled(local);
    final incomingTerminal = _shipmentCancelled(incoming);
    // Do not resurrect a cancelled lot from a stale ready copy.
    if (localTerminal && !incomingTerminal) return local;
    if (incomingTerminal && !localTerminal) return incoming;
    final incomingRank = _shipmentFulfillmentRank(incoming);
    final localRank = _shipmentFulfillmentRank(local);
    if (incomingRank > localRank) return incoming;
    if (localRank > incomingRank) return local;
    // Same rank: keep the rider assignment so hydrate cannot reopen a
    // taken lot as an unassigned offer.
    if (_shipmentAssignedHuber(incoming).isNotEmpty &&
        _shipmentAssignedHuber(local).isEmpty) {
      return incoming;
    }
    return local;
  }

  static const _cancelledShipmentStatus = {
    'cancelled',
    'canceled',
  };

  static bool _shipmentCancelled(Map<String, dynamic> row) {
    return _cancelledShipmentStatus
        .contains('${row['status'] ?? ''}'.toLowerCase());
  }

  static String _shipmentAssignedHuber(Map<String, dynamic> row) {
    return '${row['assignedHuberId'] ?? ''}'.trim();
  }

  /// Keep a paid or voided seller payout when cloud is behind.
  ///
  /// Replacing `adminPayouts` with the Firestore list restored a pending
  /// payout after `paySeller` or after `reverseCancelledOrder` had already
  /// refunded the buyer. Admin then paid 94% on a sale that was gone.
  static List<Map<String, dynamic>> mergePayoutDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergePayoutRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergePayoutRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      if (current == null) {
        if (_payoutRank(row) == 0 && _orderCancelledForPayout(row)) {
          continue;
        }
        byId[id] = row;
        continue;
      }
      byId[id] = preferPayoutRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferPayoutRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    return _payoutRank(incoming) > _payoutRank(local) ? incoming : local;
  }

  /// paid > cancelled > pending so a stale pending copy cannot reopen a
  /// finished or voided payout.
  static int _payoutRank(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}'.toLowerCase()) {
      case 'paid':
        return 2;
      case 'cancelled':
      case 'canceled':
        return 1;
      default:
        return 0;
    }
  }

  static bool _orderCancelledForPayout(Map<String, dynamic> row) {
    final orderId = '${row['orderId'] ?? ''}'.trim();
    if (orderId.isEmpty) return false;
    for (final order in _localDocList('localOrders')) {
      if ('${order['id'] ?? ''}' != orderId) continue;
      return _orderTerminal(order);
    }
    return false;
  }

  /// Keep a local intake a stale snapshot omitted, and do not resurrect a
  /// reversed collection after cancel refunded the buyer.
  static List<Map<String, dynamic>> mergeIntakeDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeIntakeRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeIntakeRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      if (current == null) {
        if (!_intakeReversed(row) && _orderCancelledForIntake(row)) {
          continue;
        }
        byId[id] = row;
        continue;
      }
      byId[id] = preferIntakeRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  @visibleForTesting
  static Map<String, dynamic> preferIntakeRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    if (_intakeReversed(local) && !_intakeReversed(incoming)) return local;
    if (_intakeReversed(incoming) && !_intakeReversed(local)) return incoming;
    return local;
  }

  static bool _intakeReversed(Map<String, dynamic> row) {
    return row['reversed'] == true;
  }

  static bool _orderCancelledForIntake(Map<String, dynamic> row) {
    if ('${row['source'] ?? ''}' != 'order') return false;
    final orderId = '${row['refId'] ?? ''}'.trim();
    if (orderId.isEmpty) return false;
    for (final order in _localDocList('localOrders')) {
      if ('${order['id'] ?? ''}' != orderId) continue;
      return _orderTerminal(order);
    }
    return false;
  }

  static int _shipmentFulfillmentRank(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}'.toLowerCase()) {
      case 'delivered':
        return 6;
      case 'out_for_delivery':
        return 5;
      case 'shipped':
        return 4;
      case 'assigned':
        return 3;
      case 'offering':
        return 2;
      case 'ready':
        return 1;
      default:
        return 0;
    }
  }

  /// Keep a completed delivery when cloud is behind.
  ///
  /// Replacing `huberDeliveries` with the Firestore list reset Proof of
  /// delivery back to accepted. The rider tapped complete again and the
  /// wallet was credited a second time for the same shipment.
  static List<Map<String, dynamic>> mergeDeliveryDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeDeliveryRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeDeliveryRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferDeliveryRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferDeliveryRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final localCancelled = _deliveryCancelled(local);
    final incomingCancelled = _deliveryCancelled(incoming);
    if (localCancelled && !incomingCancelled && !_deliveryDelivered(incoming)) {
      return local;
    }
    if (incomingCancelled && !localCancelled && !_deliveryDelivered(local)) {
      return incoming;
    }
    return _deliveryFulfillmentRank(incoming) > _deliveryFulfillmentRank(local)
        ? incoming
        : local;
  }

  static bool _deliveryCancelled(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}'.toLowerCase()) {
      case 'cancelled':
      case 'canceled':
        return true;
      default:
        return false;
    }
  }

  static bool _deliveryDelivered(Map<String, dynamic> row) {
    return '${row['status'] ?? ''}'.toLowerCase() == 'delivered';
  }

  static int _deliveryFulfillmentRank(Map<String, dynamic> row) {
    switch ('${row['status'] ?? ''}'.toLowerCase()) {
      case 'delivered':
        return 7;
      case 'arrived_dropoff':
        return 6;
      case 'en_route_dropoff':
        return 5;
      case 'picked_up':
        return 4;
      case 'arrived_pickup':
        return 3;
      case 'en_route_pickup':
        return 2;
      case 'accepted':
        return 1;
      default:
        return 0;
    }
  }

  /// Keep rider earnings that already landed when cloud is behind.
  ///
  /// Replacing `huberProfiles` with the Firestore list restored a pre-drop
  /// wallet after Proof of delivery had already credited the fee. The rider
  /// either lost the pay, or completed again and was paid twice.
  static List<Map<String, dynamic>> mergeHuberProfileDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeHuberProfileRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeHuberProfileRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferHuberProfileRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferHuberProfileRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final localAt = _huberProfileUpdatedAt(local);
    final incomingAt = _huberProfileUpdatedAt(incoming);
    if (localAt != null && incomingAt != null) {
      if (incomingAt.isAfter(localAt)) return incoming;
      if (localAt.isAfter(incomingAt)) return local;
    } else if (incomingAt != null && localAt == null) {
      return incoming;
    } else if (localAt != null && incomingAt == null) {
      return local;
    }
    final incomingWallet = _huberWallet(incoming);
    final localWallet = _huberWallet(local);
    if (incomingWallet > localWallet) return incoming;
    if (localWallet > incomingWallet) return local;
    final incomingDone = _huberCompletedCount(incoming);
    final localDone = _huberCompletedCount(local);
    if (incomingDone > localDone) return incoming;
    return local;
  }

  static DateTime? _huberProfileUpdatedAt(Map<String, dynamic> row) {
    final raw = '${row['updatedAt'] ?? ''}'.trim();
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static double _huberWallet(Map<String, dynamic> row) {
    final value = row['walletBalanceGhs'];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static int _huberCompletedCount(Map<String, dynamic> row) {
    final value = row['completedCount'];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  /// Keep the live bag that already sold when cloud is behind.
  ///
  /// Replacing `localStreams` with the Firestore list restored pre-checkout
  /// `productQuantities` after `_consumeLiveBag` had already decremented.
  /// A second checkout then wrote another paid order for the last unit.
  static List<Map<String, dynamic>> mergeStreamDocs({
    required String localKey,
    required List<Map<String, dynamic>> incoming,
  }) {
    return mergeStreamRows(
      local: _localDocList(localKey),
      incoming: incoming,
    );
  }

  @visibleForTesting
  static List<Map<String, dynamic>> mergeStreamRows({
    required List<Map<String, dynamic>> local,
    required List<Map<String, dynamic>> incoming,
  }) {
    final byId = <String, Map<String, dynamic>>{};
    for (final row in local) {
      final id = '${row['id'] ?? ''}';
      if (id.isNotEmpty) byId[id] = row;
    }
    for (final row in incoming) {
      final id = '${row['id'] ?? ''}';
      if (id.isEmpty) continue;
      final current = byId[id];
      byId[id] = current == null
          ? row
          : preferStreamRow(local: current, incoming: row);
    }
    return byId.values.toList();
  }

  /// [local] is this device's copy. [incoming] is the cloud snapshot.
  @visibleForTesting
  static Map<String, dynamic> preferStreamRow({
    required Map<String, dynamic> local,
    required Map<String, dynamic> incoming,
  }) {
    final out = Map<String, dynamic>.from(local);
    final quantities = _minProductQuantities(local, incoming);
    if (quantities.isEmpty) {
      out.remove('productQuantities');
    } else {
      out['productQuantities'] = quantities;
    }
    out['productIds'] = _unionStringIds(
      local['productIds'],
      incoming['productIds'],
    );
    if (_streamEnded(incoming) && !_streamEnded(local)) {
      out['status'] = incoming['status'];
      if (incoming['endedAt'] != null) out['endedAt'] = incoming['endedAt'];
    } else if (_streamLive(incoming) &&
        !_streamLive(local) &&
        !_streamEnded(local)) {
      out['status'] = incoming['status'];
      out.remove('endedAt');
    }
    final auction = _preferStreamAuction(local['auction'], incoming['auction']);
    if (auction == null) {
      out.remove('auction');
    } else {
      out['auction'] = auction;
    }
    final incomingViewers = _streamViewerCount(incoming);
    out['viewerCount'] = incomingViewers;
    final peak = [
      _streamPeakViewers(local),
      _streamPeakViewers(incoming),
      incomingViewers,
    ].reduce((a, b) => a > b ? a : b);
    out['peakViewers'] = peak;
    if (incoming['pinnedProductId'] != null) {
      out['pinnedProductId'] = incoming['pinnedProductId'];
    }
    if (incoming['replayAvailable'] == true) {
      out['replayAvailable'] = true;
    }
    return out;
  }

  static Map<String, int> _minProductQuantities(
    Map<String, dynamic> local,
    Map<String, dynamic> incoming,
  ) {
    final left = _productQuantityMap(local);
    final right = _productQuantityMap(incoming);
    final out = <String, int>{};
    for (final key in {...left.keys, ...right.keys}) {
      if (left.containsKey(key) && right.containsKey(key)) {
        final a = left[key]!;
        final b = right[key]!;
        out[key] = a < b ? a : b;
      } else if (left.containsKey(key)) {
        out[key] = left[key]!;
      } else {
        out[key] = right[key]!;
      }
    }
    return out;
  }

  static Map<String, int> _productQuantityMap(Map<String, dynamic> row) {
    final raw = row['productQuantities'];
    if (raw is! Map) return {};
    final out = <String, int>{};
    for (final entry in raw.entries) {
      final n = entry.value is num
          ? (entry.value as num).toInt()
          : int.tryParse('${entry.value}');
      if (n != null && n >= 0) out['${entry.key}'] = n;
    }
    return out;
  }

  static List<String> _unionStringIds(dynamic a, dynamic b) {
    final seen = <String>{};
    final out = <String>[];
    for (final raw in [a, b]) {
      if (raw is! List) continue;
      for (final item in raw) {
        final id = '$item'.trim();
        if (id.isEmpty || !seen.add(id)) continue;
        out.add(id);
      }
    }
    return out;
  }

  static bool _streamEnded(Map<String, dynamic> row) {
    return '${row['endedAt'] ?? ''}'.trim().isNotEmpty;
  }

  static bool _streamLive(Map<String, dynamic> row) {
    return '${row['status'] ?? ''}' == 'live' && !_streamEnded(row);
  }

  static int _streamViewerCount(Map<String, dynamic> row) {
    final value = row['viewerCount'];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static int _streamPeakViewers(Map<String, dynamic> row) {
    final value = row['peakViewers'];
    if (value is num) return value.toInt();
    return int.tryParse('$value') ?? 0;
  }

  static Map<String, dynamic>? _preferStreamAuction(dynamic a, dynamic b) {
    if (a is! Map) {
      return b is Map ? Map<String, dynamic>.from(b) : null;
    }
    if (b is! Map) return Map<String, dynamic>.from(a);
    final left = Map<String, dynamic>.from(a);
    final right = Map<String, dynamic>.from(b);
    final leftOrder = '${left['orderId'] ?? ''}'.trim();
    final rightOrder = '${right['orderId'] ?? ''}'.trim();
    if (rightOrder.isNotEmpty && leftOrder.isEmpty) return right;
    if (leftOrder.isNotEmpty && rightOrder.isEmpty) return left;
    final leftStatus = '${left['status'] ?? ''}';
    final rightStatus = '${right['status'] ?? ''}';
    if (rightStatus == 'sold' && leftStatus != 'sold') return right;
    if (leftStatus == 'sold' && rightStatus != 'sold') return left;
    if (rightStatus == 'open' && leftStatus == 'reserve_not_met') return right;
    if (leftStatus == 'open' && rightStatus == 'reserve_not_met') return left;
    final leftBid = _streamAuctionBid(left);
    final rightBid = _streamAuctionBid(right);
    if (rightBid > leftBid + 0.001) return right;
    if (leftBid > rightBid + 0.001) return left;
    return left;
  }

  static double _streamAuctionBid(Map<String, dynamic> row) {
    final value = row['currentBidGhs'];
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }

  static List<Map<String, dynamic>> _localDocList(String localKey) {
    final raw = LocalStore.getString(localKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return [
        for (final e in decoded)
          if (e is Map) Map<String, dynamic>.from(e),
      ];
    } catch (_) {
      return const [];
    }
  }

  /// REST PATCH query so omitted account fields (passkeys, suspended) stay.
  @visibleForTesting
  static Map<String, dynamic> accountPatchQuery({
    required String apiKey,
    required Map<String, dynamic> fields,
  }) {
    return {
      'key': apiKey,
      'updateMask.fieldPaths': fields.keys.toList(),
    };
  }

  static Map<String, dynamic> encodeFields(Map<String, dynamic> data) {
    return {
      for (final e in data.entries)
        if (e.value != null) e.key: encodeValue(e.value),
    };
  }

  static Map<String, dynamic> encodeValue(Object? value) {
    if (value == null) return {'nullValue': null};
    if (value is bool) return {'booleanValue': value};
    if (value is int) return {'integerValue': '$value'};
    if (value is double) return {'doubleValue': value};
    if (value is String) return {'stringValue': value};
    if (value is Map) {
      return {
        'mapValue': {
          'fields': encodeFields(Map<String, dynamic>.from(value)),
        },
      };
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': [for (final item in value) encodeValue(item)],
        },
      };
    }
    return {'stringValue': '$value'};
  }

  static Map<String, dynamic> decodeDocument(dynamic raw) {
    if (raw is! Map) return {};
    final fields = raw['fields'];
    if (fields is! Map) return {};
    return decodeFields(Map<String, dynamic>.from(fields));
  }

  static Map<String, dynamic> decodeFields(Map<String, dynamic> fields) {
    return {
      for (final e in fields.entries) e.key: decodeValue(e.value),
    };
  }

  static dynamic decodeValue(dynamic value) {
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    if (map.containsKey('stringValue')) return map['stringValue'];
    if (map.containsKey('booleanValue')) return map['booleanValue'];
    if (map.containsKey('doubleValue')) {
      return (map['doubleValue'] as num).toDouble();
    }
    if (map.containsKey('integerValue')) {
      return int.tryParse('${map['integerValue']}') ?? map['integerValue'];
    }
    if (map.containsKey('nullValue')) return null;
    if (map['mapValue'] is Map) {
      final inner = Map<String, dynamic>.from(map['mapValue'] as Map);
      final fields = inner['fields'];
      if (fields is Map) {
        return decodeFields(Map<String, dynamic>.from(fields));
      }
      return <String, dynamic>{};
    }
    if (map['arrayValue'] is Map) {
      final inner = Map<String, dynamic>.from(map['arrayValue'] as Map);
      final values = inner['values'];
      if (values is List) return values.map(decodeValue).toList();
      return const [];
    }
    return map;
  }
}
