'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const { URL } = require('url');

const PORT = Number(process.env.PORT || 8080);
const DATA_DIR = process.env.MEDIA_DIR || '/data/media';
const TOKEN = (process.env.MEDIA_TOKEN || '').trim();
const PUBLIC_BASE = (process.env.PUBLIC_BASE_URL || '').replace(/\/$/, '');

fs.mkdirSync(DATA_DIR, { recursive: true });

function send(res, status, body, headers) {
  const extra = headers || {};
  const payload = typeof body === 'string' ? body : JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': extra['Content-Type'] || 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, OPTIONS, HEAD',
    'Access-Control-Allow-Headers': '*',
    ...extra,
  });
  res.end(payload);
}

function safeId(raw) {
  return String(raw || '')
    .replace(/[^a-zA-Z0-9._-]/g, '')
    .slice(0, 80);
}

function publicUrl(id) {
  const file = `${id}.mp4`;
  if (PUBLIC_BASE) return `${PUBLIC_BASE}/media/${file}`;
  return `/media/${file}`;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url || '/', `http://${req.headers.host || 'localhost'}`);

  if (req.method === 'OPTIONS') {
    send(res, 204, '');
    return;
  }

  if (req.method === 'GET' && url.pathname === '/health') {
    send(res, 200, { ok: true });
    return;
  }

  if (req.method === 'POST' && url.pathname === '/media/upload') {
    if (TOKEN) {
      const got = `${req.headers['x-hubsom-media-token'] || ''}`;
      if (got !== TOKEN) {
        send(res, 401, { error: 'unauthorized' });
        return;
      }
    }
    const id = safeId(req.headers['x-hubsom-video-id']);
    if (!id) {
      send(res, 400, { error: 'missing X-Hubsom-Video-Id' });
      return;
    }
    const dest = path.join(DATA_DIR, `${id}.mp4`);
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('error', () => send(res, 400, { error: 'upload failed' }));
    req.on('end', () => {
      try {
        fs.writeFileSync(dest, Buffer.concat(chunks));
        send(res, 201, { url: publicUrl(id), id });
      } catch (e) {
        send(res, 500, { error: String(e) });
      }
    });
    return;
  }

  const mediaMatch = url.pathname.match(/^\/media\/([a-zA-Z0-9._-]+)\.mp4$/);
  if (req.method === 'GET' && mediaMatch) {
    const file = path.join(DATA_DIR, `${mediaMatch[1]}.mp4`);
    if (!fs.existsSync(file)) {
      send(res, 404, { error: 'not found' });
      return;
    }
    const stat = fs.statSync(file);
    res.writeHead(200, {
      'Content-Type': 'video/mp4',
      'Content-Length': stat.size,
      'Access-Control-Allow-Origin': '*',
      'Cache-Control': 'public, max-age=31536000',
    });
    fs.createReadStream(file).pipe(res);
    return;
  }

  send(res, 404, { error: 'not found' });
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`hubsom media-api listening on ${PORT}`);
});
