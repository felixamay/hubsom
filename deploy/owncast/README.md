# Hubsom Owncast VPS

Live video is ingested over RTMP and played as HLS. Shop / product clips are stored under `/media` on the same host. Firebase stays the source of truth for accounts, products, chat, and auctions.

## What to buy

A VPS with a public IPv4, 2+ vCPU, 4 GB RAM, and 80+ GB disk is enough to start (Ubuntu 22.04/24.04). Open:

- 80 / 443 — HTTPS (Caddy)
- 1935 — Owncast RTMP (single-stream fallback)
- 1936 — Hubsom nginx-rtmp (one stream key per live show)

Point a DNS A record at the VPS (`live.yourdomain.com`).

## Install

```bash
sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2 git
sudo usermod -aG docker "$USER"
# re-login, then:
cd deploy/owncast
cp .env.example .env
# edit DOMAIN, PUBLIC_BASE_URL, HUBSOM_MEDIA_TOKEN, OWNCAST_STREAM_KEY
docker compose up -d
```

Caddy issues Let's Encrypt certificates for `DOMAIN`.

## Wire Hubsom

Until this host exists, the Flutter app treats Owncast as disconnected (local camera preview + “VPS not connected”). After install, either:

1. Paste `PUBLIC_BASE_URL` in Hubsom **Settings → Owncast public URL**, or
2. Rebuild / redeploy Flutter with:

```bash
flutter build web --release --base-href / \
  --dart-define=HUBSOM_OWNCAST_URL=https://live.yourdomain.com \
  --dart-define=HUBSOM_OWNCAST_MEDIA_TOKEN=change-me
```

## Host publish / viewer play

- **Host (OBS / Larix / Streamlabs):** `rtmp://<host>:1936/hubsom` — stream key is the Hubsom live id (`live-xxxxxxxx`).
- **Viewers:** `https://<host>/hls/<live-id>/index.m3u8`
- **Shop clips:** `POST https://<host>/media/upload` with `X-Hubsom-Video-Id` and optional `X-Hubsom-Media-Token`. Files are served at `/media/<id>.mp4`.
- **Owncast admin:** `https://<host>/admin` (set the admin password on first visit). Stock Owncast ingest `rtmp://<host>:1935/live` is a single-stream fallback.

CORS is enabled so Firebase Hosting (`hubsom-web`) can play HLS and upload clips.
