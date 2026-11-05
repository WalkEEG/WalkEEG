# WalkEEG × TI ADS1293 Interface Notes

This directory documents the interface design for adding a **TI ADS1293** 3-channel 24-bit ECG analog front end (AFE) to the WalkEEG firmware (02-firmware).
The ADS1293 is kept **in parallel** with the existing AD8232 design: the AD8232 pins (AIN0=P0.02, LO+=P1.13, LO-=P1.15, SDN=P1.14)
and the UART (P0.12/P0.13) stay **untouched**, while the ADS1293 uses entirely new pins and the data source is switched with a single Kconfig option.

## 1. Why Add the ADS1293

| Comparison | AD8232 (existing) | ADS1293 (new) |
|---|---|---|
| Channels | 1 (single lead) | 3 (Lead I/II/III simultaneously) |
| Resolution | 12-bit SAADC | 24-bit ΔΣ |
| Sample rate | 500 Hz | 533 Hz (configurable 25–6400 sps) |
| Lead-off detection | External LO+/LO- comparator | Built-in LOD + AC/DC detection |
| Right leg drive | None | Built-in RLD amplifier (to IN4) |
| Interface | Analog (SAADC) | SPI (mode 0, up to 20 MHz) |

## 2. Hardware Wiring (nRF52840-DK / Qingfeng board P12 header)

> On the Qingfeng board, P10/P11 are core-board sockets (internal); **only P12/P13 accept Dupont wires**; the ADS1293 pins P1.00–P1.05 are on **P12**.

The ADS1293 uses **SPI1** entirely, with pins in the P1 group, so there is zero conflict with the AD8232/UART:

| Function | nRF52840 pin | ADS1293 pin | Notes |
|---|---|---|---|
| SCLK | P1.00 | SCLK | SPIM1 SCK |
| MOSI | P1.01 | SDI | SPIM1 MOSI |
| MISO | P1.02 | SDO | SPIM1 MISO |
| CS | P1.03 | CSB | GPIO chip select (active low) |
| DRDY | P1.04 | DRDYB | Data-ready interrupt (active low, falling edge) |
| RESET | P1.05 | RSTB | Optional hard reset (active low) |
| — | 3.3V | VDD / VDDIO | VDD 2.7–5.5V, VDDIO 1.65–3.6V |
| — | GND | VSS | Common ground |
| — | — | CVREF | 1 µF low-ESR capacitor to ground |
| — | — | RLDREF | 0.1 µF capacitor to ground |
| Electrode RA | — | IN1 | Right arm |
| Electrode LA | — | IN2 | Left arm |
| Electrode LL | — | IN3 | Left leg |
| Electrode RL | — | IN4 | Right leg (RLD output) |

> ⚠️ RESET is an optional pin. **The CJMCU-1293 module does not expose RST**, so the overlay must not declare `reset-gpios`; the driver performs a soft reset via `CONFIG=0`, and P1.05 can be left floating.

**Electrode-to-lead mapping** (per TI's official 3-Lead reference design):
- Lead I = LA − RA = IN2 − IN1 (CH1)
- Lead II = LL − RA = IN3 − IN1 (CH2)
- Lead III = LL − LA = IN3 − IN2 (CH3)

> Clock: the module requires a 4.096 MHz crystal (XTAL1/XTAL2), or a 409.6 kHz clock fed externally into the CLK pin.
> Common ADS1293 production modules (e.g., the TI official EVM, domestic modules) already integrate the crystal and can be used directly.

### 2.1 CJMCU-1293 Production Module (actually used in this project)

Schematic: `docs/ads1293/CJMCU-1293.PDF`. The module = ADS1293 + MIC5219-3.3 LDO + 2 × 3.5 mm electrode jacks + 9-pin digital header; 5V input, VDDIO 3.3V, SDO idle level 3.3V, so it connects directly to the nRF52840.

**9-pin digital header P3 (silkscreen 1→9)**

| Pin | Signal | Connects to nRF52840 | Notes |
|---|---|---|---|
| 1 | +5V | 5V | Module supply (not 3.3V) |
| 2 | GND | GND | Common ground |
| 3 | SCLK | P1.00 | SPI clock |
| 4 | SDI | P1.01 | MOSI |
| 5 | SDO | P1.02 | MISO |
| 6 | CSB | P1.03 | Chip select, active low |
| 7 | WCT | — | Wilson central terminal; not needed for 3-lead EEG/ECG, leave floating |
| 8 | ALAB | Optional | Alarm output, active low; firmware can read `ERROR_LOD` instead, so it may be left unconnected |
| 9 | DRDB | P1.04 | Data ready, active low, falling-edge interrupt, **must be connected** |

> The module has **no RESET pin**. The overlay does not declare `reset-gpios`; the driver performs a soft reset via `CONFIG=0`, and P1.05 is left unconnected.

**Nets of the two 3.5 mm electrode jacks**

| Jack | Contact | Net |
|---|---|---|
| P1 | 1 (tip) | IN1 |
| | 2 (ring) | IN2 |
| | 3 (sleeve) | IN3 |
| | 4–7 | Mechanical/plug-detect switch, no signal |
| P2 | 1 (tip) | IN4 |
| | 2 (ring) | IN5 |
| | 3 (sleeve) | IN6 |
| | 4–7 | Mechanical/plug-detect switch, no signal |

> ⚠️ On P1/P2 there is a plug-detect switch between pin 2 and pin 3: with nothing plugged in, the two inputs are shorted. **A three-conductor TRS plug must be used**; a two-conductor TS plug would short IN2/IN3 (or IN5/IN6) together.

**Mapping to the current 3-lead firmware** (533 sps):

- CH1 = IN2 − IN1
- CH2 = IN3 − IN1
- CH3 = IN3 − IN2
- RLD output → IN4 (P2 tip)

**Suggested 2-channel, 6-electrode EEG setup (common reference, no firmware change)**

| Electrode | Position | Plug into | Net | Role |
|---|---|---|---|---|
| E1 | Left mastoid A1 | P1-1 | IN1 | Common reference REF |
| E2 | Left forehead Fp1 | P1-2 | IN2 | CH1 positive input |
| E3 | Right forehead Fp2 | P1-3 | IN3 | CH2 positive input |
| E4 | Right mastoid A2 | P2-1 | IN4 | RLD / bias |
| E5/E6 | Spare (Fpz/ground/shielding) | P2-2 / P2-3 | IN5 / IN6 | — |

→ CH1 = Fp1 − A1, CH2 = Fp2 − A1; the App only needs to display CH0/CH1 by default.

> To measure alpha (8–13 Hz), place E2/E3 at O1/O2 (occipital); Fp1/Fp2 on the forehead mainly pick up frontal EEG and eye-movement artifacts.
> Bipolar 2-channel (Fp1−F3 / Fp2−F4) requires changing the POS/NEG selection in `FLEX_CH1/2` and confirming whether the RLD output can be moved from IN4 to IN5; the current firmware does not do this.
>
> Full EEG/EMG test procedure, electrode placement, App settings, and troubleshooting are in **[eeg-emg-test.md](eeg-emg-test.md)**.

## 3. Firmware Change List (relative to master)

| File | Change |
|---|---|
| `02-firmware/src/ads1293.c` | Added: SPI driver + register configuration + DRDY interrupt + data readout |
| `02-firmware/src/ads1293.h` | Added: API and pin description, `WALKEEG_ADS1293_AVAILABLE` build switch |
| `02-firmware/dts/bindings/ti/ti,ads1293.yaml` | Added: devicetree binding |
| `02-firmware/boards/nrf52840dk_nrf52840.overlay` | Added SPI1 node + ads1293 child node (AD8232 section untouched) |
| `02-firmware/src/stream.c` | sampler thread selects the data source by build switch: ADS1293 → CH0-2 three leads; AD8232 → original logic |
| `02-firmware/src/main.c` | Initialization selects `walkeeg_ads1293_init()` / `walkeeg_adc_init()` by switch |
| `02-firmware/Kconfig` | Added `CONFIG_WALKEEG_USE_ADS1293` (default y) |
| `02-firmware/prj.conf` | Added `CONFIG_SPI=y`, `CONFIG_NRFX_SPIM=y` |
| `02-firmware/CMakeLists.txt` | Added `src/ads1293.c` |

## 4. ADS1293 Register Configuration (533 sps, 3 leads)

| Register | Address | Value written | Meaning |
|---|---|---|---|
| CONFIG | 0x00 | 0x00 → 0x01 | Exit standby first, then START_CON=1 |
| FLEX_CH1_CN | 0x01 | 0x11 | CH1: POS=IN2, NEG=IN1 (Lead I) |
| FLEX_CH2_CN | 0x02 | 0x19 | CH2: POS=IN3, NEG=IN1 (Lead II) |
| FLEX_CH3_CN | 0x03 | 0x1A | CH3: POS=IN3, NEG=IN2 (Lead III) |
| CMDET_EN | 0x0A | 0x07 | Common-mode detection enabled on IN1/2/3 |
| RLD_CN | 0x0C | 0x04 | RLD amplifier output to IN4 |
| REF_CN | 0x11 | 0x00 | Internal 2.4V reference enabled |
| OSC_CN | 0x12 | 0x00 → 0x04 | STRTCLK=1 after crystal starts |
| AFE_RES | 0x13 | 0x00 | FS=102.4 kHz, low-power mode |
| AFE_SHDN_CN | 0x14 | 0x00 | All three channels enabled |
| R2_RATE | 0x21 | 0x01 | R2=4 |
| R3_RATE_CH1/2/3 | 0x22/23/24 | 0x08 | R3=12 |
| R1_RATE | 0x25 | 0x00 | R1=4 (standard PACE rate) |
| DRDYB_SRC | 0x27 | 0x08 | DRDYB driven by CH1 ECG |
| CH_CNFG | 0x2F | 0x70 | Round-robin readback enabled E3+E2+E1 |

**ODR calculation**: `fODR = fS / (R1×R2×R3) = 102400 / (4×4×12) = 533.3 Hz`, BW ≈ 105 Hz.

**Data readout**: DRDYB falling edge → GPIO interrupt → semaphore; `spi_transceive` sends 0xD0 (read 0x50), then
receives 9 bytes continuously = 3 bytes per channel (CH1/2/3) of 24-bit data, **MSB first, offset-binary** (0V differential input = 0x400000).
The stream layer converts to int16: `(raw - 0x400000) >> 8`, centered at 0, full scale ±0x8000.

## 5. Build and Switching

```bash
# Default (master configuration): ADS1293 enabled
west build -b nrf52840dk_nrf52840 --sysbuild   # or simply west build -b nrf52840dk_nrf52840

# Switch back to AD8232 (SAADC single channel + sawtooth test signal)
west build -b nrf52840dk_nrf52840 -DCONFIG_WALKEEG_USE_ADS1293=n
```

After flashing, the log (RTT) should show:
```
walkeeg_ads1293: ADS1293 REVID=0x01 (SPI OK)
walkeeg_ads1293: ADS1293 init OK (3-lead ECG, 533 sps, DRDY P1.4)
```

If you see `Unexpected REVID` or `SPI device not ready`: check the SCLK/MOSI/MISO/CS wiring, the VDD/VDDIO supply, and the CVREF capacitor.

## 6. BLE Frame Format (unchanged)

Keeps the 8-channel int16 frame (App compatible):
- ADS1293 mode: CH0=Lead I, CH1=Lead II, CH2=Lead III, CH3-7=0; flags bit0=IN1 lead-off status (1=connected), bit1=IN2
- AD8232 mode: CH0=AD8232, CH1=sawtooth test, CH2-7=0 (original logic)

## 7. TODO / Future Improvements

- [ ] Verify SPI timing and REVID on hardware (no NCS toolchain on this machine, not build-verified)
- [ ] Full lead-off LOD configuration (currently only reads the ERROR_LOD status bit; LOD excitation current is not enabled)
- [ ] Sample-rate alignment: 533 Hz vs. 500 Hz frame-header marker (if the App truly needs strict 500 Hz, use the 400/800 Hz settings instead)
- [ ] When porting to nRF54L15, just add an ads1293 node to the corresponding overlay to reuse this driver
