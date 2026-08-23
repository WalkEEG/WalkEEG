# WalkEEG nRF54L15-DK 移植研究（分支 `nRF54L15`）

> 本目录是 WalkEEG 项目从 nRF52840 / nRF52833 生态迁移到 **nRF54L15-DK** 的研究与实施方案。
> 研究日期：2026-08-23　·　研究人：nRF54L15 移植子会话

## 一、目标

1. 把 `02-firmware`（Zephyr / nRF Connect SDK 工程）从 nRF52840（青风开发板）移植到 **nRF54L15-DK**（Nordic PCA10156），
   保持现有功能不变：
   - BLE 广播 / 连接（NUS 服务，Nordic UART Service）
   - 500 Hz ECG 数据流（AD8232 → ADC 采样 → 8 通道帧 → BLE Notify）
   - 导联脱落检测（LO+/LO-）、SDN 控制、LED/按键、RTT 日志
2. 全程不破坏现有 nRF52840 / 其他板卡支持（新增内容以 overlay/分支隔离，旧逻辑保留回退路径）。
3. 产出研究文档 + 可落地的代码改动 + 构建/烧录说明。

## 二、现状（移植前确认）

| 项目 | 现状 |
|---|---|
| 仓库 | `/Users/mac/Documents/GitHub/WalkEEG`，remote `origin = https://github.com/WalkEEG/WalkEEG.git` |
| 基础分支 | `master`（已含 `feature/nrf52840-ble-flutter`：nRF52840 BLE 流式固件 + Flutter App） |
| 固件 | `02-firmware` = Zephyr / NCS 工程（CMakeLists.txt / Kconfig / Kconfig.sysbuild / prj.conf / boards/ / src/） |
| NCS 版本 | **NCS v3.2.1**（`.vscode/settings.json`：`nrf-connect.topdir: D:/ncs/v3.2.1`） |
| 默认板卡 | `nrf52840dk/nrf52840`（青风 nRF52840 板，P13 排针接 AD8232） |
| boards/ 目录 | 含 `nrf52840dk_nrf52840`（自定义）及从 NCS `peripheral_uart` 样例拷入的多板文件（nrf5340dk / nrf54h20dk / **nrf54l15dk** / nrf54lm20dk / nrf54lv10dk / thingy53 / uart1_usb_serial） |
| nRF52833 | **仓库中不存在任何 nrf52833 目标**（`boards/` 无、源码无引用）；用户提到的 52833 可能是早期 PCB 变体，需与硬件资料核对（详见 `01-research-notes.md`） |

`boards/` 下现有目标板一览：

```
nrf52840dk_nrf52840.{conf,overlay}      ← 实际使用（青风板 + DK 两用）
nrf5340dk_nrf5340_cpuapp.conf / cpuapp_ns.overlay
nrf54h20dk_nrf54h20_cpuapp.conf / cpurad.overlay
nrf54l15dk_nrf54l15_cpuapp_ns.overlay   ← nRF54L15 已有 overlay（分区布局），但缺 chosen/ADC/GPIO 适配
nrf54lm20dk_nrf54lm20{a,b}_cpuapp_ns.{conf,overlay}
nrf54lv10dk_nrf54lv10a_cpuapp_ns.overlay
thingy53_nrf5340_cpuapp.{conf,overlay}
uart1_usb_serial.{conf,overlay}         ← 附加 conf（52840 用外部 USB-TTL）
```

## 三、核心结论（摘要）

1. **nRF54L15 与 nRF52840 是"同生态、跨代"关系**：都是 Zephyr/NCS 工程、都用 Zephyr BT 协议栈 + Nordic SoftDevice Controller、驱动 API（UART/GPIO/ADC/GPIO 等）大体兼容。**不是从零重写**，工作量属"中等偏小"。
2. **必须用 `cpuapp_ns`（非安全域 + TF-M）目标**，NCS ≥ 2.7.0（推荐 v3.2.x 及以上，与现有工程一致），且**必须开 sysbuild**。仓库的 `Kconfig.sysbuild` 已满足。
3. **ADC 是最大差异点**：
   - nRF54L15 的 ADC 硬件是全新设计（Mouser 标称 14-bit），但 Zephyr 设备树兼容串仍是 `nordic,nrf-saadc`，驱动仍是 `adc_nrfx_saadc.c`（nrfx_saadc 为 nRF54L 提供 API 兼容层）。
   - nrfx 在 nRF54L 上使用 **"AIN 即引脚号"（AIN-as-pin）** 模式：`NRF_SAADC_INPUT_AIN0` 这类 nRF52 枚举宏**不存在**，改由 `nrfx_saadc_ain_get()` 用 AIN 索引查表映射到 P1 引脚。
   - 现有 `src/adc_sample.c` 硬编码 `NRF_SAADC_INPUT_AIN0` → **在 nRF54L15 上无法编译**（本次已改为 DT 驱动 + 索引宏，见 `03-code-changes.md`）。
   - nRF54L15 模拟输入 **AIN0–AIN7 全部位于 P1 口**（AIN0=P1.04 … AIN3=P1.07，AIN4=P1.11 … AIN7=P1.14），与 nRF52 的 P0.02(AIN0) 完全不同，**引脚全部要重排**。
4. **BLE 无需改代码**：SoC dtsi 已选 `zephyr,bt-hci = &bt_hci_sdc`（SoftDevice Controller），host 侧熵源走 TF-M PSA（`psa_rng`）；NUS/连接/MTU/DLE/2M PHY 等 API 全部通用。`main.c` 里 `CONFIG_SOC_SERIES_NRF54H || NRF54L` 的按键提示分支**早已预留**。
5. **本机（macOS）无 NCS 工具链**（无 west/cmake/ninja/nrfutil），无法实机构建；所有代码改动按"结构正确 + 关键引用已交叉核对"提交，标注 **待验证**，构建命令见 `02-migration-plan.md`。
6. 仓库 `boards/nrf54l15dk_nrf54l15_cpuapp_ns.overlay` 已存在且与 NCS v3.2.x 样例一致（RRAM 分区布局），本次在其上**追加**：`nordic,nus-uart = &uart20`、ADC 通道（AIN4 = P1.11）、walkeeg ECG 引脚节点、`adc/gpio1` status。

## 四、交付物

| 文件 | 内容 |
|---|---|
| `docs/nrf54l15-migration/README.md` | 本文件：总览、现状、结论摘要 |
| `docs/nrf54l15-migration/01-research-notes.md` | 芯片/DK 调研笔记：架构、外设差异表、BLE 栈、NCS 版本要求、DK 板载资源、引脚域 |
| `docs/nrf54l15-migration/02-migration-plan.md` | 分步移植计划（board → dts → prj.conf → 驱动 → BLE → 构建/烧录/验证），含风险点与待硬件确认项 |
| `docs/nrf54l15-migration/03-code-changes.md` | 具体代码改动清单（文件级 diff 说明） |
| `02-firmware/boards/nrf54l15dk_nrf54l15_cpuapp_ns.overlay` | 追加 NUS UART chosen / ADC / ECG 引脚 / 使能 adc+gpio |
| `02-firmware/boards/nrf52840dk_nrf52840.overlay` | 追加 `walkeeg,ecg-pins` 节点（青风板引脚），行为不变 |
| `02-firmware/dts/bindings/walkeeg/walkeeg,ecg-pins.yaml` | 新增设备树绑定（ADC 通道 + 导联 GPIO） |
| `02-firmware/src/adc_sample.c` / `.h` | ADC 采样改为 **DT 驱动**（`adc_dt_spec` + `gpio_dt_spec`），nRF52/nRF54L 双兼容，保留旧回退路径 |

## 五、下一步（需要用户/硬件参与）

1. 拿到 nRF54L15-DK（PCA10156）实机后：确认 **P1.11(AIN4) 接 AD8232 OUTPUT** 的接线方案与 LO+/LO-/SDN 引脚占用（本方案占用 SW0/LED3，可改用 UART RTS/CTS 引脚释放按键）。
2. 在 Windows（D:/ncs/v3.2.1）上用 `west build -b nrf54l15dk/nrf54l15/cpuapp_ns --sysbuild` 实测编译；重点核对 ADC `gain`（1/6 是否支持；内部基准电压）与 `oversampling`。
3. 验证 BLE 吞吐（2M PHY / DLE 下 Notify 速率）与 52840 的差异。
4. 确认"nrf52833"是否真的需要支持（当前仓库无此目标）。
