# Troubleshooting

Every failure below was hit during real bring-up. Each entry lists the **symptom**, the **cause**, and the **fix**.

---

## Build fails: unknown command 'build'

```
west: unknown command "build"; workspace … does not define this extension command
```

**Cause:** you ran `west build` from the application directory. `west` resolves the workspace from the current directory, and `02-firmware/` is not a west workspace.

**Fix:** `cd` into the NCS root first, then point `west` at the app:

```bash
cd /opt/nordic/ncs/v2.5.99-dev1
west build -b nrf52840dk_nrf52840 -d /tmp/build-walkeeg ~/path/to/02-firmware
```

---

## Build fails: hidden Kconfig symbol assigned directly

```
error: NRFX_SPIM (defined at modules/hal_nordic/nrfx/Kconfig:205) is assigned in a
configuration file, but is not directly user-configurable (has no prompt).
```

**Cause:** `prj.conf` assigns a **hidden Kconfig symbol**. These have no prompt and can only be selected indirectly by the driver they belong to.

| Don't set | Set instead |
|---|---|
| `CONFIG_NRFX_UARTE` | `CONFIG_UART_NRFX` — or nothing, it's implied by `CONFIG_SERIAL` |
| `CONFIG_NRFX_SPIM` | `CONFIG_SPI` |
| `CONFIG_NRFX_SAADC` | `CONFIG_ADC` |

**Fix:** delete the direct assignments. Verify the derived symbols appear in the generated config:

```bash
grep -E "CONFIG_UART_NRFX|CONFIG_ADC_NRFX_SAADC" /tmp/build-walkeeg/zephyr/.config
```

---

## Build fails: cs-gpios not declared in the binding

```
devicetree error: 'cs-gpios' appears in /soc/spi@40004000/ads1293@0 …,
but is not declared in 'properties:' in …/dts/bindings/ti/ti,ads1293.yaml
```

**Cause:** the board overlay gives the SPI device a `cs-gpios` property, but the binding's `.yaml` doesn't declare that property. Zephyr rejects unknown properties.

**Fix:** add it to the binding:

```yaml
＃ dts/bindings/ti/ti,ads1293.yaml
properties:
  cs-gpios:
    type: phandle-array
    required: false
    description: Optional explicit chip-select GPIO.
```

---

## Firmware resets every ~85 seconds, LED flickers irregularly, no BLE

**Symptom:** no device appears when scanning, and the LED does something that looks like "blinking very slightly" rather than a clean 1 Hz heartbeat.

**Cause:** `CONFIG_WALKEEG_USE_ADS1293` **defaults to `y`**, so the firmware tries to initialise an ADS1293 over SPI. If your board has an **AD8232** instead, nothing answers on the bus, `walkeeg_ads1293_init()` faults, and the watchdog resets the chip — roughly every 85 s.

Confirmed by RTT:

```
[00:00:00.534] <inf> walkeeg_stream: WalkEEG ECG stream module ready
[00:00:00.541] <err> os: ***** Reserved Exception ( -16) *****
[00:00:00.541] <err> os: Faulting instruction address (r15/pc): 0x00014629
[00:00:00.541] <err> os: >>> ZEPHYR FATAL ERROR 0: CPU exception on CPU 0
[00:01:25.208] <err> fatal_error: Resetting system
```

**Fix:**

```ini
＃ prj.conf
＃ CONFIG_WALKEEG_USE_ADS1293 is not set
```

Then confirm the SAADC path is active:

```bash
grep -E "CONFIG_WALKEEG_USE_ADS1293|CONFIG_ADC_NRFX_SAADC" /tmp/build-walkeeg/zephyr/.config
＃ → # CONFIG_WALKEEG_USE_ADS1293 is not set
＃ → CONFIG_ADC_NRFX_SAADC=y
```

---

## Flash writes "succeed" but nothing changes

```
Erasing flash     [100%] Done.
Downloading file [zephyr.bin]…
Error while programming flash: Programming failed.
Verify failed @ address 0x00001000.
```

**Cause:** an old J-Link firmware whose nRF52840 flash algorithm doesn't stick. Erase works, writes are dropped. **This is not read protection** — `APPROTECT` reads `00 01 00 00` (`PROTECTDISABLED`).

**Fix:** use `nrfutil` instead of `JLinkExe`:

```bash
nrfutil device recover --serial-number <SN>
nrfutil device program --serial-number <SN> --firmware zephyr.hex
nrfutil device reset   --serial-number <SN>
```

Verify the write landed:

```bash
nrfutil device read --serial-number <SN> --address 0x00000000 --bytes 16
＃ first word should be the initial stack pointer, e.g. 2000BAC0 — not FFFFFFFF
```

---

## Crash logs never appear

**Symptom:** the firmware misbehaves, but RTT shows nothing beyond the last successful `LOG_INF`.

**Cause:** `CONFIG_LOG_MODE_IMMEDIATE=y`. In immediate mode the RTT backend writes synchronously, and the panic path (`z_arm_fatal_error` → `log_backend_std_panic`) deadlocks. The message that would explain the crash never reaches the host.

**Fix:** remove the immediate-mode setting and keep logging asynchronous:

```ini
＃ CONFIG_LOG_MODE_IMMEDIATE=y
```

Because async logging is queued, a crash can also swallow the last few lines. If you need certainty, set a breakpoint at `z_arm_fatal_error` and inspect registers directly.

---

## Failed to save Database Hash (err -2) and the MAC changes on every reset

```
[00:00:00.534] <err> bt_gatt: Failed to save Database Hash (err -2)
[00:00:00.532] <inf> bt_hci_core: No ID address. App must call settings_load()
```

**Cause:** `settings_subsys_init()` was never called. `CONFIG_SETTINGS=y` alone is not enough — without the subsystem initialised, every `settings_save_one()` returns `-ENOENT` (-2). Bonding data and the identity address can't be persisted, so the stack generates a new random address each boot.

**Fix:** call it **before** `bt_enable()`:

```c
if (IS_ENABLED(CONFIG_SETTINGS)) {
    err = settings_subsys_init();
    /* log on error */
}

err = bt_enable(NULL);

if (IS_ENABLED(CONFIG_SETTINGS)) {
    err = settings_load();      /* check the return value */
}
```

Order matters: `bt_enable()` already touches the settings backend internally.

---

## Debugger faults on every halt

**Symptom:** you halt the core and `PC` looks like it's inside an interrupt vector (`0x14628`, `0x14654`, an MPSL-obfuscated symbol), and `CycleCnt` never advances between samples.

**Cause:** most likely your own script. `JLinkExe` command files that contain `h` (halt) or `r` (reset-and-halt) stop the core deliberately — so of course it isn't running.

```bash
＃ ❌ This halts the core every time
si SWD / speed 4000 / device NRF52840_xxAA / connect / r / g / sleep 400 / h / regs
```

Only `r` + `g` (reset, then go) leaves the firmware running. Verify with the LED, which needs no debugger at all.

---

## Quick checklist

| Symptom | First thing to check |
|---|---|
| `west build` unknown command | Are you in the NCS root? |
| Kconfig hidden-symbol error | `grep NRFX_ prj.conf` |
| Reset every ~85 s | `CONFIG_WALKEEG_USE_ADS1293` |
| Flash verify fails | Use `nrfutil`, not `JLinkExe` |
| No crash log | `CONFIG_LOG_MODE_IMMEDIATE` |
| MAC changes each boot | `settings_subsys_init()` |
| LED never reaches 4 blinks | Front end init, then RTT log |
| LED blinks 1 Hz but no scan result | Radio/antenna, or adv error code in RTT |
