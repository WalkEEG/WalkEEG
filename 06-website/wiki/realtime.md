# Realtime Dashboard

A local WebSocket relay that mirrors the phone's signal in a browser — same data, same instant, no install.

```
AD8232 → nRF52840 → BLE → phone app → WebSocket → this server → browser
```

No cloud, no disk. Frames live in a 10-second ring buffer; a browser opening mid-session is backfilled with the last 2 seconds.

---

## Run

```bash
cd 08-realtime
npm install
node server.js            # http://0.0.0.0:8787
```

Then, optionally, feed it synthetic data:

```bash
node simulate.js          # 500 Hz, 8 channels
```

Open **`http://localhost:8787`**.

### Using a phone

1. On the computer, note the LAN address (`ipconfig getifaddr en0` on macOS)
2. In the app, open the relay dialog and enter that IP with port `8787`
3. In any browser on the same network: `http://<that-ip>:8787`

Everything stays on the local network — the relay never leaves the LAN.

---

## Endpoints

| Method | Path | Purpose |
|---|---|---|
| `GET` | `/` | Dashboard page |
| `GET` | `/health` | JSON stats |
| `WS` | `/ingest` | App/device pushes frames here |
| `WS` | `/live` | Browser subscribes here |

### /health

```json
{
  "ok": true,
  "uptimeSec": 42,
  "samples": 21000,
  "frames": 700,
  "lastSeq": 699,
  "drops": 0,
  "clients": 1,
  "sourceRateHz": 500,
  "ringSamples": 5000
}
```

Fastest way to tell whether the pipeline is alive:

```bash
curl -s http://localhost:8787/health
```

- `frames` climbing → data is arriving
- `frames` flat but `clients > 0` → server is up, phone isn't sending
- `drops` rising → the relay can't keep up

---

## Frame format

The app forwards the BLE frame body with a timestamp the phone adds:

```
magic 'W' (0x57) | version (1) | seq (u16 LE) | t_ms (u64 LE) | n (u8) | ch[8][n] (u16 LE)
```

13-byte header. This is **not** the same as the BLE frame — see [Protocol](../protocol.md) for the on-air format. The relay adds `t_ms`, which the device doesn't know.

At 500 Hz with `n = 50`, batches arrive roughly **10 times per second**.

---

## Configuration

| Setting | Default | Where |
|---|---|---|
| Port | 8787 | `server.js` |
| Ring buffer | 5000 samples (10 s) | `server.js` |
| Backfill on connect | last 2 s | `server.js` |
| Source rate (display only) | 500 Hz | `server.js` |

There is no persistence and no authentication — this is a bring-up and demo tool. **Do not expose it to the internet.**

---

## Files

```
08-realtime/
├── server.js         HTTP + WebSocket relay, ring buffer
├── index.html        dashboard (vanilla JS, canvas chart)
├── simulate.js       synthetic 500 Hz source
└── package.json      single dependency: ws
```

---

## Troubleshooting

**Browser shows nothing.**
Check `/health`. If `frames` isn't climbing, the phone isn't connected to the relay. If `clients` is 0, the browser's WebSocket didn't attach — check the console for a `/live` connection error.

**Wrong network.**
The phone and the computer must be on the same subnet. If the computer moves to a different Wi-Fi, its IP changes and the app's relay setting goes stale.

**Synthetic and real data mixed together.**
`node simulate.js` keeps running in the background. Kill it before connecting a real device, or the waveforms will be a superposition of both.
