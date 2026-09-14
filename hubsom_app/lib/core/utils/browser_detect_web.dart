import 'package:web/web.dart' as web;

/// Returns true when the current browser is Safari (not Chrome/Chromium).
///
/// Chrome on iOS contains both "CriOS" and "Safari" in its UA but does NOT
/// contain "Chrome", so it correctly returns true here (it uses WebKit and
/// shares Safari's shadow-DOM limitation for video elements).
bool isSafariBrowser() {
  final ua = web.window.navigator.userAgent;
  return ua.contains('Safari') &&
      !ua.contains('Chrome') &&
      !ua.contains('Chromium');
}
