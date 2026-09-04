import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'cloud_media.dart';
import 'cloud_store.dart';
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
  static Future<bool> ensureLocalBytes({
    required String videoId,
    String? videoUrl,
    String mimeType = 'video/mp4',
  }) async {
    if (videoId.isEmpty) return false;
    try {
      final existing = await ProductDemoVideoStore.load(videoId);
      if (existing != null) return true;

      final url = videoUrl?.trim() ?? '';
      if (url.startsWith('http://') ||
          url.startsWith('https://') ||
          url.startsWith('blob:') ||
          url.startsWith('data:')) {
        return false;
      }

      final downloaded = await _downloadChunks(videoId);
      if (downloaded == null || downloaded.isEmpty) return false;
      await ProductDemoVideoStore.save(
        productId: videoId,
        bytes: downloaded,
        mimeType: mimeType.isEmpty ? 'video/mp4' : mimeType,
      );
      return true;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia.ensureLocalBytes failed: $e');
      return false;
    }
  }

  static Future<Uint8List?> _downloadChunks(String videoId) async {
    try {
      final metas = await CloudStore.listDocs(metaCollection);
      Map<String, dynamic>? meta;
      for (final row in metas) {
        if ('${row['id']}' == videoId) {
          meta = row;
          break;
        }
      }

      final chunks = await CloudStore.listDocs(chunkCollection);
      final mine = chunks
          .where((c) => '${c['videoId']}' == videoId)
          .toList()
        ..sort(
          (a, b) => ((a['index'] as num?)?.toInt() ?? 0)
              .compareTo((b['index'] as num?)?.toInt() ?? 0),
        );
      if (mine.isEmpty) return null;

      final expected = (meta?['chunkCount'] as num?)?.toInt() ?? mine.length;
      final builder = BytesBuilder(copy: false);
      for (var i = 0; i < expected; i++) {
        Map<String, dynamic>? row;
        for (final c in mine) {
          if ((c['index'] as num?)?.toInt() == i) {
            row = c;
            break;
          }
        }
        final b64 = '${row?['data'] ?? ''}';
        if (b64.isEmpty) return null;
        builder.add(base64Decode(b64));
      }
      final out = builder.takeBytes();
      return out.isEmpty ? null : out;
    } catch (e) {
      if (kDebugMode) debugPrint('CloudVideoMedia._downloadChunks failed: $e');
      return null;
    }
  }
}
