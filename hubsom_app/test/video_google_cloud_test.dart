import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/config/app_config.dart';
import 'package:hubsom_app/core/services/cloud_media.dart';
import 'package:hubsom_app/core/services/cloud_storage_status.dart';
import 'package:hubsom_app/core/services/cloud_store.dart';
import 'package:hubsom_app/core/services/cloud_video_media.dart';
import 'package:hubsom_app/core/services/firebase_bootstrap.dart';
import 'package:hubsom_app/core/services/shop_video_upload_progress.dart';
import 'package:hubsom_app/models/shop_video.dart';

ShopVideo _clip({String? videoUrl}) => ShopVideo(
      id: 'vid-gc',
      authorId: 'u1',
      authorName: 'Ama Seller',
      caption: 'Cloud clip',
      productIds: const ['p1'],
      videoUrl: videoUrl,
      createdAt: '2026-09-13T00:00:00Z',
    );

void main() {
  setUp(() {
    AppConfig.load();
    CloudStore.useNetwork = false;
    ShopVideoUploadProgress.reset();
  });

  tearDown(() {
    FirebaseBootstrap.ready = false;
    CloudStorageStatus.debugOverride = null;
    ShopVideoUploadProgress.reset();
  });

  group('storage availability', () {
    test('the configured bucket is the Google Cloud one, not a placeholder', () {
      expect(CloudStorageStatus.bucket, 'hubsom-web.firebasestorage.app');
    });

    test('storage is unusable until Firebase itself is up', () async {
      FirebaseBootstrap.ready = false;
      CloudStorageStatus.debugOverride = true;
      expect(CloudMedia.storageKnownAvailable, isFalse);
      expect(await CloudMedia.available(), isFalse);
    });

    test('a live bucket makes storage the preferred path', () async {
      FirebaseBootstrap.ready = true;
      CloudStorageStatus.debugOverride = true;
      expect(CloudMedia.storageKnownAvailable, isTrue);
      expect(await CloudMedia.available(), isTrue);
    });

    test('a missing bucket short-circuits instead of hanging an upload',
        () async {
      FirebaseBootstrap.ready = true;
      CloudStorageStatus.debugOverride = false;
      final started = DateTime.now();
      final url = await CloudMedia.uploadShopVideo(
        videoId: 'vid-gc',
        bytes: Uint8List.fromList(List.filled(2048, 7)),
        mimeType: 'video/mp4',
      );
      expect(url, isNull);
      // No Storage retry budget is spent when there is nothing to upload to.
      expect(DateTime.now().difference(started).inSeconds, lessThan(5));
    });

    test('migration is skipped while there is no bucket', () async {
      FirebaseBootstrap.ready = true;
      CloudStorageStatus.debugOverride = false;
      final url = await CloudVideoMedia.migrateToStorage(
        videoId: 'vid-gc',
        bytes: Uint8List.fromList(List.filled(1024, 3)),
        mimeType: 'video/mp4',
      );
      expect(url, isNull);
    });
  });

  group('storage object paths', () {
    test('clip and still share the shopVideos prefix the rules allow', () {
      expect(CloudMedia.videoPath('vid-gc'), 'shopVideos/vid-gc');
      expect(CloudMedia.thumbPath('vid-gc'), 'shopVideos/vid-gc_thumb.jpg');
    });
  });

  group('firestore fallback refs', () {
    test('a chunked clip is recognised as needing migration', () {
      expect(
        CloudVideoMedia.isFirestoreRef(_clip(videoUrl: 'hubsom-fs://vid-gc').videoUrl),
        isTrue,
      );
      expect(
        CloudVideoMedia.isFirestoreRef(
          _clip(videoUrl: 'https://firebasestorage.googleapis.com/x').videoUrl,
        ),
        isFalse,
      );
    });

    test('a chunked clip counts as published but not streamable', () {
      final clip = _clip(videoUrl: 'hubsom-fs://vid-gc');
      expect(clip.hasPublishedMedia, isTrue);
      expect(clip.hasRemoteVideo, isFalse);
    });
  });

  group('upload progress', () {
    test('progress is published so a backgrounded upload is visible', () {
      ShopVideoUploadProgress.start('vid-gc');
      expect(ShopVideoUploadProgress.isUploading, isTrue);
      expect(ShopVideoUploadProgress.of('vid-gc'), 0);

      ShopVideoUploadProgress.report('vid-gc', 0.5);
      expect(ShopVideoUploadProgress.of('vid-gc'), 0.5);

      ShopVideoUploadProgress.finish('vid-gc');
      expect(ShopVideoUploadProgress.of('vid-gc'), isNull);
      expect(ShopVideoUploadProgress.isUploading, isFalse);
    });

    test('tiny deltas do not spam listeners', () {
      var notifications = 0;
      void listener() => notifications++;
      ShopVideoUploadProgress.active.addListener(listener);
      addTearDown(
        () => ShopVideoUploadProgress.active.removeListener(listener),
      );

      ShopVideoUploadProgress.report('vid-gc', 0.20);
      ShopVideoUploadProgress.report('vid-gc', 0.201);
      ShopVideoUploadProgress.report('vid-gc', 0.202);
      expect(notifications, 1);

      ShopVideoUploadProgress.report('vid-gc', 0.40);
      expect(notifications, 2);
    });

    test('completion always lands even after throttled updates', () {
      ShopVideoUploadProgress.report('vid-gc', 0.999);
      ShopVideoUploadProgress.report('vid-gc', 1);
      expect(ShopVideoUploadProgress.of('vid-gc'), 1);
    });
  });
}
