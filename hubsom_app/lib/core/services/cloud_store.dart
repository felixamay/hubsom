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

  /// Tests set this to false so they do not write to production Firestore.
  static bool useNetwork = true;

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
    if (!useNetwork) return null;
    final id = accountDocId(email);
    if (id.isEmpty || !id.contains('@')) return null;

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
      final res = await _rest.patch<dynamic>(
        '$_root/$accounts/${Uri.encodeComponent(id)}',
        queryParameters: {'key': _apiKey},
        data: {'fields': encodeFields(payload)},
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
        await LocalStore.setString(entry.key, jsonEncode(rows));
      } catch (e) {
        if (kDebugMode) {
          debugPrint('CloudStore.hydrateLocalCache ${entry.value}: $e');
        }
      }
    }));
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
