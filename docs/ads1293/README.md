# WalkEEG × TI ADS1293 接口说明

本目录记录 WalkEEG 固件（02-firmware）新增 **TI ADS1293** 三通道 24-bit ECG 模拟前端（AFE）的接口方案。
ADS1293 与原有 AD8232 方案**并行保留**：AD8232 的引脚（AIN0=P0.02、LO+=P1.13、LO-=P1.15、SDN=P1.14）
与 UART（P0.12/P0.13）**一律不动**，ADS1293 使用全新引脚，通过 Kconfig 一键切换数据源。

## 1. 为什么加 ADS1293

| 对比 | AD8232（现有） | ADS1293（新增） |
|---|---|---|
| 通道数 | 1（单导联） | 3（Lead I/II/III 同时） |
| 分辨率 | 12-bit SAADC | 24-bit ΔΣ |
| 采样率 | 500 Hz | 533 Hz（可配 25~6400 sps） |
| 导联脱落 | 外接 LO+/LO- 比较器 | 内置 LOD + 交流/直流检测 |
| 右腿驱动 | 无 | 内置 RLD 放大器（接 IN4） |
| 接口 | 模拟（SAADC） | SPI（mode 0，最高 20 MHz） |

## 2. 硬件接线（nRF52840-DK / 青风板 P13 排针）

ADS1293 全部走 **SPI1**，引脚选在 P1 组，与 AD8232/UART 零冲突：

| 功能 | nRF52840 引脚 | ADS1293 引脚 | 说明 |
|---|---|---|---|
| SCLK | P1.00 | SCLK | SPIM1 SCK |
| MOSI | P1.01 | SDI | SPIM1 MOSI |
| MISO | P1.02 | SDO | SPIM1 MISO |
| CS | P1.03 | CSB | GPIO 片选（低有效） |
| DRDY | P1.04 | DRDYB | 数据就绪中断（低有效，下降沿） |
| RESET | P1.05 | RSTB | 可选硬复位（低有效） |
| — | 3.3V | VDD / VDDIO | VDD 2.7~5.5V，VDDIO 1.65~3.6V |
| — | GND | VSS | 共地 |
| — | — | CVREF | 1 µF 低 ESR 电容到地 |
| — | — | RLDREF | 0.1 µF 电容到地 |
| 电极 RA | — | IN1 | 右臂 |
| 电极 LA | — | IN2 | 左臂 |
| 电极 LL | — | IN3 | 左腿 |
| 电极 RL | — | IN4 | 右腿（RLD 输出） |

**电极-导联映射**（按 TI 3-Lead 官方参考设计）：
- Lead I = LA − RA = IN2 − IN1（CH1）
- Lead II = LL − RA = IN3 − IN1（CH2）
- Lead III = LL − LA = IN3 − IN2（CH3）

> 时钟：模块需带 4.096 MHz 晶振（XTAL1/XTAL2），或从 CLK 脚外部馈入 409.6 kHz 时钟。
> 常见 ADS1293 成品模块（如 TI 官方 EVM、国产模块）已集成晶振，直接可用。

## 3. 固件改动清单（相对 master）

| 文件 | 改动 |
|---|---|
| `02-firmware/src/ads1293.c` | 新增：SPI 驱动 + 寄存器配置 + DRDY 中断 + 数据读取 |
| `02-firmware/src/ads1293.h` | 新增：API 与引脚说明，`WALKEEG_ADS1293_AVAILABLE` 编译开关 |
| `02-firmware/dts/bindings/ti/ti,ads1293.yaml` | 新增：设备树绑定 |
| `02-firmware/boards/nrf52840dk_nrf52840.overlay` | 新增 SPI1 节点 + ads1293 子节点（AD8232 部分未动） |
| `02-firmware/src/stream.c` | sampler 线程按编译开关选数据源：ADS1293 → CH0-2 三导联；AD8232 → 原逻辑 |
| `02-firmware/src/main.c` | 初始化按开关选 `walkeeg_ads1293_init()` / `walkeeg_adc_init()` |
| `02-firmware/Kconfig` | 新增 `CONFIG_WALKEEG_USE_ADS1293`（默认 y） |
| `02-firmware/prj.conf` | 新增 `CONFIG_SPI=y`、`CONFIG_NRFX_SPIM=y` |
| `02-firmware/CMakeLists.txt` | 新增 `src/ads1293.c` |

## 4. ADS1293 寄存器配置（533 sps，3 导联）

| 寄存器 | 地址 | 写入值 | 含义 |
|---|---|---|---|
| CONFIG | 0x00 | 0x00 → 0x01 | 先退 standby，最后 START_CON=1 |
| FLEX_CH1_CN | 0x01 | 0x11 | CH1: POS=IN2, NEG=IN1（Lead I） |
| FLEX_CH2_CN | 0x02 | 0x19 | CH2: POS=IN3, NEG=IN1（Lead II） |
| FLEX_CH3_CN | 0x03 | 0x1A | CH3: POS=IN3, NEG=IN2（Lead III） |
| CMDET_EN | 0x0A | 0x07 | 共模检测使能 IN1/2/3 |
| RLD_CN | 0x0C | 0x04 | RLD 放大器输出接 IN4 |
| REF_CN | 0x11 | 0x00 | 内部 2.4V 基准开启 |
| OSC_CN | 0x12 | 0x00 → 0x04 | 晶振起振后 STRTCLK=1 |
| AFE_RES | 0x13 | 0x00 | FS=102.4 kHz，低功耗模式 |
| AFE_SHDN_CN | 0x14 | 0x00 | 三通道全开 |
| R2_RATE | 0x21 | 0x01 | R2=4 |
| R3_RATE_CH1/2/3 | 0x22/23/24 | 0x08 | R3=12 |
| R1_RATE | 0x25 | 0x00 | R1=4（标准 PACE 速率） |
| DRDYB_SRC | 0x27 | 0x08 | DRDYB 由 CH1 ECG 驱动 |
| CH_CNFG | 0x2F | 0x70 | 循环回读使能 E3+E2+E1 |

**ODR 计算**：`fODR = fS / (R1×R2×R3) = 102400 / (4×4×12) = 533.3 Hz`，BW ≈ 105 Hz。

**数据读取**：DRDYB 下降沿 → GPIO 中断 → 信号量；`spi_transceive` 发 0xD0（读 0x50）后
连续收 9 字节 = CH1/2/3 各 3 字节 24-bit，**MSB 在前，offset-binary**（0V 差分输入 = 0x400000）。
stream 层转 int16：`(raw - 0x400000) >> 8`，中心化到 0，量程 ±0x8000。

## 5. 构建与切换

```bash
# 默认（master 配置）：已启用 ADS1293
west build -b nrf52840dk_nrf52840 --sysbuild   # 或直接 west build -b nrf52840dk_nrf52840

# 切回 AD8232（SAADC 单通道 + 锯齿波测试信号）
west build -b nrf52840dk_nrf52840 -DCONFIG_WALKEEG_USE_ADS1293=n
```

烧录后日志（RTT）应看到：
```
walkeeg_ads1293: ADS1293 REVID=0x01 (SPI OK)
walkeeg_ads1293: ADS1293 init OK (3-lead ECG, 533 sps, DRDY P1.4)
```

若看到 `Unexpected REVID` 或 `SPI device not ready`：检查 SCLK/MOSI/MISO/CS 接线、VDD/VDDIO 供电、CVREF 电容。

## 6. BLE 帧格式（不变）

保持 8 通道 int16 帧（App 兼容）：
- ADS1293 模式：CH0=Lead I，CH1=Lead II，CH2=Lead III，CH3-7=0；flags bit0=IN1 脱落状态（1=接上），bit1=IN2
- AD8232 模式：CH0=AD8232，CH1=锯齿波测试，CH2-7=0（原逻辑）

## 7. 待办 / 后续优化

- [ ] 实机验证 SPI 时序与 REVID（本机无 NCS 工具链，未编译验证）
- [ ] 导联脱落 LOD 完整配置（当前只读 ERROR_LOD 状态位，未开 LOD 激励电流）
- [ ] 采样率对齐：533 Hz vs 帧头 500 Hz 标记（App 端如需严格 500Hz 可改用 400/800Hz 档位）
- [ ] nRF54L15 移植时在对应 overlay 加 ads1293 节点即可复用本驱动
