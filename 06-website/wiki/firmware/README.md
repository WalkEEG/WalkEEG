# Firmware

Zephyr application for the **nRF52840**, streaming biosignals over BLE using the Nordic UART Service (NUS).

---

## At a glance

| | |
|---|---|
| **SoC** | nRF52840 (also builds for nRF5340, nRF54L15, nRF54H20) |
| **RTOS** | Zephyr 3.4.99 via Nordic Connect SDK |
| **Radio** | BLE 5.0 peripheral — 2M PHY, Data Length Extension, MTU 498 |
| **Service** | Nordic UART Service (NUS) |
| **Device name** | `WalkEEG` |
| **Analog front end** | AD8232 (SAADC) or ADS1293 (SPI) — Kconfig switch |
| **Sample rate** | 500 / 1000 / 2000 / 4000 Hz, runtime-selectable |
| **Frame** | 8 channels × 16-bit, 6-byte header |

---

## Source layout

```
02-firmware/
├── src/
│   ├── main.c          BLE setup, NUS callbacks, LED state machine
│   ├── stream.c        Sample timer → ring buffer → BLE notify
│   ├── adc_sample.c    AD8232 path (SAADC AIN0 = P0.02)
│   └── ads1293.c       ADS1293 path (SPIM1, 3-lead)
├── boards/             Per-board .conf and .overlay files
├── dts/bindings/       Custom devicetree bindings
├── prj.conf            Application configuration
└── Kconfig             WalkEEG-specific options
```

---

## Analog front end: choose one

The firmware supports two AFEs. Which one is compiled in is decided by a single Kconfig symbol:

```ini
＃ prj.conf
＃ AD8232 on-board AFE (default for the nRF52840 DK)
＃ CONFIG_WALKEEG_USE_ADS1293 is not set
```

| | **AD8232** | **ADS1293** |
|---|---|---|
| Interface | Analog → SAADC | SPI (mode 0) |
| Channels | 1 (single lead) | 3 (Lead I / II / III) |
| Resolution | 12-bit | 24-bit |
| Rate | 500 / 1000 / 2000 / 4000 Hz | 533 SPS (configurable) |
| Lead-off | External LO+/LO− comparator | Built-in LOD |
| Pin use | AIN0 = P0.02, LO± on P1.x | SPIM1 on P1.00–P1.05 |
| Kconfig | `# CONFIG_WALKEEG_USE_ADS1293 is not set` | `CONFIG_WALKEEG_USE_ADS1293=y` |

> ⚠️ **`CONFIG_WALKEEG_USE_ADS1293` defaults to `y`.** If your board has an AD8232 and you leave the default, the firmware tries to initialise a chip that isn't there, faults inside `walkeeg_ads1293_init()`, and resets every ~85 s. The symptom is an LED that blinks irregularly and no BLE advertisement. Always set this explicitly.

The ADS1293 pinout and register map are documented in [`docs/ads1293/`](https://github.com/WalkEEG/WalkEEG/tree/master/docs/ads1293).

---

## BLE configuration

```ini
CONFIG_BT=y
CONFIG_BT_PERIPHERAL=y
CONFIG_BT_DEVICE_NAME="WalkEEG"
CONFIG_BT_NUS=y

＃ Throughput
CONFIG_BT_CTLR_PHY_2M=y              # 2 Mbps PHY
CONFIG_BT_CTLR_DATA_LENGTH_MAX=251   # DLE: 27 → 251 byte payloads
CONFIG_BT_L2CAP_TX_MTU=498           # long ATT MTU
CONFIG_BT_BUF_ACL_RX_SIZE=502
CONFIG_BT_BUF_ACL_TX_SIZE=502

＃ Connection interval: 6 × 1.25 ms = 7.5 ms
CONFIG_BT_PERIPHERAL_PREF_MIN_INT=6
CONFIG_BT_PERIPHERAL_PREF_MAX_INT=12
```

**Why these numbers matter.** At 500 Hz with 8 channels × 2 bytes, one second of data is 8,000 bytes. With the default 27-byte payload and 30 ms connection interval you get roughly 720 bytes/s — nowhere near enough. Turning on 2M PHY, DLE and a 498-byte MTU raises a single notification to 495 bytes of payload, and a 7.5 ms interval allows ~130 notifications/s.

---

## Logging

`CONFIG_LOG_BACKEND_UART` is **off** — console output goes to **SEGGER RTT** instead. UART0 is reserved for the NUS data path on P0.13/P0.12.

```ini
CONFIG_LOG=y
CONFIG_USE_SEGGER_RTT=y
CONFIG_LOG_BACKEND_RTT=y
CONFIG_LOG_BACKEND_UART=n
```

> ⚠️ **Do not enable `CONFIG_LOG_MODE_IMMEDIATE`.** In immediate mode the RTT backend writes synchronously, and on a fault the panic path deadlocks inside `log_backend_std_panic` — the crash log never appears *and* boot stalls. Leave logging asynchronous (the default).

---

## Startup LED codes

Not every board has a serial console attached, so the firmware narrates its progress through the run LED:

| Blinks | Reached |
|---|---|
| 1 | `bt_enable()` returned |
| 2 | NUS service initialised |
| 3 | Analog front end initialised |
| 4 | BLE advertising started |
| 8 | `bt_le_adv_start()` failed — check the RTT log for the error code |

After the last code, the LED settles into a 1 Hz heartbeat from the main loop. **A steady 1 Hz blink means the firmware reached `for (;;)` and everything before it succeeded.**

If the LED never settles — or resets every ~85 seconds — the front end or BLE init failed. See [Troubleshooting](troubleshooting.md).

---

## Next

- [Build & Flash](build.md) — toolchain setup and the exact commands that work
- [Troubleshooting](troubleshooting.md) — every failure mode we've hit, and the fix
- [Protocol](../protocol.md) — what goes over the wire
