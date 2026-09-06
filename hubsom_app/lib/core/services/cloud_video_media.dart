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

  /// Keep base64 payloads comfortably under Firestore's 1 MiB doc limit.
  static const _chunkBytes = 350 * 1024;

  static const fsScheme = 'hubsom-fs://';

  static bool isFirestoreRef(String? url) {
    final u = url?.trim() ?? '';
    return u.startsWith(fsScheme);
  }

  static String fsRefFor(String videoId) => '$fsScheme$videoId';

  /// Upload bytes; returns an https Storage URL or a `hubsom-fs://` ref.
  static Future<String?> publish({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    if (videoId.isEmpty || bytes.isEmpty) return null;

    final storageUrl = await CloudMedia.uploadShopVideo(
      videoId: videoId,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (storageUrl != null && storageUrl.isNotEmpty) return storageUrl;

    final ok = await _uploadChunks(
      videoId: videoId,
      bytes: bytes,
      mimeType: mimeType,
    );
    if (!ok) return null;
    return fsRefFor(videoId);
  }

  static Future<bool> _uploadChunks({
    required String videoId,
    required Uint8List bytes,
    required String mimeType,
  }) async {
    try {
      final chunkCount = (bytes.length / _chunkBytes).ceil();
      // One doc at a time so a large video never blows a single batch.
      for (var i = 0; i < chunkCount; i++) {
        final start = i * _chunkBytes;
        final end = (start + _chunkBytes).clamp(0, bytes.length);
        final slice = bytes.sublist(start, end);
        await CloudStore.upsertDocs(chunkCollection, [
          {
            'id': '${videoId}_$i',
            'videoId': videoId,
            'index': i,
            'data': base64Encode(slice),
          },
        ]);
      }
      await CloudStore.upsertDocs(metaCollection, [
        {
          'id': videoId,
          'mimeType': mimeType,
          'chunkCount': chunkCount,
          'size': bytes.length,
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
  static Future<bool> ensureLocalBytes({
    required String videoId,
    String? videoUrl,
    String mimeType = 'video/mp4',
    bool allowChunkFallbackForHttp = false,
  }) async {
    if (videoId.isEmpty) return false;
    try {
      final url = videoUrl?.trim() ?? '';
      final isStreamable = url.startsWith('http://') ||
          url.startsWith('https://') ||
          url.startsWith('blob:') ||
          url.startsWith('data:');
      if (isStreamable && !allowChunkFallbackForHttp) return false;

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
      return await _downloadByListing(videoId);
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

  /// Older uploads used unpredictable chunk doc ids. List and filter.
  static Future<Uint8List?> _downloadByListing(String videoId) async {
    final rows = await CloudStore.listDocs(chunkCollection);
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

      final rows = await CloudStore.listDocs(chunkCollection);
      for (final row in rows) {
        final owner = '${row['videoId'] ?? ''}';
        final docId = '${row['id'] ?? ''}';
        if (owner != videoId && !docId.startsWith('${videoId}_')) continue;
        if (docId.isEmpty) continue;
        await CloudStore.deleteDoc(chunkCollection, docId);
      }
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia.deletePublished failed: $e');
    }
  }
}
