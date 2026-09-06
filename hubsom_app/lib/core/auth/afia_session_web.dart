import 'package:web/web.dart' as web;

/// Clear the Afia unlock and reload `/afia` so the HTML login door shows.
void leaveAfiaSession() {
  web.window.localStorage.removeItem('flutter.hubsom_afiaUnlockedEmail');
  web.window.location.replace('/afia');
}
