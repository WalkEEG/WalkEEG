# WalkEMG Dual Front End (AD8232 + ADS1293)

Branch `WalkEMG` · 2026-11-04

## Wiring (nRF52840 DK)
| Front end | Signal | Pin |
|---|---|---|
| AD8232 | OUT → AIN0 | P0.02 (P13 pin 8) |
| AD8232 | LO+ / LO- / SDN | P1.13 / P1.15 / P1.14 |
| ADS1293 | SCLK / MOSI / MISO | P1.00 / P1.01 / P1.02 |
| ADS1293 | CS / DRDY / RESET | P1.03 / P1.04 / P1.05 |
| UART | TX / RX | P0.13 / P0.12 |

The two sets of pins do not overlap, so both can be plugged in at the same time.

## Frame Mapping
| Frame channel | Default (AD8232 mode) | ADS1293 only | **Dual front end** |
|---|---|---|---|
| CH0 | AD8232 raw 12-bit | Lead I | **AD8232 raw 12-bit** |
| CH1 | Sawtooth test signal | Lead II | **ADS1293 ECG1** |
| CH2 | 0 | Lead III | **ADS1293 ECG2** |
| CH3..7 | 0 | 0 | 0 |

flags: bit0/1 = AD8232 LO+/LO-; bit2/3 = ADS1293 IN1/IN2 (1 = connected).

## How to Enable
`prj.conf` (or `boards/*.conf`):
```
CONFIG_WALKEEG_USE_ADS1293=y
CONFIG_WALKEEG_DUAL_FRONTEND=y
```
Disabled by default; when not enabled, behavior is identical to before.

## Sample Rate
- AD8232 / frame rate: `SET_RATE 500|1000|2000|4000`, default 2000.
- The ADS1293 runs at 533 sps by itself (R2=4, R3=12, fMOD=102.4 kHz).
- In dual-front-end mode the sampling thread **does not block waiting for DRDY**: it reads a new value only when DRDY is present, otherwise it holds the previous one →
  CH1/CH2 look like a staircase (updated roughly every 1.9 ms), while CH0 remains a true 2000 Hz stream.
- For a higher ODR: change `REG_R3_RATE_CHx` from `0x08` (R3=12, 533 sps) to `0x01`
  (R3=4, 1600 sps). Note that this also affects ECG-only mode.

## Known Limitations
- The ADS1293's 24-bit output is right-shifted by 8 bits to int16: its amplitude scale is much larger than the AD8232's 0..4095,
  so displaying both waveforms on the same screen in the App requires separate scaling (currently handled by AC Auto auto-scaling).
- 533 sps is sufficient for the EMG envelope (<100 Hz); to view raw EMG at 100–450 Hz you need 1600+
  sps, or simply use the AD8232 channel.
- A 2 ms SPI read by the sampling thread takes only ~25 µs and does not affect AD8232 sampling.
