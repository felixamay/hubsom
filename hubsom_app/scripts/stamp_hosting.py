#!/usr/bin/env python3
"""Rewrite a Flutter web build so each deploy uses unique JS filenames.

Safari (especially iOS home-screen / standalone) treats
`main.dart.js?v=stamp` as the same cached URL as `main.dart.js`. A filename
Safari has never seen cannot be served from that HTTP cache or an old
service-worker cache.
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

SW_KILL_SWITCH = """\
// Hubsom: uninstall every service worker and drop Cache Storage.
// Old Flutter PWA workers pin index.html / main.dart.js forever on Safari.
self.addEventListener('install', (event) => {
  self.skipWaiting();
});
self.addEventListener('activate', (event) => {
  event.waitUntil((async () => {
    const names = await caches.keys();
    await Promise.all(names.map((name) => caches.delete(name)));
    await self.registration.unregister();
    const clientsList = await self.clients.matchAll({
      type: 'window',
      includeUncontrolled: true,
    });
    await Promise.all(clientsList.map((client) => {
      try {
        const url = new URL(client.url);
        if (url.searchParams.get('hubsom_sw') === '1') {
          return Promise.resolve();
        }
        url.searchParams.set('hubsom_sw', '1');
        return client.navigate(url.toString());
      } catch (_) {
        return Promise.resolve();
      }
    }));
  })());
});
"""


def safe_stamp(stamp: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9._-]", "", stamp.strip())
    if not cleaned:
        raise ValueError("empty stamp")
    return cleaned


def stamp_html(text: str, stamp: str) -> str:
    bootstrap = f"flutter_bootstrap.{stamp}.js"
    text = re.sub(
        r'(src=")flutter_bootstrap\.js(?:\?[^"]*)?(")',
        rf"\1{bootstrap}\2",
        text,
    )
    text = re.sub(
        r'(content=")flutter_bootstrap\.js(?:\?[^"]*)?(")',
        rf"\1{bootstrap}\2",
        text,
    )
    text = re.sub(
        r'src="(/?)afia_gate\.js(?:\?[^"]*)?"',
        rf'src="\1afia_gate.{stamp}.js"',
        text,
    )
    marker = f"<!-- hubsom-deploy {stamp} -->"
    if "<!-- hubsom-deploy" in text:
        text = re.sub(r"<!-- hubsom-deploy [^>]*-->", marker, text)
    else:
        text = text.replace("<!DOCTYPE html>", f"<!DOCTYPE html>\n{marker}", 1)
    return text


def stamp_bootstrap(text: str, stamp: str) -> str:
    main_js = f"main.dart.{stamp}.js"
    text = re.sub(
        r'"mainDartJs":"main\.dart\.js(?:\?[^"]*)?"',
        f'"mainDartJs":"{main_js}"',
        text,
    )
    text = re.sub(
        r'"mainJsPath":"main\.dart\.js(?:\?[^"]*)?"',
        f'"mainJsPath":"{main_js}"',
        text,
    )
    text = re.sub(r"`main\.dart\.js(?:\?[^`]*)?`", f"`{main_js}`", text)
    text = re.sub(r"'main\.dart\.js(?:\?[^']*)?'", f"'{main_js}'", text)
    text = re.sub(r'"main\.dart\.js(?:\?[^"]*)?"', f'"{main_js}"', text)
    # Drop any Flutter loader service-worker config. pwa-strategy=none already
    # omits it; keep this so a future build cannot re-register an old worker.
    text = re.sub(
        r"_flutter\.loader\.load\(\{[\s\S]*?\}\);",
        "_flutter.loader.load();",
        text,
        count=1,
    )
    return text


def apply_stamp(web_dir: Path, stamp: str) -> dict[str, str]:
    stamp = safe_stamp(stamp)
    bootstrap_src = web_dir / "flutter_bootstrap.js"
    main_src = web_dir / "main.dart.js"
    gate_src = web_dir / "afia_gate.js"
    if not bootstrap_src.is_file():
        raise FileNotFoundError(bootstrap_src)
    if not main_src.is_file():
        raise FileNotFoundError(main_src)

    bootstrap_dst = web_dir / f"flutter_bootstrap.{stamp}.js"
    main_dst = web_dir / f"main.dart.{stamp}.js"
    bootstrap_dst.write_text(
        stamp_bootstrap(bootstrap_src.read_text(encoding="utf-8"), stamp),
        encoding="utf-8",
    )
    main_dst.write_bytes(main_src.read_bytes())

    gate_name = ""
    if gate_src.is_file():
        gate_name = f"afia_gate.{stamp}.js"
        (web_dir / gate_name).write_bytes(gate_src.read_bytes())

    for html_name in ("index.html", "Afia.html"):
        html_path = web_dir / html_name
        if html_path.is_file():
            original = html_path.read_text(encoding="utf-8")
            updated = stamp_html(original, stamp)
            if updated != original:
                html_path.write_text(updated, encoding="utf-8")

    flutter_js = web_dir / "flutter.js"
    if flutter_js.is_file():
        flutter_js.write_text(
            stamp_bootstrap(flutter_js.read_text(encoding="utf-8"), stamp),
            encoding="utf-8",
        )

    (web_dir / "flutter_service_worker.js").write_text(
        SW_KILL_SWITCH,
        encoding="utf-8",
    )
    return {
        "stamp": stamp,
        "bootstrap": bootstrap_dst.name,
        "main": main_dst.name,
        "gate": gate_name,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--web-dir", required=True)
    parser.add_argument("--stamp", required=True)
    args = parser.parse_args()
    result = apply_stamp(Path(args.web_dir), args.stamp)
    print(
        "stamped {stamp} -> {bootstrap} {main} {gate}".format(**result).strip()
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
