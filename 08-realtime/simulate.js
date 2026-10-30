#!/usr/bin/env node
/** Synthetic 500 Hz, 8-channel WalkEEG source for the local relay. */
const WebSocket = require('ws');

const url = process.argv[2] || 'ws://localhost:8787/ingest';
const seconds = Number(process.argv[3] || 0); // 0 = forever
const MAGIC = 0x57, VERSION = 1, N = 50; // 50 samples = 100 ms @ 500 Hz
const ws = new WebSocket(url);
let seq = 0;
let sampleIndex = 0;
let sent = 0;

function frame(t, samples) {
  const buf = Buffer.allocUnsafe(13 + samples.length * 16);
  buf[0] = MAGIC; buf[1] = VERSION;
  buf.writeUInt16LE(seq & 0xffff, 2);
  buf.writeBigUInt64LE(BigInt(t), 4);
  buf[12] = samples.length;
  let off = 13;
  for (const s of samples) {
    for (let c = 0; c < 8; c++) { buf.writeUInt16LE(s[c] & 0xffff, off); off += 2; }
  }
  return buf;
}

ws.on('open', () => {
  console.log(`simulate -> ${url}  (500 Hz, N=${N})`);
  const start = Date.now();
  const timer = setInterval(() => {
    const t = Date.now();
    const samples = [];
    for (let i = 0; i < N; i++) {
      const idx = sampleIndex++;
      const ms = idx * 2; // 500 Hz
      const ecg = (idx % 250 === 0) ? 700 : 0; // 2 Hz spike
      const ch0 = Math.round(2048 + 650 * Math.sin(2 * Math.PI * 10 * ms / 1000) + ecg);
      const ch1 = Math.round((idx % 500) * 4095 / 499);
      samples.push([ch0, ch1, 0, 0, 0, 0, 0, 0]);
    }
    ws.send(frame(t, samples));
    seq = (seq + 1) & 0xffff;
    sent += N;
    if (seconds && Date.now() - start >= seconds * 1000) {
      clearInterval(timer);
      ws.close();
    }
  }, 100);
  ws.on('close', () => console.log(`done, samples=${sent}`));
});

ws.on('error', (e) => { console.error('ws error', e.message); process.exit(1); });
