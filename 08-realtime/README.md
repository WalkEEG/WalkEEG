# WalkEEG realtime relay (500 Hz)

Local-only link: AD8232 → nRF52840 → BLE → iPad/iPhone → WebSocket → this server → browser.
No disk persistence; 10 s ring buffer; web shows the same data as the iPad.

## Run

```bash
cd 08-realtime
npm install ws
node server.js            # http://0.0.0.0:8787
node simulate.js          # synthetic 500 Hz source
open http://localhost:8787
```

For the iPad, open `http://<mac-lan-ip>:8787` and point the app relay to
`ws://<mac-lan-ip>:8787/ingest`.

## Protocol

`magic 'W'(0x57) | version 1 | seq u16 LE | t_ms u64 LE | n u8 | ch[8][n] u16 LE` (13-byte header)

- 500 Hz, 8 channels; n=50 per batch (100 ms), ~10 frames/s.
- `t_ms` is added by the app when it receives the BLE frame.
- Server keeps 5000 samples (10 s); a new `/live` client gets the last 2 s.

## Endpoints

- `WS /ingest` — app/device pushes frames
- `WS /live` — browser subscribes
- `GET /health` — JSON stats
- `GET /` — dashboard

## Test

```bash
curl -s http://localhost:8787/health
```
