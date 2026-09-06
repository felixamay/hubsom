(function () {
  var KEY = 'flutter.hubsom_afiaUnlockedEmail';
  var EMAIL = 'felixames0808@gmail.com';
  var HASH = 'ac668d772d82fb28c85601fb52fef2d4cf127147fced8701ac69fa9c70f78601';

  function unlocked() {
    try {
      return JSON.parse(localStorage.getItem(KEY) || 'null') === EMAIL;
    } catch (e) {
      return false;
    }
  }

  async function sha256hex(text) {
    var buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
    return Array.from(new Uint8Array(buf))
      .map(function (b) { return b.toString(16).padStart(2, '0'); })
      .join('');
  }

  function removeGate() {
    var gate = document.getElementById('afia-gate');
    if (gate) gate.remove();
    var boot = document.getElementById('hubsom-boot');
    if (boot) boot.remove();
  }

  function loadFlutter() {
    if (document.querySelector('script[data-hubsom-flutter]')) return;
    var opening = document.getElementById('afia-opening');
    var form = document.getElementById('afia-form');
    if (form) form.hidden = true;
    if (opening) opening.hidden = false;
    var boot = document.getElementById('hubsom-flutter-boot');
    var s = document.createElement('script');
    s.src = (boot && boot.textContent ? boot.textContent.trim() : 'flutter_bootstrap.js');
    s.async = true;
    s.setAttribute('data-hubsom-flutter', '1');
    document.body.appendChild(s);
    window.addEventListener('flutter-first-frame', removeGate);
  }

  function bindForm() {
    var form = document.getElementById('afia-form');
    if (!form) return;
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var emailEl = document.getElementById('afia-email');
      var passEl = document.getElementById('afia-password');
      var err = document.getElementById('afia-error');
      var email = (emailEl && emailEl.value ? emailEl.value : '').trim().toLowerCase();
      var password = passEl && passEl.value ? passEl.value : '';
      if (err) err.textContent = '';
      sha256hex('afia-portal::' + password + '::hubsom').then(function (hash) {
        if (email !== EMAIL || hash !== HASH) {
          if (err) err.textContent = 'Email or password is not valid for this portal.';
          return;
        }
        localStorage.setItem(KEY, JSON.stringify(EMAIL));
        loadFlutter();
      }).catch(function () {
        if (err) err.textContent = 'Could not open this portal. Try again.';
      });
    });
  }

  window.hubsomAfiaStart = function () {
    if (unlocked()) {
      loadFlutter();
      return;
    }
    var form = document.getElementById('afia-form');
    var opening = document.getElementById('afia-opening');
    if (form) form.hidden = false;
    if (opening) opening.hidden = true;
    bindForm();
  };
})();
