# Protocol

The wire format between the nRF52840 and the mobile app. Everything runs over the **Nordic UART Service (NUS)**.

---

## NUS characteristics

| Role | UUID | Direction |
|---|---|---|
| Service | `6E400001-B5A3-F393-E0A9-E50E24DCCA9E` | — |
| RX (write, phone → device) | `6E400002-B5A3-F393-E0A9-E50E24DCCA9E` | commands |
| TX (notify, device → phone) | `6E400003-B5A3-F393-E0A9-E50E24DCCA9E` | sample frames |

The device advertises the service UUID and the name `WalkEEG`. Enable notifications on **TX** to start the stream.

---

## Frame layout

```
 byte  field    type      notes
 ────  ───────  ────────  ─────────────────────────────────────────────
  0    magic    uint8     0xA5
  1    version  uint8     0x01
  2-3  seq      uint16    little-endian, wraps at 0xFFFF
  4    n        uint8     samples per frame (1 … 30)
  5    flags    uint8     bit0 = LO+ attached, bit1 = LO− attached
  6..  ch[8][n] uint16    little-endian, interleaved by sample
```

**Byte order:** little-endian, as written by `sys_put_le16()`.

**Payload size:** `6 + n × 8 × 2` bytes.

| n | Frame size | Typical use |
|---|---|---|
| 20 | 326 B | default at MTU 498 |
| 30 | 486 B | maximum |
| 1 | 22 B | minimum |

### Sample interleaving

Samples are **structured by time, then channel** — all 8 channels of sample 0, then all 8 of sample 1, and so on:

```
offset 6   → sample[0].ch[0]   (ch0 of first sample)
offset 8   → sample[0].ch[1]
…
offset 20  → sample[0].ch[7]
offset 22  → sample[1].ch[0]
```

---

## Choosing n

The firmware sizes frames to the negotiated MTU. ATT notification payload = `MTU − 3`, so:

```
n = floor((MTU − 3 − 6) / (8 × 2))
```

capped at **30**. With the long MTU the firmware requests (**498**), you get `n = 30`.

If the phone negotiates a small MTU, `n` shrinks automatically — the parser does not need to assume a fixed value. **Always read `n` from the header.**

---

## Channel assignment

8 channels are always transmitted, regardless of how many the front end provides:

| Channel | AD8232 board | ADS1293 board |
|---|---|---|
| CH0 | SAADC AIN0 (P0.02) | Lead I |
| CH1 | 0 | Lead II |
| CH2 | 0 | Lead III |
| CH3–7 | 0 | 0 |

Unused channels are transmitted as zeros. This keeps the frame layout stable so one app build works with both front ends.

---

## Sample values

`uint16` covers the full 12-bit SAADC range and the ADS1293's 24-bit output truncated to 16 bits.

```c
// 12-bit SAADC is single-ended and offset around mid-scale
voltage_mV = (raw - 2048) / 4096.0 * VREF_MV;
```

The firmware does **no** filtering, baseline correction or scaling — frames carry raw converter counts.

---

## Loss detection

Use `seq` to detect dropped frames:

```dart
final delta = (seq - lastSeq) & 0xFFFF;   // handles wraparound
if (delta != 1) dropped += delta - 1;
lastSeq = seq;
```

Because BLE notifications are reliable at the link layer but the app queue is finite, drops happen when the phone can't drain notifications fast enough. A persistent loss rate above ~1 % usually means the connection interval is too long or the phone is throttling a background app.

---

## Commands (phone → device)

The RX characteristic accepts short ASCII commands.

| Command | Effect |
|---|---|
| `rate 500` | Set 500 Hz |
| `rate 1000` | Set 1000 Hz |
| `rate 2000` | Set 2000 Hz |
| `rate 4000` | Set 4000 Hz |

Invalid rates return `-EINVAL` and leave the current setting untouched.

---

## Bandwidth budget

At 500 Hz × 8 channels × 2 bytes = **8,000 B/s**. Each frame carries `n` samples, so the notification rate is:

```
frames/s = 500 / n
```

With `n = 30` that's **~17 notifications per second**, each 486 bytes — comfortably inside a 7.5 ms connection interval.

At 4000 Hz the same `n` gives **133 notifications/s**, which is where 2M PHY and Data Length Extension stop being optional.
