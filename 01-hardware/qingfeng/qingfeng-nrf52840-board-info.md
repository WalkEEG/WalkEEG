# Qingfeng (Qingyun) nRF52840 Development Board Quick Reference

> Compiled from the schematics under `01-hardware/qingfeng/` in this repository: `52840core.pdf` (core board), `qingfeng-840-baseboard-1.pdf`, and `qingfeng-840-baseboard-2.pdf`.
> Board vendor: Qingfeng Electronics (forum qfv8.com); the vendor examples call it the "Qingyun nRF52840 Bluetooth Development Board".
> Compiled: 2026-11-02. Pins follow the **schematic net labels**; pins on module sockets that the schematic does not label are called out separately.

---

## 1. Board Overview

- **Structure**: core board (`52840core.pdf`, 3 pages, 2018-11-18) plus two baseboard sheets (`qingfeng-840-baseboard-1.pdf` / `qingfeng-840-baseboard-2.pdf`, 2018-11-06).
- **Main controller**: nRF52840-**QIAA** (aQFN73, 7×7 mm).
- **Baseboard resources**: 4× LED, 4× push buttons + reset button, buzzer, CH340 USB-UART, nRF52840 native USB, W25X80 SPI flash, MicroSD socket, LIS3DH/OLED1 module socket, OLED2 socket, MPU6050 socket, WIFI module socket, NFC antenna socket, touch module socket, photoresistor, DHT11 socket, relay interface (JDQ), CR2032 backup battery.
- **Power**: USB 5V → AMS1117-3.3; the core board can be powered from VDD_HV (high-voltage mode) or VDD_nRF (3.3V).

---

## 2. Chip Specifications (nRF52840-QIAA)

| Item | Specification |
|---|---|
| CPU | Cortex-M4F @ 64 MHz (with FPU/DSP) |
| Memory | **1 MB flash / 256 KB RAM** |
| GPIO | 48 (P0.00~P0.31 + P1.00~P1.15) |
| Radio | BLE 5.0 (1M/2M/Coded PHY), IEEE 802.15.4 (Thread/Zigbee), 2.4 GHz proprietary, NFC-A |
| USB | USB 2.0 Full-Speed (12 Mbps), native D+/D- |
| UART | **2× UARTE** |
| SPI/TWI | 4× SPIM/SPIS, 2× TWIM/TWIS; **QSPI** (for external flash) |
| Other peripherals | I2S, PDM, 4× PWM, 8-channel SAADC, 2× RTC, comparator, temperature sensor |
| Supply | 1.7~5.5 V (VDDH high-voltage mode), internal DC-DC |
| Package | aQFN73 (QIAA), **not compatible** with nRF52833/nRF52832 (different pins and package) |

> Compared with the nRF52833: 1 MB flash (vs 512 KB), 256 KB RAM (vs 128 KB), and the 52840 additionally has QSPI, USB, and 802.15.4.

---

## 3. Core Board

### 3.1 Key Components

| Item | Specification / part |
|---|---|
| MCU | nRF52840-QIAA (aQFN73) |
| High-speed crystal | X1: 32 MHz (C1/C2 = 12 pF) |
| Low-speed crystal | X2: 32.768 kHz, connected to **P0.00/XL1, P0.01/XL2** (C17/C18 = 12 pF) |
| RF matching | ANT → L1 3.9 nH, C3 1.0 pF, L3 15 nH, C4 1.0 pF, C8 820 pF, C9 1.2 pF (C22/C23 N.C.) |
| DC-DC | L2 10 µH (DEC4), L4 10 µH (DCCH), C6/C19/C20/C21 = 4.7 µF |
| Power nets | VDD_nRF (3.3 V), VDD_HV (high-voltage input), VBUS_nRF (USB VBUS) |
| Debug | SWD: SWDCLK / SWDIO; P0.18/RESET |
| Breakout | P1 / P2: 2×14 double-row headers (see 3.2) |

> ⚠️ P0.00 / P0.01 are connected to the 32.768 kHz crystal on the core board by default; to use them as GPIO or I2C, first check whether X2 is fitted and remove it if needed.

### 3.2 Core Board Headers

**P1 (2×14)**

| Pin | Net | Pin | Net |
|---|---|---|---|
| 1 | P0.10/NFC2 | 2 | P0.09/NFC1 |
| 3 | P1.07 | 4 | P1.06 |
| 5 | P1.05 | 6 | P1.04 |
| 7 | P1.03 | 8 | P1.02 |
| 9 | SWDCLK | 10 | SWDIO |
| 11 | P1.01 | 12 | P1.00 |
| 13 | P0.25 | 14 | P0.24 |
| 15 | P0.23 | 16 | P0.22 |
| 17 | P0.21 | 18 | P0.20 |
| 19 | P0.19 | 20 | P0.18/RESET |
| 21 | P0.17 | 22 | P0.16 |
| 23 | P0.15 | 24 | P0.14 |
| 25 | P0.13 | 26 | P0.12 |
| 27 | VDD_nRF | 28 | VDD_HV |

**P2 (2×14)**

| Pin | Net | Pin | Net |
|---|---|---|---|
| 1 | P1.10 | 2 | P1.11 |
| 3 | P1.12 | 4 | P1.13 |
| 5 | P1.14 | 6 | P1.15 |
| 7 | P0.03/AIN1 | 8 | P0.02/AIN0 |
| 9 | P0.28/AIN4 | 10 | P0.29/AIN5 |
| 11 | P0.30/AIN6 | 12 | P0.31/AIN7 |
| 13 | P0.01 | 14 | P0.00 |
| 15 | P0.26 | 16 | P0.27 |
| 17 | P0.04/AIN2 | 18 | P0.05/AIN3 |
| 19 | P0.06 | 20 | P0.07 |
| 21 | P0.08 | 22 | P1.08 |
| 23 | P1.09 | 24 | P0.11 |
| 25 | D- | 26 | D+ |
| 27 | VBUS_nRF | 28 | VBUS |

---

## 4. Baseboard Peripherals and Pin Mapping (Key Section)

### 4.1 On-Board Basic Peripherals

| Peripheral | Signal | Pin | Notes / source |
|---|---|---|---|
| LED1 / LED2 / LED3 / LED4 | — | **P0.13 / P0.14 / P0.15 / P0.16** | Active-low (LED cathode to GPIO, anode via 220R to VCC3.3); R2/R3/R5/R6 = 220R |
| Buttons BUTTON1 / BUTTON2 | — | **P0.11 / P0.12** | SW1/SW2, pulled low when pressed; 10k pull-up (R15, baseboard sheet 2) |
| Buttons BUTTON3 / BUTTON4 | — | **P0.24 / P0.25** | SW3/SW4, pulled low when pressed (baseboard sheet 2) |
| Reset button REST | P0.18/RESET | **P0.18** | REST1 + 10k pull-up |
| Buzzer BEEP | BEEP | **P0.27** | R18 1k → Q1 (2N3904) → LS1 (Bell); R20 10k base pull-down |
| USB-UART (CH340) | TX / RX / RTS / CTS | **P0.06 / P0.08 / P0.05 / P0.07** | U1 = CH340, 12 MHz crystal; `TXD`→P0.08, `RXD`→P0.06 |
| nRF native USB | D+ / D- / VBUS | P2-26 / P2-25 / VBUS_nRF | USB2 connector, PRTR5V0U2X ESD protection, ferrite beads FB1/FB2 |
| SPI flash | SCK / MOSI / MISO / CS | **P0.23 / P0.20 / P0.21 / P0.22** | U2 = W25X80 (per schematic), nHOLD/nWP pulled up via R22 10k |
| MicroSD socket | SD_CS / SCK / MOSI / MISO | **P0.19** / shares P0.23 / P0.20 / P0.21 | U3; shares the SPI bus with the flash, SD_CS is separate |
| Photoresistor | AD | **P0.04 / AIN2** | D1 (Photo Sen) + R4 10k, SAADC samples AIN2 |
| Touch module | TK (OUT) | **P0.26** | JR1 6-pin module socket (OUT/GND/S0/SHH/VDD/STG), C14 22 pF, R23 1k |
| Temp/humidity (DHT11 type) | WS | **P1.08** | P5 module socket (1 GND / 2 WS / 3 VCC3.3) |
| Relay interface | JDQ | **P1.09** | Pin 23 of P11 |
| Power | — | — | AMS1117-3.3, USB1 (5V), S1 power switch, CR2032 backup |

### 4.2 Module Sockets

| Interface | Purpose | Pin mapping |
|---|---|---|
| P14 (2×5) | **LIS3DH / OLED1 module socket** | 10 VCC3.3 · 9 GND · 8 INT2=**P1.10** · 7 INT1=**P1.11** · 6 LS_CS=**P1.12** · 5 LS_SCL=**P1.13** · 4 SDO=**P1.14** · 3 LS_SDA=**P1.15** (pins 1/2 unlabeled in schematic) |
| P6 (Header 7) | **OLED2 socket** (4-wire SPI) | 7 OCS(CS)=**P0.03** · 6 DC=**P0.02** · 5 RST=**P0.28** · 4 MOSI=**P0.29** · 3 OSCK(SCK)=**P0.30** · 1/2 = VCC3.3 / GND |
| P7 (Header 8) | **MPU6050 socket** (I2C) | 6 SCL=**P0.01** · 5 SDA=**P0.00** · 1 INT=**P0.31** · 7 GND; other pins are separately marked P0.02/P0.03/P0.28~P0.30 in the schematic — wire per the schematic |
| P8 (4×2) | **WIFI module socket** | 1 WTXD=**P1.07** · 2 GND · 3 W3=**P1.05** · 4 W2=**P1.06** · 5 W1=**P1.03** · 6 W0=**P1.04** · 7 VCC3.3 · 8 WRXD=**P1.02** |
| P3 (Molex 051281-0594) | **NFC antenna socket** | 2 NFC1=**P0.09** · 4 NFC2=**P0.10**, 300 pF (C5/C7) + 0R jumpers R9/R10/R12; pins 1/3/5 NC |
| P5 (Header 3) | Temp/humidity module | 1 GND · 2 WS=**P1.08** · 3 VCC3.3 |
| P4 (Header 4) | USB breakout | VCC5.0 / D- / D+ / GND |
| P1 / P2 (power) | Power in/out | P1: 5V / 3.3V / GND; P2: VCCore / 3.3V |

### 4.3 Core Board Sockets P10 / P11 (internal, mate with the core board — do not attach Dupont wires)

> ⚠️ Correction (2026-11-04): P10/P11 are the 2×14 sockets on the baseboard that receive the core board — they are not external headers.
> Only **P12 / P13** accept Dupont wires. The tables below list the socket nets (i.e. core board P1/P2), useful for verifying routing — do not plug Dupont wires here.

**P10 (2×14) — core board P1 socket (baseboard function of the same net in parentheses)**

| Pin | Pin name | Function net | Pin | Pin name | Function net |
|---|---|---|---|---|---|
| 1 | P0.10/NFC2 | — | 2 | P0.09/NFC1 | — |
| 3 | P1.07 | WTXD | 4 | P1.06 | W2 |
| 5 | P1.05 | W3 | 6 | P1.04 | W0 |
| 7 | P1.03 | W1 | 8 | P1.02 | WRXD |
| 9 | SWDCLK | — | 10 | SWDIO | — |
| 11 | P1.01 | — | 12 | P1.00 | — |
| 13 | P0.25 | BUTTON4 | 14 | P0.24 | BUTTON3 |
| 15 | P0.23 | SCK | 16 | P0.22 | F_CS |
| 17 | P0.21 | OUT | 18 | P0.20 | DIN |
| 19 | P0.19 | SD_CS | 20 | P0.18/RESET | — |
| 21 | P0.17 | — | 22 | P0.16 | LED4 |
| 23 | P0.15 | LED3 | 24 | P0.14 | LED2 |
| 25 | P0.13 | LED1 | 26 | P0.12 | BUTTON2 |
| 27 | VDD_nRF | — | 28 | VDD_HV | — |

**P11 (2×14) — core board P2-side socket (internal, function nets)**

> Note: pins 27/28 of P11 are GND / VBUS_nRF in the netlist, which does not fully match the VBUS_nRF / VBUS markings on core board P2; defer to the silkscreen on the physical board.

| Pin | Function | GPIO | Pin | Function | GPIO |
|---|---|---|---|---|---|
| 1 | INT2 | P1.10 | 2 | INT1 | P1.11 |
| 3 | LS_CS | P1.12 | 4 | LS_SCL | P1.13 |
| 5 | SDO | P1.14 | 6 | LS_SDA | P1.15 |
| 7 | OCS | P0.03 | 8 | DC | P0.02 |
| 9 | RST | P0.28 | 10 | MOSI | P0.29 |
| 11 | OSCK | P0.30 | 12 | INT | P0.31 |
| 13 | SCL | P0.01 | 14 | SDA | P0.00 |
| 15 | TK | P0.26 | 16 | BEEP | P0.27 |
| 17 | AD | P0.04 | 18 | CTS | P0.05 |
| 19 | RXD | P0.06 | 20 | RTS | P0.07 |
| 21 | TXD | P0.08 | 22 | WS | P1.08 |
| 23 | JDQ | P1.09 | 24 | BUTTON1 | P0.11 |
| 25 | D_N | — | 26 | D_P | — |
| 27 | GND | — | 28 | VBUS_nRF | — |

### 4.4 External Dupont Headers P12 / P13 (the only ones you can wire to)

P12 maps one-to-one to core board P1 (pins 1~26) and P13 maps one-to-one to core board P2 (pins 1~26); they lack the 27/28 power pins of P1/P2. Take power and ground from the baseboard power header. When wiring, just align by the same pin numbers as in section 3.2.

---

## 5. SAADC Channels

| AIN | Pin | Occupied on board by |
|---|---|---|
| AIN0 | P0.02 | **OLED2 DC** |
| AIN1 | P0.03 | **OLED2 CS (OCS)** |
| AIN2 | P0.04 | **Photoresistor AD** (SAADC sampling) |
| AIN3 | P0.05 | **CH340 RTS** |
| AIN4 | P0.28 | **OLED2 RST** |
| AIN5 | P0.29 | **OLED2 MOSI** |
| AIN6 | P0.30 | **OLED2 SCK (OSCK)** |
| AIN7 | P0.31 | **MPU6050 INT** |

---

## 6. Software and Development Environment

| Item | Details |
|---|---|
| Vendor examples | On the bundled cloud-drive material (nRF5 SDK 17 / Keil); not included in this repository |
| Zephyr / NCS | The board definition **`nrf52840dk/nrf52840`** (pca10056) runs as-is; override peripheral pins per the tables above |
| Debug/flash | J-Link (SWDCLK/SWDIO) + P0.18 reset |
| Serial | On-board CH340: TX=P0.06, RX=P0.08 (115200 8N1) |
| USB | nRF native USB can be used for CDC/bootloader; D+/D- are broken out to P2 25/26 |

### Existing Wiring Conventions in This Repository (WalkEEG)

- `02-firmware/boards/nrf52840dk_nrf52840.overlay`:
  - NUS physical UART: **P0.13 = TX, P0.12 = RX** (P12 pins 25/26), with the default `led0` and `button1` disabled;
  - AD8232: **AIN0 = P0.02** (P13 pin 8), gain 1/6;
  - ADS1293 (SPI1): **SCLK=P1.00 (P12-12), MOSI=P1.01 (P12-11), MISO=P1.02 (P12-8), CS=P1.03 (P12-7), DRDY=P1.04 (P12-6), RESET=P1.05 (P12-5)**; GND/3V3 taken from the baseboard power header. 9-pin modules such as CJMCU-1293 have no RST, so P1.05 stays unconnected and the firmware uses a CONFIG=0 soft reset.
- Note: on this development board P0.12/P0.13 are normally **BUTTON2 / LED1**; using them for UART requires disabling the corresponding peripherals as the existing overlay does.

---

## 7. Cautions (Important)

1. **P0.00 / P0.01 are connected to the 32.768 kHz crystal by default** (core board X2). Before using them as GPIO or I2C (e.g. SCL/SDA on the MPU6050 socket), confirm whether the crystal is fitted or needs removal.
2. **P0.09 / P0.10 = NFC1 / NFC2**: connect to NFC antenna socket P3; usable as normal GPIO when no antenna is attached, but mind the 300 pF caps and 0R jumpers.
3. **P0.18 = RESET**; the board already has a reset button, so do not use it as a normal IO.
4. **LED1~4 = P0.13~P0.16**, active-low (sinking current), high = off.
5. **Buttons = P0.11 / P0.12 / P0.24 / P0.25**, active-low, with 10k pull-ups on board.
6. **BEEP = P0.27**, driven through a 2N3904, active-high.
7. **Flash and SD card share SPI**: SCK=P0.23, MOSI=P0.20, MISO=P0.21; Flash_CS=P0.22, SD_CS=P0.19 — only one chip select may be active at a time.
8. **CH340 UART occupies P0.05~P0.08**, of which P0.05/P0.07 are also the alternate functions AIN3/AIN5.
9. **P1 port allocation**: P1.02~P1.07 = WIFI socket, P1.08 = WS (DHT11), P1.09 = JDQ, P1.10~P1.15 = LIS3DH/OLED1 socket; these are the same nets as on the P10/P11 headers, so do not contend for pins when plugging in modules.
10. **OLED2 and the MPU6050 socket share P0.28~P0.31** (RST/MOSI/SCK/INT); plugging in both modules at once conflicts.
11. **Not interchangeable with the Qingfeng nRF52833 board**: LED/button counts, UART chip (CH340 on this board), and pin layout all differ, so code and wiring cannot be copied over (52833 board notes in a separate project: Qingfeng nRF52833 development board info, `BALANX2_FIRMWARE/`).
12. Some module socket pins in the schematic (P14 pins 1/2, P6 pin 2, P7 pins 2~4/8) carry no net name; wire per the PCB silkscreen/physical board.

---

## Appendix: Source Files

| Purpose | File |
|---|---|
| Core board schematic | `01-hardware/qingfeng/52840core.pdf` |
| Baseboard schematic 1 (headers/OLED/Flash/SD/touch/USB) | `01-hardware/qingfeng/qingfeng-840-baseboard-1.pdf` |
| Baseboard schematic 2 (LED/buttons/CH340/power/NFC/module sockets) | `01-hardware/qingfeng/qingfeng-840-baseboard-2.pdf` |
| 52840 firmware configuration in this repo | `02-firmware/boards/nrf52840dk_nrf52840.overlay`, `.conf` |
