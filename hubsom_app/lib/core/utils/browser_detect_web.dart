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

/// Insert [el] into `document.body` as its very first child so it sits
/// underneath the Flutter view in natural DOM stacking order.
///
/// Flutter's `<flutter-view>` is appended to `<body>` after the bootstrap JS
/// runs, so it is already after any child we prepend here. Elements appended
/// later in the DOM stack on top of earlier ones when their z-indices are
/// equal. By making [el] the first child we guarantee it renders beneath
/// Flutter without touching any CSS on the Flutter view itself.
void mountBehindFlutter(web.HTMLElement el) {
  final body = web.document.body;
  if (body == null) return;
  // Remove any stale explicit z-index so the natural DOM order wins.
  el.style.removeProperty('z-index');
  body.insertBefore(el, body.firstChild);
}
