# Build & Flash

Everything below was verified on macOS with **NCS v2.5.99-dev1** and **Zephyr SDK 0.16.1**. Other versions work too — the pitfalls are version-independent.

---

## 1. Toolchain

You need:

- **Nordic Connect SDK** (contains Zephyr + nRF drivers + west manifest)
- **Zephyr SDK** (the ARM cross compiler)
- `west`, `cmake`, `ninja`, `dtc`
- `nrfutil` with the `device` subcommand — for flashing

### Install

```bash
＃ Nordic Connect SDK toolchain manager (recommended)
nrfutil install nrf5sdk-tools
nrfutil sdk-manager install v2.5.99-dev1

＃ Flashing support
brew install --cask nrfutil      # macOS
nrfutil install device
```

### Verify

```bash
arm-zephyr-eabi-gcc --version     # → 12.2.0 for SDK 0.16.1
west --version                    # → West version: v1.2.0
nrfutil device list               # → should list your J-Link / DK
```

> **Watch out:** the SDK manager can leave behind an *empty* version directory. If `/opt/nordic/ncs/v2.5.2` exists but is 0 bytes, it has no Zephyr tree and every build will fail with confusing errors. Confirm before building:
> ```bash
> ls /opt/nordic/ncs/*/zephyr/VERSION     # must print a real file
> du -sh /opt/nordic/ncs/*                # a real SDK is ~2 GB
> ```

---

## 2. Build

**`west build` must run from inside the NCS west workspace**, not from the application directory. Running it in `02-firmware/` gives `unknown command 'build'`.

```bash
＃ Adjust these to your install
export NCS=/opt/nordic/ncs/v2.5.99-dev1
export TOOLCHAIN=/opt/nordic/ncs/toolchains/20d68df7e5

export ZEPHYR_BASE=$NCS/zephyr
export ZEPHYR_TOOLCHAIN_VARIANT=zephyr
export ZEPHYR_SDK_INSTALL_DIR=$TOOLCHAIN/opt/zephyr-sdk
export PATH=$TOOLCHAIN/bin:$ZEPHYR_SDK_INSTALL_DIR/arm-zephyr-eabi/bin:$PATH

cd $NCS
west build -b nrf52840dk_nrf52840 -d /tmp/build-walkeeg <path-to>/02-firmware
```

The output directory is deliberately outside the repo — `build/` is git-ignored but a stale CMake cache is the classic cause of "it built yesterday".

### Expected output

```
Memory region         Used Size  Region Size  %age Used
           FLASH:      213096 B         1 MB     20.32%
             RAM:       82308 B       256 KB     31.40%
```

### Other boards

```bash
west build -b nrf5340dk/nrf5340/cpuapp  -d /tmp/b5340 02-firmware
west build -b nrf54l15dk/nrf54l15/cpuapp -d /tmp/b54l15 02-firmware
```

Each has a matching `boards/<board>.overlay` and `.conf`.

---

## 3. Flash

### With nrfutil (recommended)

```bash
SER=$SER            # serial number from `nrfutil device list`

nrfutil device recover --serial-number $SER
nrfutil device program --serial-number $SER \
    --firmware /tmp/build-walkeeg/zephyr/zephyr.hex
nrfutil device reset   --serial-number $SER
```

`recover` erases everything and clears protection — do this first if a previous flash left the chip in a strange state.

### With a J-Link (may not work)

`JLinkExe` reports success and the first flash often does land, but on some J-Link firmware the **write silently fails**:

```
Erasing flash     [100%] Done.
Downloading file [zephyr.bin]...
Error while programming flash: Programming failed.
Verify failed @ address 0x00001000.
```

Erase works, verify fails, and reading back shows `FF FF FF FF`. If you hit this, don't chase the target — switch to `nrfutil`.

---

## 4. Confirm it runs

After flashing, watch the run LED:

| What you see | What it means |
|---|---|
| Blinks 1 → 2 → 3 → 4, then steady 1 Hz | Everything initialised; advertising |
| Blinks stop early | The last number is where it failed |
| Blinks 8 times | `bt_le_adv_start()` failed |
| Irregular flicker, restarts every ~85 s | Hard fault during init — check the front end Kconfig |

Then scan with **nRF Connect** (iOS/Android). You should see a peripheral named **`WalkEEG`** advertising the NUS service UUID.

---

## 5. Live logs over RTT

Logs go to SEGGER RTT, not UART.

```bash
JLinkRTTLogger -Device NRF52840_xxAA -If SWD -Speed 4000 \
    -RTTChannel 0 /tmp/rtt.log -RTTCmd "r;g"
```

Sample output from a healthy boot:

```
[00:00:00.529] <inf> peripheral_uart: UART welcome queued (37 bytes)
[00:00:00.531] <inf> bt_hci_core: HW Platform: Nordic Semiconductor
[00:00:00.532] <inf> peripheral_uart: Bluetooth initialized
[00:00:00.532] <inf> bt_hci_core: Identity: C8:7F:42:59:2D:85 (random)
[00:00:00.534] <inf> walkeeg_stream: WalkEEG ECG stream module ready
[00:00:00.541] <inf> [diag] bt_nus_init OK
[00:00:00.552] <inf> [diag] walkeeg_adc_init OK
[00:00:00.560] <inf> [diag] adv_start OK
```

If the last line is missing, advertising never started — read the error code in the preceding `adv_start FAILED err=…` line.

---

## Clean rebuild

```bash
rm -rf /tmp/build-walkeeg
＃ then run the west build command again
```

Zephyr caches devicetree and Kconfig aggressively. After changing a `prj.conf`, an overlay, or a Kconfig symbol, **always** do a clean build before concluding something is broken.
