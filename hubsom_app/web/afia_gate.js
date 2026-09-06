(function () {
  var KEY = 'flutter.hubsom_afiaUnlockedEmail';
  var EMAIL = 'felixames0808@gmail.com';
  var HASH = 'ac668d772d82fb28c85601fb52fef2d4cf127147fced8701ac69fa9c70f78601';
  var CATEGORIES = [
    ['fashion', 'Fashion'],
    ['phones-accessories', 'Phones & Accessories'],
    ['electronics', 'Electronics'],
    ['groceries', 'Groceries'],
    ['beauty-personal-care', 'Beauty'],
    ['home-kitchen', 'Home & Kitchen'],
    ['shoes', 'Shoes'],
    ['health-wellness', 'Health'],
  ];

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

  function prefsGet(key) {
    var raw = localStorage.getItem('flutter.hubsom_' + key);
    if (raw == null) return null;
    try {
      return JSON.parse(raw);
    } catch (e) {
      return raw;
    }
  }

  function prefsSet(key, value) {
    localStorage.setItem('flutter.hubsom_' + key, JSON.stringify(value));
  }

  function readList(key) {
    var inner = prefsGet(key);
    if (!inner) return [];
    if (typeof inner === 'string') {
      try {
        inner = JSON.parse(inner);
      } catch (e) {
        return [];
      }
    }
    return Array.isArray(inner) ? inner : [];
  }

  function writeList(key, rows) {
    prefsSet(key, JSON.stringify(rows));
  }

  function uid(prefix) {
    return prefix + Math.random().toString(16).slice(2, 12);
  }

  function esc(value) {
    return String(value == null ? '' : value)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/"/g, '&quot;');
  }

  function showAdmin() {
    var gate = document.getElementById('afia-gate');
    var admin = document.getElementById('afia-admin');
    if (gate) gate.style.display = 'none';
    if (admin) {
      admin.classList.add('is-open');
      admin.style.display = 'block';
    }
    document.title = 'Hubsom Admin';
    renderAll();
  }

  function showLogin() {
    var gate = document.getElementById('afia-gate');
    var admin = document.getElementById('afia-admin');
    if (admin) {
      admin.classList.remove('is-open');
      admin.style.display = 'none';
    }
    if (gate) gate.style.display = 'flex';
    document.title = 'Hubsom Admin';
  }

  function renderOverview() {
    var products = readList('localProducts');
    var sellers = readList('localSellers');
    var streams = readList('localStreams');
    var orders = readList('localOrders');
    var offers = readList('purchaseOffers');
    var promos = readList('promotions');
    var liveNow = streams.filter(function (s) { return s && s.status === 'live'; }).length;
    document.getElementById('panel-overview').innerHTML =
      '<div class="stats">' +
      stat(sellers.length, 'Stores') +
      stat(products.length, 'Products') +
      stat(liveNow, 'Live now') +
      stat(orders.length, 'Orders') +
      stat(offers.length, 'Offers') +
      stat(promos.length, 'Promos') +
      '</div>' +
      '<h2>Live shows</h2>' +
      (streams.length ? streams.slice(0, 12).map(function (s) {
        return '<div class="row"><div><strong>' + esc(s.title || s.id) +
          '</strong><br><small>' + esc(s.status || '') + ' · ' + esc(s.id || '') +
          '</small></div></div>';
      }).join('') : '<p>No live shows</p>');
  }

  function stat(value, label) {
    return '<div class="stat"><b>' + esc(value) + '</b>' + esc(label) + '</div>';
  }

  function checked(name, value, on) {
    return '<label class="place"><input type="checkbox" name="' + name +
      '" value="' + esc(value) + '"' + (on ? ' checked' : '') + '> ' + esc(value) + '</label>';
  }

  function renderPromotions() {
    var items = readList('promotions');
    document.getElementById('panel-promotions').innerHTML =
      '<h2>Hubsom promotions</h2>' +
      '<p>Choose where each promo appears on Hubsom. Empty category or product lists mean all pages.</p>' +
      '<form id="promo-form">' +
      '<label>Title</label><input name="title" type="text" required>' +
      '<label>Subtitle</label><input name="subtitle" type="text">' +
      '<label>Link</label><input name="href" type="text" value="/marketplace">' +
      '<label>Button label</label><input name="ctaLabel" type="text" value="Shop now">' +
      '<p>Placements</p>' +
      checked('place', 'landing', true) +
      checked('place', 'marketplace', false) +
      checked('place', 'category', false) +
      checked('place', 'product', false) +
      '<p>Categories (optional)</p>' +
      CATEGORIES.map(function (c) {
        return '<label class="place"><input type="checkbox" name="cat" value="' +
          c[0] + '"> ' + esc(c[1]) + '</label>';
      }).join('') +
      '<p id="promo-status" class="ok"></p>' +
      '<button type="submit">Save promotion to Hubsom</button>' +
      '</form>' +
      '<h2>Live on Hubsom</h2>' +
      (items.length ? items.map(function (p) {
        return '<div class="row"><div><strong>' + esc(p.title) + '</strong><br><small>' +
          esc((p.placements || [p.placement]).join(', ')) +
          '</small></div><button type="button" data-del-promo="' + esc(p.id) +
          '" class="secondary">Delete</button></div>';
      }).join('') : '<p>No promotions yet</p>');

    var form = document.getElementById('promo-form');
    form.onsubmit = function (e) {
      e.preventDefault();
      var places = Array.prototype.map.call(form.querySelectorAll('[name=place]:checked'), function (el) { return el.value; });
      if (!places.length) places = ['landing'];
      var cats = Array.prototype.map.call(form.querySelectorAll('[name=cat]:checked'), function (el) { return el.value; });
      items.unshift({
        id: uid('promo_'),
        title: form.elements.title.value.trim(),
        subtitle: form.elements.subtitle.value.trim(),
        href: form.elements.href.value.trim() || '/marketplace',
        ctaLabel: form.elements.ctaLabel.value.trim() || 'Shop now',
        placement: places[0],
        placements: places,
        categorySlugs: cats,
        productIds: [],
        active: true,
        priority: 100,
        sortOrder: 100,
      });
      writeList('promotions', items);
      document.getElementById('promo-status').textContent = 'Saved to Hubsom';
      renderPromotions();
    };
    Array.prototype.forEach.call(document.querySelectorAll('[data-del-promo]'), function (btn) {
      btn.onclick = function () {
        writeList('promotions', items.filter(function (p) { return p.id !== btn.getAttribute('data-del-promo'); }));
        renderPromotions();
      };
    });
  }

  function renderOffers() {
    var items = readList('purchaseOffers');
    document.getElementById('panel-offers').innerHTML =
      '<h2>Purchase offers</h2>' +
      '<p>Send an offer to buyers from what they already bought.</p>' +
      '<form id="offer-form">' +
      '<label>Offer title</label><input name="title" type="text" required>' +
      '<label>Message</label><input name="subtitle" type="text">' +
      '<label>Link</label><input name="href" type="text" value="/marketplace">' +
      '<label>Button label</label><input name="ctaLabel" type="text" value="Shop now">' +
      '<label>% off</label><input name="discountPct" type="number" value="0">' +
      '<p id="offer-status" class="ok"></p>' +
      '<button type="submit">Send offer</button>' +
      '</form>' +
      '<h2>Sent offers</h2>' +
      (items.length ? items.map(function (o) {
        return '<div class="row"><div><strong>' + esc(o.title) + '</strong><br><small>' +
          esc(o.href || '') + '</small></div></div>';
      }).join('') : '<p>No offers sent yet</p>');
    var form = document.getElementById('offer-form');
    form.onsubmit = function (e) {
      e.preventDefault();
      items.unshift({
        id: uid('offer_'),
        title: form.elements.title.value.trim(),
        subtitle: form.elements.subtitle.value.trim(),
        href: form.elements.href.value.trim() || '/marketplace',
        ctaLabel: form.elements.ctaLabel.value.trim() || 'Shop now',
        discountPct: parseInt(form.elements.discountPct.value, 10) || 0,
        productIds: [],
        categorySlugs: [],
        active: true,
        kind: 'purchase-offer',
        placements: ['offers'],
        createdAt: new Date().toISOString(),
      });
      writeList('purchaseOffers', items);
      document.getElementById('offer-status').textContent = 'Offer sent';
      renderOffers();
    };
  }

  function renderOrders() {
    var orders = readList('localOrders');
    document.getElementById('panel-orders').innerHTML =
      '<h2>Orders</h2>' +
      (orders.length ? orders.map(function (o) {
        var name = (o.lines || []).map(function (l) { return l.name; }).join(', ') || o.id;
        return '<div class="row"><div><strong>' + esc(name) + '</strong><br><small>' +
          esc(o.id) + ' · ' + esc(o.status || '') + '</small></div></div>';
      }).join('') : '<p>No orders yet</p>');
  }

  function renderAll() {
    renderOverview();
    renderPromotions();
    renderOffers();
    renderOrders();
  }

  function bindTabs() {
    Array.prototype.forEach.call(document.querySelectorAll('.tabs button'), function (btn) {
      btn.onclick = function () {
        Array.prototype.forEach.call(document.querySelectorAll('.tabs button'), function (b) { b.classList.remove('on'); });
        Array.prototype.forEach.call(document.querySelectorAll('.panel'), function (p) { p.classList.remove('on'); });
        btn.classList.add('on');
        var panel = document.getElementById('panel-' + btn.getAttribute('data-tab'));
        if (panel) panel.classList.add('on');
      };
    });
    var lock = document.getElementById('afia-lock');
    if (lock) {
      lock.onclick = function () {
        localStorage.removeItem(KEY);
        showLogin();
      };
    }
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
        showAdmin();
      }).catch(function () {
        if (err) err.textContent = 'Could not open this portal. Try again.';
      });
    });
  }

  window.hubsomAfiaStart = function () {
    bindTabs();
    bindForm();
    if (unlocked()) {
      showAdmin();
      return;
    }
    showLogin();
  };
})();
