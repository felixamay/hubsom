String? _pickMediaUrl(String? previous, String? incoming) {
  final keep = previous?.trim() ?? '';
  final remote = incoming?.trim() ?? '';
  if (keep.isEmpty) return remote.isEmpty ? null : remote;
  if (remote.isEmpty) return keep;
  final keepHttp = keep.startsWith('http://') || keep.startsWith('https://');
  final remoteHttp =
      remote.startsWith('http://') || remote.startsWith('https://');
  if (keepHttp && !remoteHttp) return keep;
  if (remoteHttp && !keepHttp) return remote;
  return remote;
}

bool _isDeviceLocalMedia(String value) {
  return value.startsWith('hubsom-blob://') ||
      (value.startsWith('data:') && value.contains('base64,'));
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
        '${row['id']}': Map<String, dynamic>.from(row),
  };
  for (final row in incoming) {
    final id = '${row['id'] ?? ''}';
    if (id.isEmpty) continue;
    final next = Map<String, dynamic>.from(row);
    final prev = byId[id];
    if (prev == null) {
      byId[id] = next;
      continue;
    }
    final merged = <String, dynamic>{...prev, ...next};
    for (final key in const ['videoUrl', 'thumbnailUrl', 'posterUrl', 'thumbUrl']) {
      final picked = _pickMediaUrl('${prev[key]}', '${next[key]}');
      if (picked != null) merged[key] = picked;
    }
    final localThumb = '${prev['thumbnailUrl'] ?? ''}'.trim();
    final remoteThumb = '${next['thumbnailUrl'] ?? ''}'.trim();
    if (localThumb.isNotEmpty &&
        _isDeviceLocalMedia(localThumb) &&
        remoteThumb.isNotEmpty &&
        _isDeviceLocalMedia(remoteThumb)) {
      merged['thumbnailUrl'] = localThumb;
    }
    byId[id] = merged;
  }
  return byId.values.toList();
}
