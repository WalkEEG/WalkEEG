# WalkEMG 前端 A（AD8232 改滤波）

日期：2026-11-01 · 分支：`WalkEMG`

## 目标
把 AD8232 从 ECG 带宽（0.5–16 Hz）改成 **EEG + EMG 共用带宽（约 0.05–500 Hz）**，采样率 2 kSPS（可调 500/1000/2000/4000）。

## 原理图元件（`01-hardware/history/AD-ND-S1.1.pdf`）

按 PDF 走线核对后，信号链是：

| 级 | 元件 | 原截止 |
|---|---|---|
| 高通 | **C4 / C6 = 0.33 µF**，配 R10~R14 = 10 MΩ | ≈ 0.05 Hz（诊断 ECG 档） |
| 低通（二阶 Sallen-Key） | **C1 = 1.5 nF**（R6/R7 节点 → OUT 反馈）、**C3 = 10 nF**（OPAMP+ → REFOUT 交流地），R6 = R7 = 1 MΩ | f₀ ≈ 41 Hz，主极点 15.9 Hz |
| （RLD 网络，不是信号滤波） | C2 1 nF + R5 360 kΩ | — |

原低通 15.9 Hz 会把 beta 和大部分 EMG 切掉，这是必须改的原因。

> 2026-11-02 修正：旧版本这里写的是“C4→15 nF、C3→330 pF”。那只适合纯 EMG，
> 且 C1 没有一起改，实际上限仍被 C1/R6/R7 的第二个极点压在 ~100 Hz。
> 现在要 **EEG + EMG 共用**，高通必须保持低频，所以改的是 **C1 + C3**。

## 改法（EEG + EMG 共用，0.05–500 Hz）

| 元件 | 原值 | 新值 | 说明 |
|---|---|---|---|
| **C1** | 1.5 nF | **100 pF**（C0G/NP0） | 二阶低通电容 1 |
| **C3** | 10 nF | **1 nF**（C0G/NP0） | 二阶低通电容 2 |

- 截止频率：`f₀ = 1 / (2π·√(R6·R7·C1·C3))` = 1/(2π×1 MΩ×√(100 pF×1 nF)) ≈ **503 Hz**。
- **C1、C3 必须一起改**：只改 C3，第二极点仍由 C1 决定，上限上不去；只改 C1，主极点仍在 15.9 Hz。
- **高通 C4 / C6 不动**（保持 0.33 µF，≈0.05 Hz）：EEG 的 0.5 Hz 和 EMG 的 20 Hz 都靠它。
- 如果以后只做 EMG、想压运动伪迹，再把 C4 改 15 nF（高通≈10.6 Hz），但会切掉 EEG 低频。
- 备选值：C1 120 pF + C3 820 pF ≈ 507 Hz（更接近原电容比值 6.7，Q 更接近原设计）；100 pF + 1 nF 的比值 10，阻尼略大，对包络检测无影响。
- 电容选 **C0G/NP0、5%**，不要 X7R。
- 上板前用万用表确认：C1 在 R6/R7 节点与 OUT 之间；C3 在 OPAMP+（pin 7）与 REFOUT（pin 8）之间。

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
