# 01 · nRF54L15 芯片 / DK 调研笔记（对照 nRF52840 / nRF52833）

> 信息来源：Nordic 产品页 / Mouser 商品页 / nRF54L15 产品规格（PS）/ 博客实测文章 /
> Zephyr-NCS 源码（`sdk-zephyr`、`sdk-nrf`、nrfx hal，GitHub API 拉取核对）。
> 结论以 NCS v3.2.1（现有工程版本）为准，标注"待验证"处需实机确认。

## 1. 芯片级对比表

| 项目 | nRF52840 | nRF52833 | **nRF54L15** |
|---|---|---|---|
| 内核 | Cortex-M4F @ 64 MHz | Cortex-M4F @ 64 MHz | **Cortex-M33 @ 128 MHz**（应用核）＋ 128 MHz RISC-V 协处理器（VPR/FLPR 域） |
| 架构 | 单核 | 单核 | **多电源域**：MCU 域（0x 外设）、PERI 域（20/21/22 外设）、LP 域（30/31 外设）、RADIO 域；TrustZone（SPM/TF-M） |
| Flash | 1 MB（XIP） | 512 KB | **1.5 MB MRAM**（标称；Zephyr 分区可用 1524 KB）＋ **256 KB RRAM**（非易失 RAM，可跑代码/存设置） |
| RAM | 256 KB | 128 KB | 256 KB SRAM（应用核） |
| BLE | 5.0，2M PHY | 5.0，2M PHY | **5.4**，2M PHY、LE Audio 硬件能力、802.15.4（Thread/Zigbee）、私有 2.4G 最高 4 Mbps |
| 发射功率 | +8 dBm | +4 dBm | +8 dBm |
| ADC | SAADC 12-bit | SAADC 12-bit | **新 ADC（Mouser 标 14-bit）**，DT 兼容串仍为 `nordic,nrf-saadc`，nrfx 提供 SAADC API 兼容层；输入 **AIN0–AIN7 全在 P1 口** |
| UART | UARTE ×2 | UARTE ×2 | UARTE20/21/22（PERI）、UARTE00（MCU 高速域）、UART30（LP 域）；DK 上 UART30 被 TF-M 占用 |
| SPI/TWI | SPIM/SPIS/TWIM ×3 | 同左 | SPIM00（高速）/SPIM20-22、TWIM20-22 等（数量略减，编号带域） |
| PDM/I2S | PDM ×1、无 I2S | 同左 | **PDM 有**（与 DMIC 相关测试在 NCS 存在）、**I2S ×1**（i2s20） |
| PWM | ×3（0/1/2） | ×3 | ×3（pwm20/21/22，**只能在 P1 口输出**） |
| 定时器 | TIMER ×5 | ×5 | TIMER ×6+、**GRTC（全局 RTC，跨域）**、WDT ×2（wdt30/31） |
| GPIOTE | 8 通道 | 8 通道 | gpiote20（P1）、gpiote30（P0）；**P2 不支持 GPIOTE/唤醒** |
| 加密 | CC310（CRYPTOCELL） | CC310 | **CRACEN + ARMV8-M TrustZone**（安全域提供 TF-M/PSA），不再有 SoftDevice/CC310 |
| USB | USB 2.0 FS | 无 | **无 USB 外设**（DK 的 USB 走板载 nRF5340 J-Link / 接口 MCU 的 VCOM） |
| 密码/安全启动 | SoftDevice + 可选 | 同左 | TF-M（SPM）强制推荐；`cpuapp_ns` 目标 + sysbuild |
| 功耗 | 广播 ~5 mA 级 | 同左 | 显著更低（nPM1300 配套；目标值需实机测） |

> 注：Mouser 页面写 "5 个 SPI/TWI/UART" 与 "2 个 PDM" 系营销口径；以 PS 外设实例列表为准
> （本文按 NCS dtsi 中的实际节点整理：`pwm20-22`、`i2s20`、`qdec20/21`、`nfct`、`temp`、`grtc` 等）。

## 2. 电源域 / 引脚域（对移植最关键的知识）

来源：nRF54L15 PS + TedLee《nRF54L15 的引脚说明》实测文章。

| 域 | 主频 | 外设编号 | GPIO 口 | 特点 |
|---|---|---|---|---|
| **MCU 域** | 128 MHz | UARTE00 / SPIM00 等 | **P2**（11 脚，最快 64 Mbps） | 高速外设；P2 **无 GPIOTE、无唤醒、无中断检测**；FLPR 专用脚在 P2 |
| **PERI 域** | 16 MHz | 20/21/22（UART20、SPI20、TWI20、PWM20…） | **P1**（15 脚） | 大多数外设；PWM 只在 P1；**AIN0–AIN7 在 P1**；NFC/复位/多天线控制脚也在 P1 |
| **LP 域** | 16 MHz | 30/31（UART30、SPIS30、WDT30/31、GRTC…） | **P0**（QFN48 仅 5 脚） | 低功耗唤醒；GPIOTE30；GRTC 时钟/PWM 输出专用脚 P0.03/P0.04 |
| **RADIO 域** | 32 MHz | 无线电/协议栈 | 无 | BLE/802.15.4/私有 2.4G |

**移植要点**：
- 外设与 GPIO 口**强绑定**：选 UART20 就必须用 P1 的引脚；GRTC 输出必须用 P0 专用脚；PWM 只能 P1。
- nRF54L15（QFN48）实际引脚：P0 只有 5 个、P1 有 15 个（P1.00–P1.14）、P2 有 11 个。**nRF52840 的 P1.15 不存在**（旧代码里 LO- = P1.15 必须改）。
- 交叉域使用外设会导致功耗升高且部分功能不可用（例如 P2 引脚不能做 GPIO 中断/唤醒）。

## 3. ADC（SAADC 兼容层）细节 —— 本次移植的核心差异

**结论先行**：
- Zephyr 设备树节点：`adc: adc@d5000`，`compatible = "nordic,nrf-saadc"`（与 nRF52 相同！）
- Zephyr 驱动：`drivers/adc/adc_nrfx_saadc.c`（同一驱动，nrfx_saadc 提供 nRF54L 实现）
- nrfx 在 nRF54L 上是 **"AIN-as-pin"** 模式：`nrf_saadc_input_t` 变成 uint32 引脚号，`NRF_SAADC_INPUT_AIN0..7` **枚举宏不存在**；Zephyr 驱动把 DT 的 AIN 索引（`NRF_SAADC_AINx`，值 0–7）原样传给 nrfx，由 `nrfx_saadc_ain_get()` 查表映射到 P1 引脚号。
- **旧代码 `NRF_SAADC_INPUT_AIN0` 在 nRF54L15 编译不过** → 已改为 `<zephyr/dt-bindings/adc/nrf-saadc.h>` 的 `NRF_SAADC_AIN0`（索引值，两代芯片通用）。

**AIN → 引脚映射（nRF54L15，依据 NCS 样例注释交叉验证）**：

| AIN | 引脚 | 说明 |
|---|---|---|
| AIN0 | P1.04 | DK 上 = UART20 TX（VCOM）⚠️ |
| AIN1 | P1.05 | DK 上 = UART20 RX ⚠️ |
| AIN2 | P1.06 | DK 上 = UART20 RTS ⚠️ |
| AIN3 | P1.07 | DK 上 = UART20 CTS ⚠️ |
| **AIN4** | **P1.11** | **DK 排针空闲 ✅（本方案选它）** |
| AIN5 | P1.12 | DK 排针空闲 ✅ |
| AIN6 | P1.13 | DK 上 = SW0（按键）⚠️ |
| AIN7 | P1.14 | DK 上 = LED3 ⚠️ |

依据：`samples/drivers/adc/adc_dt/boards/nrf54l15dk_nrf54l15_cpuapp.overlay`
（`AIN4 /* P1.11 */`、`AIN2 /* P1.06 */`、`AIN6 /* P1.13 */`、`AIN7 /* P1.14 */`）与
`tests/drivers/adc/adc_latency`（"P1.06 (AIN2)"）。

**增益/基准（待实机验证）**：
- nRF54L15 内部基准 ≠ nRF52840 的 0.6 V（推测 0.9 V 级），增益档位有增删（NCS 测试里出现 `ADC_GAIN_2_3`、`ADC_GAIN_1_4` 等新档；`1/6` 是否支持待确认）。
- 建议 nRF54L15-DK 上先用 **gain 1/4 + 内部基准**（若内部基准 0.9 V，满量程 ≈ 3.6 V，与 52840 的 0.6 V×1/6 相当，AD8232 输出 0–3.3 V 兼容），实机校准后再定。
- 分辨率：10/12-bit 已确认可用（样例用 `zephyr,resolution = <10>/<12>`）；14-bit 是否对应用开放待确认。
- oversampling：NCS 样例使用 `zephyr,oversampling = <8>` 于 nRF54L15 ✅（旧代码 C 侧 `oversampling = 4` 保留）。

## 4. BLE 协议栈变化

| 项 | nRF52840 / nRF52833（NCS） | nRF54L15（NCS） |
|---|---|---|
| 控制器 | SoftDevice Controller（SDC，单核内） | **SDC（`bt_hci_sdc`）**，SoC dtsi 已选 `zephyr,bt-hci = &bt_hci_sdc`；与 host 走共享内存 HCI |
| Host | Zephyr BT 协议栈 | 同（`CONFIG_BT=y` 等全部沿用） |
| 熵源 | HCI/硬件 RNG | **TF-M PSA RNG**（`zephyr,entropy = &psa_rng`，`/delete-node/ rng`）——`cpuapp_ns` 目标自动处理 |
| 安全 | CC310 / SMP | SMP + CRACEN（安全域） |
| SoftDevice API | 废弃 | 无（NCS 早已是 Zephyr 栈） |
| 2M PHY / DLE | 支持 | 支持（SDC 自动协商；host 侧 `bt_conn_le_data_len_update` / `bt_conn_le_phy_update` API 不变） |

**对现有代码的影响**：`main.c` / `stream.c` 的 BLE 部分**零改动**。
`prj.conf` 中 `CONFIG_BT_CTLR_*`（如 `CONFIG_BT_CTLR_DATA_LENGTH_MAX=251`、`CONFIG_BT_CTLR_PHY_2M=y`）
在 SDC 下本来就不是生效关键（NCS 的 SDC 由自己的配置管理），保留无害；如需精确控制可在实机验证阶段调整。

## 5. nRF54L15-DK（PCA10156）板载资源

来源：Mouser 商品页 + 实测文章 + NCS `nrf54l15dk_common.dtsi`。

- **J-Link OB** 由板载 **nRF5340** 实现（Type-C USB）；2 路 VCOM（UART20 = P1.04/P1.05 等）
- 电源：**nPM1300 PMIC**（USB 输入，1.8–3.3 V 可编程）
- **外挂 8 MB（64 Mbit）MXIC QSPI Flash**（nRF54L15 无内部 QSPI 控制器，用 FLPR + P2 模拟，即 "MSPI/SQSPI"）
- 2.4 GHz 天线 + SWF 射频座 + NFC 天线
- 4× LED（led0=P2.09、led1=P1.10、led2=P2.07、led3=P1.14）+ 4× 按键（sw0=P1.13、sw1=P1.09、sw2=P1.08、sw3=P0.04）
- **扩展排针 = "PORT P1"**（P1.04–P1.14 引出，**无 Arduino 接口**，与 nRF52840-DK/52833-DK 的 Arduino 头不同！）
- 功耗测量引脚、Board Configurator（nRF Connect for Desktop）支持
- 可仿真 nRF54L10 / nRF54L05（软件后续支持）

**与 nRF52840-DK / nRF52833-DK 的关键差异**：
1. **没有 Arduino 接口**，IO 从 "PORT P1" 排针出（P1.04–P1.14）。
2. USB 不是 SoC 的 USB 外设，是 J-Link 接口 MCU 提供的 VCOM；SoC 本身**无 USB**。
3. LED/按键引脚完全不同（52840-DK：LED=P0.13–16，按键=P0.11–14；54L15-DK：见上表）。
4. 无 52833 对应的 DK；52833 一般用 nRF52833-DK（PCA10100），与 52840-DK 引脚布局接近但芯片不同。

## 6. NCS 版本要求

- nRF54L 系列 SoC / nrf54l15dk 板卡支持起始版本：**NCS ≥ 2.7.0**（Zephyr 3.7 内核引入 nRF54L）。
- **sysbuild 必开**（TF-M/SPM 多镜像）；仓库 `Kconfig.sysbuild` 已满足。
- 本工程在用 **NCS v3.2.1** → 完全满足，**无需升级 SDK**（建议保持 v3.2.1 以复用现有构建环境）。
- 板卡目标（v3.2.x 写法）：`west build -b nrf54l15dk/nrf54l15/cpuapp_ns`（overlay 文件名 `boards/nrf54l15dk_nrf54l15_cpuapp_ns.overlay` 与之一致）。
  新版本（v3.4+）也接受 `nrf54l15dk/nrf54l15/cpuapp/ns` 写法。
- 烧录：`west flash`（J-Link OB）或 nRF Connect for Desktop / `nrfutil device program`。

## 7. 关于"nRF52833"

- 全仓库检索（含 KiCad 工程、docs、固件、Flutter/PC/MATLAB）：**没有任何 nrf52833 目标或引用**。
- `boards/` 只有 nrf52840dk 及 NCS 样例带的多板文件。
- 结论：要么用户记错了，要么 52833 是未进仓库的早期硬件；**移植范围按 nRF52840 → nRF54L15 处理**，若确有 52833 硬件，需用户提供原理图确认引脚后另行加板（工作量与 52840 相同，见 `02-migration-plan.md` 第 0 步）。

## 8. 参考资料

- Mouser：https://www.mouser.cn/zh/new/nordic-semiconductor/nordic-nrf54l15-dev-kit/
- Nordic 产品页：https://www.nordicsemi.com/Products/nRF54L15
- PS：https://docs.nordicsemi.com/bundle/ps_nrf54l15 （被 Cloudflare 拦，可通过 Bing 快照/博客转引）
- 实测文章：《从零开始手把手教你写一个基于 nRF54L15 的 BLE 工程》 https://www.cnblogs.com/HannibalWang/p/18603044
- 引脚说明：《【Nordic随笔】nRF54L15 的引脚说明》 https://www.cnblogs.com/TedLeeX/p/19007753
- 引脚规划工具：https://pinplanner.app（Nordic 原厂 Pin Planner，规划新 PCB 引脚必用）
- NCS 源码交叉核对：`sdk-zephyr`（boards/nordic/nrf54l15dk、dts/vendor/nordic/nrf54l15*.dtsi、drivers/adc/adc_nrfx_saadc.c）、`sdk-nrf`（samples/bluetooth/peripheral_uart/boards、samples/drivers/adc/adc_dt/boards）、nrfx（drivers/src/nrfx_saadc.c、helpers/nrfx_analog_common.h）
