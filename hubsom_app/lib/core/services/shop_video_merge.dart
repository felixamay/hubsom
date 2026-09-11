/// Normalise a media URL field: null, empty, and the literal string "null"
/// (written by an older merge bug) all mean "no value".
String cleanMediaUrl(Object? raw) {
  if (raw == null) return '';
  final v = '$raw'.trim();
  if (v.isEmpty || v == 'null' || v == 'undefined') return '';
  return v;
}

bool _isHttp(String v) => v.startsWith('http://') || v.startsWith('https://');

/// Only this device can read a `hubsom-blob://` ref. Data URLs play anywhere.
bool isDeviceOnlyMedia(String value) => value.startsWith('hubsom-blob://');

/// Choose between the value already on this phone and the cloud value.
///
/// Prefer anything other devices can load (https, data:, hubsom-fs://) over a
/// device-only blob ref, and never let an empty cloud field erase a local one.
String? _pickMediaUrl(Object? previous, Object? incoming) {
  final keep = cleanMediaUrl(previous);
  final remote = cleanMediaUrl(incoming);
  if (keep.isEmpty) return remote.isEmpty ? null : remote;
  if (remote.isEmpty) return keep;
  if (_isHttp(keep) && !_isHttp(remote)) return keep;
  if (_isHttp(remote) && !_isHttp(keep)) return remote;
  if (isDeviceOnlyMedia(remote) && !isDeviceOnlyMedia(keep)) return keep;
  return remote;
}

/// Merge cloud shop-video docs into the on-device list without dropping a
/// thumbnail or playback URL the phone already has.
List<Map<String, dynamic>> mergeShopVideoDocs({
  required List<Map<String, dynamic>> local,
  required List<Map<String, dynamic>> incoming,
}) {
  final byId = <String, Map<String, dynamic>>{
    for (final row in local)
      if ('${row['id'] ?? ''}'.isNotEmpty)
        '${row['id']}': _sanitize(Map<String, dynamic>.from(row)),
  };
  for (final row in incoming) {
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) continue;
    final next = _sanitize(Map<String, dynamic>.from(row));
    final prev = byId[id];
    if (prev == null) {
      byId[id] = next;
      continue;
    }
    final merged = <String, dynamic>{...prev, ...next};
    for (final key in const ['videoUrl', 'thumbnailUrl', 'posterUrl', 'thumbUrl']) {
      final picked = _pickMediaUrl(prev[key], next[key]);
      if (picked == null) {
        merged.remove(key);
      } else {
        merged[key] = picked;
      }
    }
    byId[id] = merged;
  }
  return byId.values.toList();
}

Map<String, dynamic> _sanitize(Map<String, dynamic> row) {
  for (final key in const ['videoUrl', 'thumbnailUrl', 'posterUrl', 'thumbUrl']) {
    if (!row.containsKey(key)) continue;
    final v = cleanMediaUrl(row[key]);
    if (v.isEmpty) {
      row.remove(key);
    } else {
      row[key] = v;
    }
  }
  return row;
}
