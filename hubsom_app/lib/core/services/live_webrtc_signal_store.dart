import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'cloud_store.dart';
import 'firebase_bootstrap.dart';

/// Firestore signaling docs so a live host can fan out camera/mic to viewers
/// without Agora (Flutter web RTC is stubbed).
class LiveWebrtcSignal {
  const LiveWebrtcSignal({
    required this.id,
    required this.streamId,
    required this.viewerId,
    required this.state,
    this.offerSdp,
    this.offerType,
    this.answerSdp,
    this.answerType,
    this.hostIce = const [],
    this.viewerIce = const [],
    this.updatedAt = 0,
  });

  final String id;
  final String streamId;
  final String viewerId;

  /// waiting → offered → answered → closed
  final String state;
  final String? offerSdp;
  final String? offerType;
  final String? answerSdp;
  final String? answerType;
  final List<String> hostIce;
  final List<String> viewerIce;
  final int updatedAt;

  static String docId(String streamId, String viewerId) =>
      '${streamId}__$viewerId';

  factory LiveWebrtcSignal.fromJson(Map<String, dynamic> json) {
    List<String> asStrings(dynamic v) {
      if (v is! List) return const [];
      return v.map((e) => '$e').where((s) => s.isNotEmpty).toList();
    }

    return LiveWebrtcSignal(
      id: '${json['id'] ?? ''}',
      streamId: '${json['streamId'] ?? ''}',
      viewerId: '${json['viewerId'] ?? ''}',
      state: '${json['state'] ?? 'waiting'}',
      offerSdp: json['offerSdp']?.toString(),
      offerType: json['offerType']?.toString(),
      answerSdp: json['answerSdp']?.toString(),
      answerType: json['answerType']?.toString(),
      hostIce: asStrings(json['hostIce']),
      viewerIce: asStrings(json['viewerIce']),
      updatedAt: int.tryParse('${json['updatedAt'] ?? 0}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'viewerId': viewerId,
        'state': state,
        'offerSdp': offerSdp,
        'offerType': offerType,
        'answerSdp': answerSdp,
        'answerType': answerType,
        'hostIce': hostIce,
        'viewerIce': viewerIce,
        'updatedAt': updatedAt,
      };

  LiveWebrtcSignal copyWith({
    String? state,
    String? offerSdp,
    String? offerType,
    String? answerSdp,
    String? answerType,
    List<String>? hostIce,
    List<String>? viewerIce,
    int? updatedAt,
  }) {
    return LiveWebrtcSignal(
      id: id,
      streamId: streamId,
      viewerId: viewerId,
      state: state ?? this.state,
      offerSdp: offerSdp ?? this.offerSdp,
      offerType: offerType ?? this.offerType,
      answerSdp: answerSdp ?? this.answerSdp,
      answerType: answerType ?? this.answerType,
      hostIce: hostIce ?? this.hostIce,
      viewerIce: viewerIce ?? this.viewerIce,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LiveWebrtcSignalStore {
  LiveWebrtcSignalStore._();

  static const collection = 'liveSignals';

  static Future<void> upsert(LiveWebrtcSignal signal) async {
    await CloudStore.upsertDocs(collection, [signal.toJson()]);
  }

  static Future<LiveWebrtcSignal?> get(String streamId, String viewerId) async {
    final id = LiveWebrtcSignal.docId(streamId, viewerId);
    final sdk = _db;
    if (sdk != null) {
      try {
        final snap = await sdk.collection(collection).doc(id).get();
        final data = snap.data();
        if (data == null) return null;
        return LiveWebrtcSignal.fromJson(Map<String, dynamic>.from(data));
      } catch (e) {
        if (kDebugMode) debugPrint('LiveWebrtcSignalStore.get sdk: $e');
      }
    }
    final rows = await listForStream(streamId);
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  static Future<List<LiveWebrtcSignal>> listForStream(String streamId) async {
    if (streamId.isEmpty || !CloudStore.useNetwork) return const [];
    final sdk = _db;
    if (sdk != null) {
      try {
        final snap = await sdk
            .collection(collection)
            .where('streamId', isEqualTo: streamId)
            .get();
        return snap.docs
            .map((d) => LiveWebrtcSignal.fromJson(Map<String, dynamic>.from(d.data())))
            .where((s) => s.id.isNotEmpty)
            .toList();
      } catch (e) {
        if (kDebugMode) debugPrint('LiveWebrtcSignalStore.list sdk: $e');
      }
    }
    final rows = await CloudStore.listDocs(collection);
    return rows
        .where((r) => '${r['streamId']}' == streamId)
        .map(LiveWebrtcSignal.fromJson)
        .where((s) => s.id.isNotEmpty)
        .toList();
  }

  static Future<void> close(String streamId, String viewerId) async {
    final existing = await get(streamId, viewerId);
    final now = DateTime.now().millisecondsSinceEpoch;
    final closed = (existing ??
            LiveWebrtcSignal(
              id: LiveWebrtcSignal.docId(streamId, viewerId),
              streamId: streamId,
              viewerId: viewerId,
              state: 'closed',
            ))
        .copyWith(state: 'closed', updatedAt: now);
    await upsert(closed);
  }

  static Future<void> closeAllForStream(String streamId) async {
    final rows = await listForStream(streamId);
    final now = DateTime.now().millisecondsSinceEpoch;
    if (rows.isEmpty) return;
    await CloudStore.upsertDocs(
      collection,
      rows
          .map((s) => s.copyWith(state: 'closed', updatedAt: now).toJson())
          .toList(),
    );
  }

  static FirebaseFirestore? get _db {
    if (!FirebaseBootstrap.ready) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }
}
