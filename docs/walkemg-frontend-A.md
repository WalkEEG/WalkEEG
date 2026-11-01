# WalkEMG 前端 A（AD8232 改滤波）

日期：2026-11-01 · 分支：`WalkEMG`

## 目标
把 AD8232 从 ECG 带宽（0.5–16 Hz）改成 EMG 带宽（10–500 Hz），采样率 2 kSPS（可调 500/1000/2000/4000）。

## 原理图元件（`01-hardware/history/AD-ND-S1.1.pdf`）
| 级 | 原元件 | 原截止 |
|---|---|---|
| 高通 | C4 0.33 µF + R9 1 MΩ | 0.48 Hz |
| 低通 | C3 10 nF + R7 1 MΩ | 15.9 Hz |
| 次级低通 | C2 1 nF + R5 360 kΩ | 442 Hz |
| 次级低通 | C1 1.5 nF + R8 100 kΩ | 1.06 kHz |

原低通 15.9 Hz 会把 beta 和大部分 EMG 切掉，这是必须改的原因。

## 改法（保留 1 MΩ 电阻，改电容）
| 级 | 改 | 新截止 |
|---|---|---|
| 高通 | C4 0.33 µF → **15 nF** | **10.6 Hz** |
| 低通 | C3 10 nF → **330 pF**（C0G/NP0） | **482 Hz** |

- 也可把 R9 改 47 kΩ、R7 改 33 kΩ，但会动直流/增益，优先改电容。
- C2/R5 的 442 Hz 是第二极点；对 EMG 包络够用。要更平可把 C2 改 680 pF（约 650 Hz）。
- 上板前用万用表确认 C4/R9、C3/R7 的实际连接。

## 固件
- `stream.h`：默认 `WALKEEG_DEFAULT_SAMPLE_HZ 2000`；运行时 `walkeeg_stream_set_rate()` / `get_rate()`。
- `stream.c`：运行时 `sample_hz`，定时器周期 `1e6/sample_hz` µs；支持 500/1000/2000/4000。
- `prj.conf`：`CONFIG_SYS_CLOCK_TICKS_PER_SEC=8000`；4 kHz = 250 µs = 2 tick。
- `main.c`：NUS RX 命令 `SET_RATE 2000\n`，返回 `OK 2000\n` 或 `ERR\n`。
- 当前不写 NVS：上电默认 2000 Hz，App 连接后发送一次。

## App
- BLE 增加 NUS RX 写入 `sendCommand("SET_RATE 2000\n")`。
- 采样率菜单：500 / 1000 / 2000 / 4000；切换时发送命令并重建分析器。
- `EmgAnalyzer`：20 Hz 高通、450 Hz 低通、整流、5 Hz 包络；输出 envelope / RMS / activation。
- `EmgPage`：包络条、激活百分比、采样率下拉、CSV 复制。
- EEG 分析仍用原始 CH0；relay 发送当前采样率配置。

## Relay / 网页
- App 连上 `/ingest` 后发送文本：`{"type":"config","rate":2000}`。
- 服务器保存 `sourceRateHz`，广播给 `/live`；网页时间轴按 rate × 5 s 计算。
- 二进制帧格式不变：`magic 0xA5 | ver | seq u16 | n u8 | ch[8][n] u16`；`t_ms` 只在 relay 信封里。

## 限制
- AD8232 12-bit、约 8 µV/LSB：EMG 包络可用，精细 EMG 波形不够；要产品级 EMG 换 ADS1293/ADS1299。
- 4 kSPS 时 SAADC oversampling 已降到 2；仍建议先用 2 kSPS 验证包络。
- 运动伪迹大；先静坐测握拳/放松，再走路。
