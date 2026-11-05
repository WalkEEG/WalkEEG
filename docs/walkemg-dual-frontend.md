# WalkEMG 双前端共存（AD8232 + ADS1293）

分支 `WalkEMG` · 2026-11-04

## 接线（nRF52840 DK）
| 前端 | 信号 | 引脚 |
|---|---|---|
| AD8232 | OUT → AIN0 | P0.02 (P13 pin 8) |
| AD8232 | LO+ / LO- / SDN | P1.13 / P1.15 / P1.14 |
| ADS1293 | SCLK / MOSI / MISO | P1.00 / P1.01 / P1.02 |
| ADS1293 | CS / DRDY / RESET | P1.03 / P1.04 / P1.05 |
| UART | TX / RX | P0.13 / P0.12 |

两路引脚不重叠，可以同时插。

## 帧映射
| 帧通道 | 默认（AD8232 模式） | 仅 ADS1293 | **双前端** |
|---|---|---|---|
| CH0 | AD8232 原始 12-bit | Lead I | **AD8232 原始 12-bit** |
| CH1 | 锯齿测试信号 | Lead II | **ADS1293 ECG1** |
| CH2 | 0 | Lead III | **ADS1293 ECG2** |
| CH3..7 | 0 | 0 | 0 |

flags：bit0/1 = AD8232 LO+/LO-；bit2/3 = ADS1293 IN1/IN2（1 = 已接）。

## 打开方式
`prj.conf`（或 `boards/*.conf`）：
```
CONFIG_WALKEEG_USE_ADS1293=y
CONFIG_WALKEEG_DUAL_FRONTEND=y
```
默认关闭，不开时行为与之前完全一致。

## 采样率
- AD8232 / 帧率：`SET_RATE 500|1000|2000|4000`，默认 2000。
- ADS1293 自己跑 533 sps（R2=4, R3=12, fMOD=102.4 kHz）。
- 双前端模式下采样线程**不阻塞等 DRDY**：有 DRDY 才读新值，否则保持上一份 →
  CH1/CH2 呈阶梯（每 ~1.9 ms 更新一次），CH0 仍是真实 2000 Hz。
- 想要较高 ODR：把 `REG_R3_RATE_CHx` 从 `0x08`（R3=12, 533 sps）改成 `0x01`
  （R3=4, 1600 sps）。注意这会同时影响 ECG-only 模式。

## 已知限制
- ADS1293 24-bit 右移 8 位成 int16：幅度刻度比 AD8232 的 0..4095 大很多，
  App 里同一屏看两条波形需要各自缩放（现在用 AC Auto 自动缩放）。
- 533 sps 对 EMG 包络（<100 Hz）够用；要看 100–450 Hz 原始 EMG 需要 1600+
  sps，或直接用 AD8232 那一路。
- 采样线程 2 ms 一次 SPI 读只有 ~25 µs，不影响 AD8232 采样。
