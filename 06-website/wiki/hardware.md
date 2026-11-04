# Hardware

KiCad 10 schematics for the WalkEEG acquisition board.

---

## Boards

| Design | Front end | Purpose |
|---|---|---|
| `walkeeg_v3.0` | AD8232 (on board) + ADS1293 (header) | Current revision |
| `walkeeg_v1/v2` | AD8232 | Earlier revisions, kept for reference |

KiCad project files live in `01-hardware/walkeeg_v3.0/`. Open `walkeeg_v3.0.kicad_pro` to edit; export a PDF before committing so reviewers can read schematics without KiCad.

---

## Analog front end — AD8232

A single-lead ECG front end with an integrated instrumentation amplifier. Datasheet headline figures:

| Parameter | Value |
|---|---|
| Supply current | 170 µA typical |
| **CMRR** | **80 dB** (DC – 60 Hz) |
| Signal gain | G = 100 |
| Half-cell potential | ±300 mV |
| High-pass filter | 2-pole, adjustable |
| Low-pass filter | 3-pole, adjustable |
| Lead-off detection | Comparator outputs |

The on-board filter is set for ECG bandwidth. Turning the board into an EMG front end means changing the capacitor values — see the walk-through in `docs/walkemg-frontend-A.md`.

---

## Connectors

### AD8232 headers (J3–J10)

Eight identical 6-pin headers, one per channel position:

| Pin | Net | Notes |
|---|---|---|
| **1** | **GND** | — |
| 2 | +3V3 | — |
| 3 | AINx | analog output → SAADC |
| 4 | P0.07 / LO+ | lead-off, positive |
| 5 | P0.25 / LO− | lead-off, negative |
| 6 | P0.25 / LO− | lead-off, shared rail |

Analog input per connector:

| Header | Pin 3 → |
|---|---|
| J3 | P0.02 / AIN0 |
| J4 | P0.03 / AIN1 |
| J5 | P0.04 / AIN2 |
| J6 | P0.05 / AIN3 |
| J7 | P0.28 / AIN4 |
| J8 | P0.29 / AIN5 |
| J9 | P0.30 / AIN6 |
| J10 | P0.31 / AIN7 |

> ⚠️ Pins 5 and 6 are labelled with the same net (`P0.25/LO−`). This looks like a schematic error — verify against the PCB before relying on pin 6 as an independent signal.

**Only pins 1, 2 and 3 are required** to capture a signal. Lead-off detection is optional.

### ADS1293 header (J11)

A 2×5 header routing the SPI front end:

| Function | nRF52840 pin | ADS1293 pin |
|---|---|---|
| SCLK | P1.00 | SCLK |
| MOSI | P1.01 | SDI |
| MISO | P1.02 | SDO |
| CS | P1.03 | CSB |
| DRDY | P1.04 | DRDYB |
| RESET | P1.05 | RSTB |

ADS1293 is deliberately on the **P1** group so it never collides with the AD8232 or UART pins. Full register programming notes: [`docs/ads1293/`](https://github.com/WalkEEG/WalkEEG/tree/master/docs/ads1293).

### Other connectors

| Ref | Type | Purpose |
|---|---|---|
| J1, J2 | 2-pin | Power input |
| J12 | USB Micro-B | UART bridge (P0.12/P0.13) |
| J13 | USB Micro-B | Main USB |
| J15 | 2×5 | Debug / SWD |

---

## Pin map summary

| Signal | Pin | Notes |
|---|---|---|
| AD8232 analog out | P0.02 (AIN0) | SAADC input |
| **UART** | P0.12 / P0.13 | NUS data path — **do not reuse** |
| SPI (ADS1293) | P1.00 – P1.05 | SCK / MOSI / MISO / CS / DRDY / RST |
| Run LED | DK LED2 | Startup blink codes |
| Connection LED | DK LED3 | Lit while a BLE peer is connected |

---

## Design notes

**Analog and digital grounds are separated** and joined at a single point under the AFE. Route the AD8232 output away from the SPI lines — P1.00–P1.05 switching at 4 MHz will couple into a microvolt-level trace.

**The ADS1293 and AD8232 share no pins**, so both can be populated simultaneously and selected by Kconfig at runtime. This is intentional: it lets one board serve both the cheap single-lead case and the 3-lead research case.

**Antenna keep-out.** The BLE antenna needs a copper-free zone on all layers beneath it. Filling that area with ground plane detunes the antenna and costs several dB of range.

---

## Revision history

| Rev | Change |
|---|---|
| v3.0 | Added ADS1293 SPI header, 8-channel AD8232 headers |
| v2.0 | Power architecture redesign |
| v1.0 | First AD8232-only board |

---

## Related

- [Firmware → front end selection](../firmware/README.md#analog-front-end-choose-one)
- AD8232 datasheet: [analog.com](https://www.analog.com/en/products/ad8232.html)
- ADS1293 datasheet: [ti.com](https://www.ti.com/product/ADS1293)
