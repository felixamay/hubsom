import 'dart:typed_data';

/// Move an MP4 `moov` atom in front of `mdat` so playback can start after the
/// first few kilobytes instead of waiting for the whole file on a slow link.
Uint8List ensureMp4FastStart(Uint8List bytes) {
  if (bytes.length < 16 || !_looksLikeMp4(bytes)) return bytes;
  final boxes = _parseTopLevel(bytes);
  if (boxes.isEmpty) return bytes;

  var moovIndex = -1;
  var mdatIndex = -1;
  for (var i = 0; i < boxes.length; i++) {
    final type = boxes[i].type;
    if (type == 'moov' && moovIndex < 0) moovIndex = i;
    if (type == 'mdat' && mdatIndex < 0) mdatIndex = i;
  }
  if (moovIndex < 0 || mdatIndex < 0) return bytes;
  if (moovIndex < mdatIndex) return bytes;

  final moov = boxes[moovIndex];
  final shifted = _shiftChunkOffsets(moov.payload, moov.totalSize);
  if (shifted == null) return bytes;

  final out = BytesBuilder(copy: false);
  for (var i = 0; i < boxes.length; i++) {
    if (i == moovIndex) continue;
    if (i == mdatIndex) {
      out.add(_encodeBox(moov.type, shifted, headerSize: moov.headerSize));
    }
    out.add(boxes[i].raw);
    if (i == mdatIndex) {
      // moov already inserted above, before this mdat
    }
  }
  final result = out.takeBytes();
  return result.isEmpty ? bytes : Uint8List.fromList(result);
}

bool _looksLikeMp4(Uint8List bytes) {
  if (bytes.length < 8) return false;
  final type = String.fromCharCodes(bytes.sublist(4, 8));
  return type == 'ftyp' || type == 'wide' || type == 'mdat' || type == 'moov';
}

class _Box {
  const _Box({
    required this.type,
    required this.headerSize,
    required this.payload,
    required this.raw,
  });

  final String type;
  final int headerSize;
  final Uint8List payload;
  final Uint8List raw;

  int get totalSize => raw.length;
}

List<_Box> _parseTopLevel(Uint8List bytes) {
  final boxes = <_Box>[];
  var offset = 0;
  while (offset + 8 <= bytes.length) {
    final parsed = _readBox(bytes, offset);
    if (parsed == null) break;
    boxes.add(parsed);
    offset += parsed.totalSize;
  }
  return boxes;
}

_Box? _readBox(Uint8List bytes, int offset) {
  if (offset + 8 > bytes.length) return null;
  var size = _u32(bytes, offset);
  var header = 8;
  if (size == 1) {
    if (offset + 16 > bytes.length) return null;
    size = _u64(bytes, offset + 8);
    header = 16;
  } else if (size == 0) {
    size = bytes.length - offset;
  }
  if (size < header || offset + size > bytes.length) return null;
  final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
  return _Box(
    type: type,
    headerSize: header,
    payload: bytes.sublist(offset + header, offset + size),
    raw: bytes.sublist(offset, offset + size),
  );
}

Uint8List _encodeBox(String type, Uint8List payload, {required int headerSize}) {
  if (headerSize == 16 || 8 + payload.length > 0xffffffff) {
    final size = 16 + payload.length;
    final out = Uint8List(size);
    _setU32(out, 0, 1);
    out.setAll(4, type.codeUnits);
    _setU64(out, 8, size);
    out.setAll(16, payload);
    return out;
  }
  final size = 8 + payload.length;
  final out = Uint8List(size);
  _setU32(out, 0, size);
  out.setAll(4, type.codeUnits);
  out.setAll(8, payload);
  return out;
}

/// Walk the moov tree and add [delta] to every stco/co64 chunk offset.
Uint8List? _shiftChunkOffsets(Uint8List moov, int delta) {
  final copy = Uint8List.fromList(moov);
  try {
    _walkBoxes(copy, 0, copy.length, (bytes, start, end, type) {
      if (type != 'stco' && type != 'co64') return;
      if (start + 8 > end) return;
      final count = _u32(bytes, start + 4);
      var cursor = start + 8;
      if (type == 'stco') {
        for (var i = 0; i < count; i++) {
          if (cursor + 4 > end) return;
          final next = _u32(bytes, cursor) + delta;
          _setU32(bytes, cursor, next);
          cursor += 4;
        }
      } else {
        for (var i = 0; i < count; i++) {
          if (cursor + 8 > end) return;
          final next = _u64(bytes, cursor) + delta;
          _setU64(bytes, cursor, next);
          cursor += 8;
        }
      }
    });
    return copy;
  } catch (_) {
    return null;
  }
}

void _walkBoxes(
  Uint8List bytes,
  int start,
  int end,
  void Function(Uint8List bytes, int payloadStart, int payloadEnd, String type)
      onBox,
) {
  var offset = start;
  while (offset + 8 <= end) {
    var size = _u32(bytes, offset);
    var header = 8;
    if (size == 1) {
      if (offset + 16 > end) return;
      size = _u64(bytes, offset + 8);
      header = 16;
    } else if (size == 0) {
      size = end - offset;
    }
    if (size < header || offset + size > end) return;
    final type = String.fromCharCodes(bytes.sublist(offset + 4, offset + 8));
    final payloadStart = offset + header;
    final payloadEnd = offset + size;
    onBox(bytes, payloadStart, payloadEnd, type);
    const containers = {
      'moov',
      'trak',
      'mdia',
      'minf',
      'stbl',
      'edts',
      'udta',
    };
    if (containers.contains(type)) {
      _walkBoxes(bytes, payloadStart, payloadEnd, onBox);
    }
    offset = payloadEnd;
  }
}

int _u32(Uint8List bytes, int offset) {
  return (bytes[offset] << 24) |
      (bytes[offset + 1] << 16) |
      (bytes[offset + 2] << 8) |
      bytes[offset + 3];
}

int _u64(Uint8List bytes, int offset) {
  return (_u32(bytes, offset) << 32) | _u32(bytes, offset + 4);
}

void _setU32(Uint8List bytes, int offset, int value) {
  bytes[offset] = (value >> 24) & 0xff;
  bytes[offset + 1] = (value >> 16) & 0xff;
  bytes[offset + 2] = (value >> 8) & 0xff;
  bytes[offset + 3] = value & 0xff;
}

void _setU64(Uint8List bytes, int offset, int value) {
  _setU32(bytes, offset, (value >> 32) & 0xffffffff);
  _setU32(bytes, offset + 4, value & 0xffffffff);
}
