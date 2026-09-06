(function () {
  var KEY = 'flutter.hubsom_afiaUnlockedEmail';
  var EMAIL = 'felixames0808@gmail.com';
  var HASH = 'ac668d772d82fb28c85601fb52fef2d4cf127147fced8701ac69fa9c70f78601';
  var APP = '/hubsom-admin';

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

  function openConsole() {
    window.location.replace(APP);
  }

  function bindForm() {
    var form = document.getElementById('afia-form');
    if (!form) return;
    form.addEventListener('submit', function (e) {
      e.preventDefault();
      var email = (document.getElementById('afia-email').value || '').trim().toLowerCase();
      var password = document.getElementById('afia-password').value || '';
      var err = document.getElementById('afia-error');
      if (err) err.textContent = '';
      sha256hex('afia-portal::' + password + '::hubsom').then(function (hash) {
        if (email !== EMAIL || hash !== HASH) {
          if (err) err.textContent = 'Email or password is not valid for this portal.';
          return;
        }
        localStorage.setItem(KEY, JSON.stringify(EMAIL));
        openConsole();
      }).catch(function () {
        if (err) err.textContent = 'Could not open this portal. Try again.';
      });
    });
  }

  window.hubsomAfiaStart = function () {
    if (unlocked()) {
      openConsole();
      return;
    }
    bindForm();
  };
})();
