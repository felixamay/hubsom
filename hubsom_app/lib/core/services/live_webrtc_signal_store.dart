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
    this.viewerSeenAt = 0,
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

  /// Last time the viewer itself checked in. Only the viewer writes this, so
  /// the host can tell "viewer still watching" from "host wrote to this doc".
  final int viewerSeenAt;

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
      viewerSeenAt: int.tryParse('${json['viewerSeenAt'] ?? 0}') ?? 0,
    );
  }

  /// Signaling docs are written with merge semantics by both the host and the
  /// viewer, so a null must be sent as `''` rather than omitted — omitting it
  /// would leave a previous negotiation's SDP in place and the far side would
  /// answer a stale offer.
  Map<String, dynamic> toJson() => {
        'id': id,
        'streamId': streamId,
        'viewerId': viewerId,
        'state': state,
        'offerSdp': offerSdp ?? '',
        'offerType': offerType ?? '',
        'answerSdp': answerSdp ?? '',
        'answerType': answerType ?? '',
        'hostIce': hostIce,
        'viewerIce': viewerIce,
        'updatedAt': updatedAt,
        'viewerSeenAt': viewerSeenAt,
      };

  /// Only the fields the viewer owns.
  Map<String, dynamic> toViewerJson() => {
        'id': id,
        'streamId': streamId,
        'viewerId': viewerId,
        'state': state,
        'answerSdp': answerSdp ?? '',
        'answerType': answerType ?? '',
        'updatedAt': updatedAt,
        'viewerSeenAt': DateTime.now().millisecondsSinceEpoch,
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
    int? viewerSeenAt,
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
      viewerSeenAt: viewerSeenAt ?? this.viewerSeenAt,
    );
  }
}

class LiveWebrtcSignalStore {
  LiveWebrtcSignalStore._();

  static const collection = 'liveSignals';

  /// True when Firestore can push signaling changes to us.
  ///
  /// Polling costs a full round trip per negotiation hop, which adds seconds
  /// before a viewer sees anything; listeners deliver the same change over an
  /// already-open channel.
  static bool get canWatch => _db != null;

  /// Push the one negotiation this viewer cares about.
  static Stream<LiveWebrtcSignal?> watchOne(String streamId, String viewerId) {
    final sdk = _db;
    if (sdk == null || streamId.isEmpty) return const Stream.empty();
    final id = LiveWebrtcSignal.docId(streamId, viewerId);
    return sdk
        .collection(collection)
        .doc(id)
        .snapshots()
        .map((snap) {
          final data = snap.data();
          if (data == null) return null;
          final row = Map<String, dynamic>.from(data);
          row.putIfAbsent('id', () => snap.id);
          return LiveWebrtcSignal.fromJson(row);
        })
        .handleError((_) {});
  }

  /// Push every viewer waiting on, or connected to, this stream.
  static Stream<List<LiveWebrtcSignal>> watchForStream(String streamId) {
    final sdk = _db;
    if (sdk == null || streamId.isEmpty) return const Stream.empty();
    return sdk
        .collection(collection)
        .where('streamId', isEqualTo: streamId)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((d) {
                final row = Map<String, dynamic>.from(d.data());
                row.putIfAbsent('id', () => d.id);
                return LiveWebrtcSignal.fromJson(row);
              })
              .where((s) => s.id.isNotEmpty)
              .toList();
        })
        .handleError((_) {});
  }

  static Future<void> upsert(LiveWebrtcSignal signal) async {
    await CloudStore.upsertDocs(collection, [signal.toJson()]);
  }

  /// The doc a viewer writes to say "I am here, offer me the stream".
  ///
  /// Announcing and clearing the previous negotiation in one write matters:
  /// two sequential writes delayed the host's offer by an extra round trip,
  /// which the viewer experiences as a slow-starting stream.
  ///
  /// NOTE: We do NOT include `hostIce` or `offerSdp` here — those are
  /// host-owned fields. The host clears them when it publishes a fresh offer
  /// via [offerDoc]. Writing an empty array here would race with the host's
  /// ICE candidate appends and wipe freshly-gathered candidates.
  static Map<String, dynamic> announceDoc({
    required String streamId,
    required String viewerId,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'id': LiveWebrtcSignal.docId(streamId, viewerId),
      'streamId': streamId,
      'viewerId': viewerId,
      'state': 'waiting',
      'answerSdp': '',
      'answerType': '',
      'viewerIce': <String>[],
      'updatedAt': now,
      'viewerSeenAt': now,
    };
  }

  /// The doc a host writes to advertise a fresh offer.
  static Map<String, dynamic> offerDoc({
    required String streamId,
    required String viewerId,
    required String offerSdp,
    required String offerType,
  }) =>
      {
        'id': LiveWebrtcSignal.docId(streamId, viewerId),
        'streamId': streamId,
        'viewerId': viewerId,
        'state': 'offered',
        'offerSdp': offerSdp,
        'offerType': offerType,
        'answerSdp': '',
        'answerType': '',
        'hostIce': <String>[],
        'viewerIce': <String>[],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };

  static Future<void> announceViewer({
    required String streamId,
    required String viewerId,
  }) async {
    await CloudStore.upsertDocs(collection, [
      announceDoc(streamId: streamId, viewerId: viewerId),
    ]);
  }

  static Future<void> publishOffer({
    required String streamId,
    required String viewerId,
    required String offerSdp,
    required String offerType,
  }) async {
    await CloudStore.upsertDocs(collection, [
      offerDoc(
        streamId: streamId,
        viewerId: viewerId,
        offerSdp: offerSdp,
        offerType: offerType,
      ),
    ]);
  }

  /// Viewer publishes its answer/state without touching host-owned fields.
  static Future<void> upsertViewerSide(LiveWebrtcSignal signal) async {
    await CloudStore.upsertDocs(collection, [signal.toViewerJson()]);
  }

  /// Append ICE candidates to one side's array.
  ///
  /// Host and viewer both write this single doc as candidates are gathered, so
  /// a read-modify-write of the whole document loses whichever side wrote last.
  /// `arrayUnion` merges server-side, so no candidate is dropped.
  static Future<void> appendIce({
    required String streamId,
    required String viewerId,
    List<String> host = const [],
    List<String> viewer = const [],
  }) async {
    if (host.isEmpty && viewer.isEmpty) return;
    final id = LiveWebrtcSignal.docId(streamId, viewerId);
    final sdk = _db;
    if (sdk != null) {
      try {
        await sdk.collection(collection).doc(id).set({
          'id': id,
          'streamId': streamId,
          'viewerId': viewerId,
          if (host.isNotEmpty) 'hostIce': FieldValue.arrayUnion(host),
          if (viewer.isNotEmpty) 'viewerIce': FieldValue.arrayUnion(viewer),
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        }, SetOptions(merge: true));
        return;
      } catch (e) {
        if (kDebugMode) debugPrint('LiveWebrtcSignalStore.appendIce sdk: $e');
      }
    }
    // REST fallback: merge against the newest copy we can read.
    final existing = await get(streamId, viewerId);
    final mergedHost = <String>{...?existing?.hostIce, ...host}.toList();
    final mergedViewer = <String>{...?existing?.viewerIce, ...viewer}.toList();
    await CloudStore.upsertDocs(collection, [
      {
        'id': id,
        'streamId': streamId,
        'viewerId': viewerId,
        if (host.isNotEmpty) 'hostIce': mergedHost,
        if (viewer.isNotEmpty) 'viewerIce': mergedViewer,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      },
    ]);
  }

  /// Viewer check-in. Lets the host tell a watching viewer from an abandoned
  /// tab without disturbing any negotiation field.
  static Future<void> viewerHeartbeat({
    required String streamId,
    required String viewerId,
  }) async {
    final id = LiveWebrtcSignal.docId(streamId, viewerId);
    await CloudStore.upsertDocs(collection, [
      {
        'id': id,
        'streamId': streamId,
        'viewerId': viewerId,
        'viewerSeenAt': DateTime.now().millisecondsSinceEpoch,
      },
    ]);
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
