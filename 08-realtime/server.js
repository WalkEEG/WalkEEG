#!/usr/bin/env node
/**
 * WalkEEG local realtime relay server.
 *   WS /ingest  device/app -> server (binary frames)
 *   WS /live    server -> browser
 *   GET /health
 *   GET /       dashboard
 *
 * Frame: magic 'W' | version u8 | seq u16 | t_ms u32 | n u8 | ch[8][n] u16
 * No disk persistence; 10 s ring buffer.
 */
const http = require('http');
const fs = require('fs');
const path = require('path');
const { WebSocketServer } = require('ws');

const PORT = Number(process.env.PORT || 8787);
const MAX_SAMPLES = 5000; // 10 s @ 500 Hz
const MAGIC = 0x57;
const VERSION = 1;
const HDR = 13; // magic+ver+seq+t_ms(u64)+n

const ring = []; // { t, ch: Uint16Array(8) }
const live = new Set();
let totalSamples = 0;
let totalFrames = 0;
let lastSeq = null;
let drops = 0;
let startedAt = Date.now();

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://localhost');
  if (u.pathname === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      ok: true,
      uptimeSec: Math.round((Date.now() - startedAt) / 1000),
      samples: totalSamples,
      frames: totalFrames,
      lastSeq,
      drops,
      clients: live.size,
      sourceRateHz: 500,
      ringSamples: ring.length,
    }));
    return;
  }
  if (u.pathname === '/' || u.pathname === '/index.html') {
    const file = path.join(__dirname, 'index.html');
    fs.readFile(file, (err, data) => {
      if (err) { res.writeHead(500); res.end('index.html missing'); return; }
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(data);
    });
    return;
  }
  res.writeHead(404); res.end('not found');
});

function parseIngest(buf) {
  if (!Buffer.isBuffer(buf) || buf.length < HDR) return null;
  if (buf[0] !== MAGIC || buf[1] !== VERSION) return null;
  const seq = buf.readUInt16LE(2);
  const t = Number(buf.readBigUInt64LE(4));
  const n = buf[12];
  if (n < 1 || n > 200) return null;
  if (buf.length < HDR + n * 16) return null;
  const samples = new Array(n);
  let off = HDR;
  for (let i = 0; i < n; i++) {
    const ch = new Uint16Array(8);
    for (let c = 0; c < 8; c++) { ch[c] = buf.readUInt16LE(off); off += 2; }
    samples[i] = { t, ch };
  }
  return { seq, t, n, samples };
}

function pushSamples(samples) {
  for (const s of samples) {
    ring.push(s);
    totalSamples++;
  }
  while (ring.length > MAX_SAMPLES) ring.shift();
}

function buildFrame(seq, t, samples) {
  const n = samples.length;
  const out = Buffer.allocUnsafe(HDR + n * 16);
  out[0] = MAGIC; out[1] = VERSION;
  out.writeUInt16LE(seq & 0xffff, 2);
  out.writeBigUInt64LE(BigInt(t), 4);
  out[12] = n;
  let off = HDR;
  for (const s of samples) {
    for (let c = 0; c < 8; c++) { out.writeUInt16LE(s.ch[c] & 0xffff, off); off += 2; }
  }
  return out;
}

function sendSnapshot(ws) {
  // last 2 s = 1000 samples, in 50-sample chunks
  const take = Math.min(1000, ring.length);
  const start = ring.length - take;
  for (let i = start; i < ring.length; i += 50) {
    const chunk = ring.slice(i, Math.min(i + 50, ring.length));
    if (!chunk.length) break;
    ws.send(buildFrame(0, chunk[0].t, chunk));
  }
}

const wss = new WebSocketServer({ noServer: true });

server.on('upgrade', (req, socket, head) => {
  const u = new URL(req.url, 'http://localhost');
  if (u.pathname !== '/ingest' && u.pathname !== '/live') {
    socket.destroy();
    return;
  }
  wss.handleUpgrade(req, socket, head, (ws) => {
    ws._path = u.pathname;
    wss.emit('connection', ws, req);
  });
});

wss.on('connection', (ws) => {
  const isLive = ws._path === '/live';
  if (isLive) {
    live.add(ws);
    sendSnapshot(ws);
    ws.on('close', () => live.delete(ws));
    ws.on('error', () => live.delete(ws));
    return;
  }

  ws.on('message', (data) => {
    const parsed = parseIngest(Buffer.from(data));
    if (!parsed) return;
    totalFrames++;
    if (lastSeq !== null) {
      const expected = (lastSeq + 1) & 0xffff;
      const gap = (parsed.seq - expected) & 0xffff;
      if (gap > 0 && gap < 1000) drops += gap;
    }
    lastSeq = parsed.seq;
    pushSamples(parsed.samples);
    for (const client of live) {
      if (client.readyState === 1) client.send(buildFrame(parsed.seq, parsed.t, parsed.samples));
    }
  });
  ws.on('error', () => {});
});

setInterval(() => {
  // drop dead live sockets
  for (const c of live) if (c.readyState !== 1) live.delete(c);
}, 5000).unref();

server.listen(PORT, '0.0.0.0', () => {
  console.log(`WalkEEG relay on http://0.0.0.0:${PORT}  (ws /ingest, /live)`);
});
