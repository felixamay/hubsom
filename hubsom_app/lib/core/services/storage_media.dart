/// Keep browser storage small — never persist camera/data-URL blobs on streams.
abstract final class StorageMedia {
  static bool isInlineData(String? value) {
    final v = value?.trim() ?? '';
    return v.startsWith('data:') && v.contains('base64,');
  }

  /// HTTP(S) and short refs stay. Inline photos are already on the product.
  static String persistable(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return '';
    if (isInlineData(v)) return '';
    if (v.length > 2048) return '';
    return v;
  }
}
