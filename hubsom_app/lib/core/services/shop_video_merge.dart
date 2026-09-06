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
      final keep = '${prev[key] ?? ''}'.trim();
      final remote = '${next[key] ?? ''}'.trim();
      if (remote.isEmpty && keep.isNotEmpty) merged[key] = keep;
    }
    byId[id] = merged;
  }
  return byId.values.toList();
}
