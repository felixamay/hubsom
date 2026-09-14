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

/// Mounts [el] in `document.body` *underneath* the Flutter view.
///
/// Flutter's UI (chat, buttons, tap-to-play overlay) must stay on top and
/// interactive; the element shows through wherever the Flutter canvas is
/// transparent. `<flutter-view>` has no stacking order of its own, so a
/// positioned element appended after it would otherwise cover the whole app.
void mountBehindFlutter(web.HTMLElement el) {
  final body = web.document.body;
  if (body == null) return;
  el.style.setProperty('z-index', '0');
  body.insertBefore(el, body.firstChild);

  final view = (web.document.querySelector('flutter-view') ??
      web.document.querySelector('flt-glass-pane')) as web.HTMLElement?;
  if (view == null) return;
  final position = web.window.getComputedStyle(view).position;
  if (position.isEmpty || position == 'static') {
    view.style.setProperty('position', 'relative');
  }
  view.style.setProperty('z-index', '1');
  view.style.setProperty('background', 'transparent');
}
