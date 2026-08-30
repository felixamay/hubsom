import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'firebase_bootstrap.dart';
import 'local_store.dart';

/// Firestore-backed Hubsom data so accounts and Huber jobs work across browsers.
class CloudStore {
  CloudStore._();

  static const accounts = 'accounts';
  static const hubers = 'hubers';
  static const offers = 'huberOffers';
  static const deliveries = 'huberDeliveries';
  static const orders = 'orders';
  static const shipments = 'shipments';

  static FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.ready) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  static bool get available => _db != null;

  static Future<Map<String, dynamic>?> getAccount(String email) async {
    final db = _db;
    if (db == null) return null;
    try {
      final snap = await db.collection(accounts).doc(email).get();
      return snap.data();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.getAccount: $e');
      return null;
    }
  }

  static Future<void> putAccount(String email, Map<String, dynamic> data) async {
    final db = _db;
    if (db == null) return;
    await db.collection(accounts).doc(email).set({
      ...data,
      'updatedAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  static Future<void> upsertDocs(
    String collection,
    List<Map<String, dynamic>> rows,
  ) async {
    final db = _db;
    if (db == null || rows.isEmpty) return;
    try {
      final batch = db.batch();
      for (final row in rows) {
        final id = '${row['id'] ?? ''}';
        if (id.isEmpty) continue;
        batch.set(db.collection(collection).doc(id), row, SetOptions(merge: true));
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.upsertDocs($collection): $e');
    }
  }

  static Future<List<Map<String, dynamic>>> listDocs(String collection) async {
    final db = _db;
    if (db == null) return const [];
    try {
      final snap = await db.collection(collection).get();
      return snap.docs.map((d) => Map<String, dynamic>.from(d.data())).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('CloudStore.listDocs($collection): $e');
      return const [];
    }
  }

  /// Pull shared Huber / commerce collections into the local cache.
  static Future<void> hydrateLocalCache() async {
    if (!available) return;
    final mapping = <String, String>{
      'huberProfiles': hubers,
      'huberOffers': offers,
      'huberDeliveries': deliveries,
      'localOrders': orders,
      'localShipments': shipments,
    };
    for (final entry in mapping.entries) {
      final rows = await listDocs(entry.value);
      if (rows.isEmpty) continue;
      await LocalStore.setString(entry.key, jsonEncode(rows));
    }
  }
}
