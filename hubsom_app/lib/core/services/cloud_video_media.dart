import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'cloud_media.dart';
import 'cloud_store.dart';
import 'mp4_faststart.dart';
import 'product_demo_video_store.dart';

/// Cross-device shop-video media via Storage when available, else Firestore chunks.
class CloudVideoMedia {
  CloudVideoMedia._();

  static const metaCollection = 'shopVideoMedia';
  static const chunkCollection = 'shopVideoChunks';

  /// Keep base64 payloads under Firestore's 1 MiB doc limit (600 KiB raw
  /// becomes ~800 KiB base64). Fewer, larger docs publish faster.
  static const _chunkBytes = 600 * 1024;

  /// Chunk uploads in flight at once. More saturates a slow phone link.
  static const _uploadParallelism = 3;

  static const fsScheme = 'hubsom-fs://';

  static final Map<String, Future<bool>> _downloads = {};

  static bool isFirestoreRef(String? url) {
    final u = url?.trim() ?? '';
    return u.startsWith(fsScheme);
  }

  static String fsRefFor(String videoId) => '$fsScheme$videoId';

  /// Upload bytes; returns an https Storage URL or a `hubsom-fs://` ref.
  ///
  /// Google Cloud Storage is tried first because clips served from it stream
  /// with range requests (seeking, Safari). [CloudMedia] returns null straight
  /// away when the project has no bucket, so nothing is wasted before the
  /// Firestore-chunk fallback runs.
  static Future<String?> publish({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
    void Function(double fraction)? onProgress,
  }) async {
    if (videoId.isEmpty || bytes.isEmpty) return null;

    String? storageUrl;
    try {
      storageUrl = await CloudMedia.uploadShopVideo(
        videoId: videoId,
        bytes: bytes,
        mimeType: mimeType,
        onProgress: onProgress,
      );
    } catch (_) {
      storageUrl = null;
    }
    if (storageUrl != null && storageUrl.isNotEmpty) {
      onProgress?.call(1);
      return storageUrl;
    }

    final ok = await _uploadChunks(
      videoId: videoId,
      bytes: bytes,
      mimeType: mimeType,
      onProgress: onProgress,
    );
    if (!ok) return null;
    return fsRefFor(videoId);
  }

  /// Move a clip that lives in Firestore chunks onto Google Cloud Storage.
  ///
  /// Returns the new https URL, or null when Storage is still unavailable.
  /// The chunks are dropped afterwards so the Firestore quota is reclaimed.
  static Future<String?> migrateToStorage({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (videoId.isEmpty || bytes.isEmpty) return null;
    if (!await CloudMedia.available()) return null;
    final url = await CloudMedia.uploadShopVideo(
      videoId: videoId,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (url == null || url.isEmpty) return null;
    await deletePublished(videoId: videoId);
    return url;
  }

  /// True when the meta doc says every chunk is already in Firestore.
  static Future<bool> isPublished(String videoId) async {
    if (videoId.isEmpty) return false;
    try {
      final meta = await CloudStore.getDoc(metaCollection, videoId);
      final expected = (meta?['chunkCount'] as num?)?.toInt() ?? 0;
      return expected > 0 && meta?['complete'] != false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _uploadChunks({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
    void Function(double fraction)? onProgress,
  }) async {
    try {
      final chunkCount = (bytes.length / _chunkBytes).ceil();
      // Meta first (complete:false) so a reader knows the clip is on its way
      // and how many chunks to expect once it flips to complete.
      await CloudStore.upsertDocs(metaCollection, [
        {
          'id': videoId,
          'mimeType': mimeType,
          'chunkCount': chunkCount,
          'size': bytes.length,
          'complete': false,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);

      var done = 0;
      var failed = false;
      Future<void> uploadOne(int i) async {
        final start = i * _chunkBytes;
        final end = (start + _chunkBytes).clamp(0, bytes.length);
        final slice = bytes.sublist(start, end);
        try {
          await CloudStore.upsertDocs(chunkCollection, [
            {
              'id': '${videoId}_$i',
              'videoId': videoId,
              'index': i,
              'data': base64Encode(slice),
            },
          ]);
          done++;
          onProgress?.call(done / chunkCount);
        } catch (e) {
          failed = true;
          if (kDebugMode) debugPrint('chunk $i of $videoId failed: $e');
        }
      }

      for (var i = 0; i < chunkCount; i += _uploadParallelism) {
        final batch = <Future<void>>[];
        for (var j = i; j < i + _uploadParallelism && j < chunkCount; j++) {
          batch.add(uploadOne(j));
        }
        await Future.wait(batch);
        if (failed) return false;
      }

      await CloudStore.upsertDocs(metaCollection, [
        {
          'id': videoId,
          'mimeType': mimeType,
          'chunkCount': chunkCount,
          'size': bytes.length,
          'complete': true,
          'updatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      ]);
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia._uploadChunks failed: $e');
      return false;
    }
  }

  /// Ensure local Hive has bytes for [videoId] (download from cloud if needed).
  ///
  /// HTTPS clips stream from the CDN and skip this download — unless
  /// [allowChunkFallbackForHttp] is true after the stream failed (old files
  /// with `moov` at the end, a dead Storage URL, or a new phone with no Hive).
  /// Concurrent callers for the same clip share one download.
  static Future<bool> ensureLocalBytes({
    required String videoId,
    String? videoUrl,
    String mimeType = 'video/mp4',
    bool allowChunkFallbackForHttp = false,
  }) {
    if (videoId.isEmpty) return Future.value(false);
    final url = videoUrl?.trim() ?? '';
    final isStreamable = url.startsWith('http://') ||
        url.startsWith('https://') ||
        url.startsWith('blob:') ||
        url.startsWith('data:');
    if (isStreamable && !allowChunkFallbackForHttp) return Future.value(false);

    final inFlight = _downloads[videoId];
    if (inFlight != null) return inFlight;
    final task = _ensureLocalBytes(videoId: videoId, mimeType: mimeType)
        .whenComplete(() => _downloads.remove(videoId));
    _downloads[videoId] = task;
    return task;
  }

  static Future<bool> _ensureLocalBytes({
    required String videoId,
    required String mimeType,
  }) async {
    try {
      final existing = await ProductDemoVideoStore.load(videoId);
      if (existing != null) return true;

      final downloaded = await _downloadChunks(videoId);
      if (downloaded == null || downloaded.isEmpty) return false;
      final mime = mimeType.isEmpty ? 'video/mp4' : mimeType;
      var bytes = downloaded;
      if (mime.contains('mp4') || mime.contains('quicktime')) {
        bytes = ensureMp4FastStart(bytes);
      }
      await ProductDemoVideoStore.save(
        productId: videoId,
        bytes: bytes,
        mimeType: mime,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia.ensureLocalBytes failed: $e');
      return false;
    }
  }

  static Future<Uint8List?> _downloadChunks(String videoId) async {
    try {
      final fromMeta = await _downloadByMeta(videoId);
      if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;
      return await _downloadByQuery(videoId);
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia._downloadChunks failed: $e');
      return null;
    }
  }

  static Future<Uint8List?> _downloadByMeta(String videoId) async {
    final meta = await CloudStore.getDoc(metaCollection, videoId);
    final expected = (meta?['chunkCount'] as num?)?.toInt() ?? 0;
    if (expected <= 0) return null;

    final builder = BytesBuilder(copy: false);
    for (var i = 0; i < expected; i++) {
      final row = await CloudStore.getDoc(chunkCollection, '${videoId}_$i');
      final b64 = '${row?['data'] ?? ''}';
      if (b64.isEmpty) return null;
      builder.add(base64Decode(b64));
    }
    final out = builder.takeBytes();
    return out.isEmpty ? null : out;
  }

  /// Older uploads used unpredictable chunk doc ids. Query just this clip.
  static Future<Uint8List?> _downloadByQuery(String videoId) async {
    final rows = await CloudStore.queryDocs(
      chunkCollection,
      field: 'videoId',
      value: videoId,
    );
    return assembleChunkDocs(videoId, rows);
  }

  /// Join base64 chunk docs for [videoId], oldest-index first.
  static Uint8List? assembleChunkDocs(
    String videoId,
    List<Map<String, dynamic>> rows,
  ) {
    if (videoId.isEmpty || rows.isEmpty) return null;
    final mine = rows.where((row) {
      final owner = '${row['videoId'] ?? ''}';
      if (owner == videoId) return true;
      final docId = '${row['id'] ?? ''}';
      return docId.startsWith('${videoId}_');
    }).toList();
    if (mine.isEmpty) return null;
    mine.sort((a, b) {
      final ai = (a['index'] as num?)?.toInt() ?? _indexFromDocId(a);
      final bi = (b['index'] as num?)?.toInt() ?? _indexFromDocId(b);
      return ai.compareTo(bi);
    });
    final builder = BytesBuilder(copy: false);
    for (final row in mine) {
      final b64 = '${row['data'] ?? ''}';
      if (b64.isEmpty) return null;
      try {
        builder.add(base64Decode(b64));
      } catch (_) {
        return null;
      }
    }
    final out = builder.takeBytes();
    return out.isEmpty ? null : out;
  }

  static int _indexFromDocId(Map<String, dynamic> row) {
    final id = '${row['id'] ?? ''}';
    final i = id.lastIndexOf('_');
    if (i < 0 || i == id.length - 1) return 0;
    return int.tryParse(id.substring(i + 1)) ?? 0;
  }

  /// Remove Firestore chunk docs and meta for a deleted shop video.
  static Future<void> deletePublished({required String videoId}) async {
    if (videoId.isEmpty) return;
    try {
      final meta = await CloudStore.getDoc(metaCollection, videoId);
      final expected = (meta?['chunkCount'] as num?)?.toInt() ?? 0;
      for (var i = 0; i < expected; i++) {
        await CloudStore.deleteDoc(chunkCollection, '${videoId}_$i');
      }
      await CloudStore.deleteDoc(metaCollection, videoId);

      final rows = await CloudStore.queryDocs(
        chunkCollection,
        field: 'videoId',
        value: videoId,
      );
      for (final row in rows) {
        final docId = '${row['id'] ?? ''}';
        if (docId.isEmpty) continue;
        await CloudStore.deleteDoc(chunkCollection, docId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia.deletePublished failed: $e');
    }
  }
}
