import 'dart:convert';

/// Decode Dio responses that may be JSON maps/lists or plain strings
/// (Firebase Hosting often returns index.html for missing `/api/*` routes).
class ApiResponse {
  ApiResponse._();

  static bool isHtml(dynamic data) {
    if (data is! String) return false;
    final t = data.trimLeft().toLowerCase();
    return t.startsWith('<!doctype') || t.startsWith('<html');
  }

  static dynamic decode(dynamic data) {
    if (data == null) return null;
    if (data is String) {
      if (isHtml(data)) return null;
      final trimmed = data.trim();
      if (trimmed.isEmpty) return null;
      try {
        return jsonDecode(trimmed);
      } catch (_) {
        return null;
      }
    }
    return data;
  }

  static Map<String, dynamic>? asMap(dynamic data) {
    final decoded = decode(data);
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
    return null;
  }

  static List<dynamic> asList(dynamic data, {String? key}) {
    final decoded = decode(data);
    if (decoded is List) return decoded;
    if (decoded is Map && key != null && decoded[key] is List) {
      return decoded[key] as List<dynamic>;
    }
    return const [];
  }
}
