import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hubsom_app/core/services/mp4_faststart.dart';
import 'package:hubsom_app/core/services/shop_video_limits.dart';
import 'package:hubsom_app/core/services/video_for_slow_network.dart';

Uint8List _box(String type, List<int> payload) {
  final body = Uint8List.fromList(payload);
  final size = 8 + body.length;
  final out = Uint8List(size);
  out[0] = (size >> 24) & 0xff;
  out[1] = (size >> 16) & 0xff;
  out[2] = (size >> 8) & 0xff;
  out[3] = size & 0xff;
  out.setAll(4, type.codeUnits);
  out.setAll(8, body);
  return out;
}

List<int> _u32(int value) => [
      (value >> 24) & 0xff,
      (value >> 16) & 0xff,
      (value >> 8) & 0xff,
      value & 0xff,
    ];

int _readU32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

String _typeAt(Uint8List bytes, int offset) {
  return String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
}

void main() {
  test('moves moov in front of mdat and patches stco offsets', () {
    final ftyp = _box('ftyp', [...'isom'.codeUnits, ..._u32(0), ...'isom'.codeUnits]);
    final mdat = _box('mdat', [1, 2, 3, 4, 5, 6, 7, 8]);
    final mdatPayloadOffset = ftyp.length + 8;
    final stco = _box('stco', [..._u32(0), ..._u32(1), ..._u32(mdatPayloadOffset)]);
    final stbl = _box('stbl', stco);
    final minf = _box('minf', stbl);
    final mdia = _box('mdia', minf);
    final trak = _box('trak', mdia);
    final moov = _box('moov', trak);

    final original = Uint8List.fromList([...ftyp, ...mdat, ...moov]);
    expect(_typeAt(original, ftyp.length), 'mdat');

    final fast = ensureMp4FastStart(original);
    expect(_typeAt(fast, 0), 'ftyp');
    expect(_typeAt(fast, ftyp.length), 'moov');
    expect(_typeAt(fast, ftyp.length + moov.length), 'mdat');

    // stco lives at a fixed offset inside moov.
    final stcoOffsetInMoov = moov.length - stco.length;
    final stcoInFile = ftyp.length + stcoOffsetInMoov;
    expect(_typeAt(fast, stcoInFile), 'stco');
    final patched = _readU32(fast, stcoInFile + 16);
    expect(patched, mdatPayloadOffset + moov.length);
  });

  test('leaves an already-fast MP4 unchanged', () {
    final ftyp = _box('ftyp', [...'isom'.codeUnits, ..._u32(0)]);
    final moov = _box('moov', const []);
    final mdat = _box('mdat', [9, 9, 9, 9]);
    final original = Uint8List.fromList([...ftyp, ...moov, ...mdat]);
    final fast = ensureMp4FastStart(original);
    expect(fast, original);
  });

  test('leaves non-MP4 bytes unchanged so WebM uploads still work', () {
    final webm = Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, 1, 2, 3, 4]);
    expect(ensureMp4FastStart(webm), webm);
  });

  test('prepareShopVideoForSlowNetwork keeps tiny clips as-is', () async {
    final bytes = Uint8List.fromList(List<int>.generate(64, (i) => i));
    final prepared = await prepareShopVideoForSlowNetwork(
      bytes: bytes,
      mimeType: 'video/mp4',
    );
    expect(prepared.bytes, bytes);
    expect(prepared.mimeType, 'video/mp4');
  });

  test('shop clips allow two minutes and reject WebM so iPhone can play', () {
    expect(ShopVideoLimits.maxSeconds, 120);
    expect(ShopVideoLimits.maxBytes, 40 * 1024 * 1024);
    final webm = Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, 1, 2, 3, 4]);
    expect(
      isWidelyPlayableShopVideo(bytes: webm, mimeType: 'video/webm'),
      isFalse,
    );
    final ftyp = _box('ftyp', [...'isom'.codeUnits, ..._u32(0), ...'isom'.codeUnits]);
    expect(
      isWidelyPlayableShopVideo(bytes: ftyp, mimeType: 'video/mp4'),
      isTrue,
    );
  });

  test('prepareShopVideoForSlowNetwork rejects WebM instead of publishing it',
      () async {
    final webm = Uint8List.fromList([0x1a, 0x45, 0xdf, 0xa3, 1, 2, 3, 4]);
    expect(
      () => prepareShopVideoForSlowNetwork(bytes: webm, mimeType: 'video/webm'),
      throwsStateError,
    );
  });

  test('prepareShopVideoForSlowNetwork finishes immediately on a large clip',
      () async {
    final bytes = Uint8List(500 * 1024);
    final sw = Stopwatch()..start();
    final prepared = await prepareShopVideoForSlowNetwork(
      bytes: bytes,
      mimeType: 'video/mp4',
    );
    sw.stop();
    expect(prepared.bytes.length, bytes.length);
    expect(sw.elapsedMilliseconds, lessThan(500));
  });
}
