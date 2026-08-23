# 02 · nRF54L15-DK 分步移植计划

> 状态图例：✅ 已完成（本分支）｜⏳ 待实机验证 ｜🔧 需要硬件/用户决策
> 构建环境：Windows + NCS v3.2.1（`D:/ncs/v3.2.1`，VS Code + nRF Connect 扩展，现有工程即此环境）。

## 第 0 步（可选）· 确认 nRF52833 需求 🔧

仓库中不存在 nRF52833 目标。若确有 52833 硬件，请提供原理图；其移植方式与 52840 相同
（同一 SoC 系列，仅引脚/板文件不同），可复制 nrf52840dk 的 overlay 做法。**默认不处理**。

## 第 1 步 · board 层 ✅（本分支已完成基础版）

- 复用 NCS 自带板卡定义 `nrf54l15dk/nrf54l15/cpuapp_ns`（无需自建 board 目录）。
- 仓库 `boards/nrf54l15dk_nrf54l15_cpuapp_ns.overlay` 已存在（RRAM 分区布局，与 NCS peripheral_uart 样例一致）。
- 本次追加（详见 `03-code-changes.md`）：
  1. `chosen { nordic,nus-uart = &uart20; }` —— NUS 桥接 UART 指向 DK VCOM（P1.04/P1.05），否则 `main.c` 会 `#error`。
  2. `&adc { status = "okay"; ... channel@0 }` —— nRF54L15 的 adc 节点默认 disabled，必须显式使能；
     通道用 **AIN4 = P1.11**（DK 排针空闲脚）。
  3. `walkeeg-ecg` 引脚节点（LO+/LO-/SDN）+ 禁用被占用的 LED3/按键 SW0。
  4. `&gpio0/&gpio1/&gpio2 { status = "okay"; }`（显式使能，避免依赖板级默认）。

**风险点**：
- ⚠️ DK 排针可用模拟脚有限（AIN0–3 被 UART20 占用）。**P1.11(AIN4)/P1.12(AIN5) 是唯一"免费"模拟脚**。
- ⚠️ LO-/SDN 需占用 LED3(P1.14)/SW0(P1.13) 或 UART20 的 RTS/CTS(P1.06/P1.07)——选后者需在 overlay 里关流控并改 pinctrl。
- ⏳ 接线方案最终以实测为准（见第 5 步）。

## 第 2 步 · 设备树 / prj.conf ✅（基础版已完成）

- `prj.conf` **无需改动**（已核对：UART/GPIO/ADC(NRFX_SAADC)/BLE/NUS/RTT 日志/DK_LIBRARY 全部兼容 nRF54L15）。
- nRF54L15 不需要像 nrf5340 那样加 `CONFIG_BT_HOST_CRYPTO_PRNG=y / CONFIG_ENTROPY_BT_HCI=n`
  （熵源走 TF-M PSA `psa_rng`，板级 defconfig 已处理；NCS peripheral_uart 样例对 nrf54l15dk 无 .conf）。
- `Kconfig`：`ZMS default y if SOC_FLASH_NRF_RRAM` 自动命中（RRAM 设置存储）✅
- `Kconfig.sysbuild`：`MERGED_HEX_FILES default y if !SOC_SERIES_NRF54H` 对 54L15 生效（TF-M + app 合并 hex）✅

**风险点**：
- ⏳ 若后续需要 DFU/加密启动/多 slot，才需要动 sysbuild 配置；当前"单 slot + TF-M"够用。
- ⚠️ `CONFIG_BT_CTLR_*` 系列在 SDC 下多为无效/冗余配置，保留无害；实机吞吐调优时再评估。

## 第 3 步 · 驱动适配 ✅（代码已改，待编译验证）

改动集中在 `src/adc_sample.c`（唯一存在编译障碍的文件）：

1. **编译修复**：`NRF_SAADC_INPUT_AIN0`（nrfx 枚举，nRF54L 不存在）→ `<zephyr/dt-bindings/adc/nrf-saadc.h>` 的 `NRF_SAADC_AIN0`（索引值，两代通用）。
2. **引脚可配置化**：ADC 通道（gain/ref/输入脚）与 LO+/LO-/SDN 全部改由 board overlay 的
   `walkeeg,ecg-pins` 节点提供（`adc_dt_spec` + `gpio_dt_spec`）；
   无该节点的板卡（nrf5340dk/thingy53 等）自动回退到旧硬编码（青风板 P1.13/15/14 + AIN0），**行为不变**。
3. 新增绑定文件 `02-firmware/dts/bindings/walkeeg/walkeeg,ecg-pins.yaml`。

**风险点**：
- ⏳ 增益 `ADC_GAIN_1_6` 在 nRF54L15 是否支持未确认（nrfx 驱动按 `NRF_SAADC_HAS_GAIN_1_6` 条件编译）；
  若编译/运行报错，把 nrf54l15dk overlay 的 `zephyr,gain` 改为 `"ADC_GAIN_1_4"` 并复核满量程。
- ⏳ 内部基准电压值（52840=0.6 V）待查 PS；换算公式：满量程 = Vref / gain。
- ⏳ 14-bit 分辨率与 oversampling 行为待实机验证。

## 第 4 步 · BLE 层 ✅（零改动）

- 协议栈：Zephyr BT host + SDC（`bt_hci_sdc`），SoC dtsi 已配好，应用零改动。
- `main.c` 中按键配对提示已含 `CONFIG_SOC_SERIES_NRF54L` 分支（按 SW0/SW1）。
- ⚠️ 注意：本方案禁用了 SW0（P1.13 用作 SDN），若需配对确认按键，请改用"UART RTS/CTS 释放方案"或改 SDN 引脚。

**风险点**：
- ⏳ 高吞吐 Notify（N=20 帧/包，2M PHY + DLE）在 54L15 上需实机测速（预期不低于 52840）。
- ⏳ TF-M/PSA 首次启动比 52840 多了 SPM 初始化，`bt_enable` 前时序无影响，但 RTT 日志顺序会变化。

## 第 5 步 · 构建 / 烧录 / 验证 ⏳

```bash
# 在 Windows（NCS v3.2.1 环境）02-firmware 目录执行：
west build -b nrf54l15dk/nrf54l15/cpuapp_ns --sysbuild -d build-nrf54l15
west flash -d build-nrf54l15            # J-Link OB 自动识别 PCA10156
# 日志：SEGGER RTT Viewer（CONFIG_LOG_BACKEND_RTT 已开）
# NUS VCOM：nRF Connect / PuTTY 打开 DK 的 VCOM（UART20 = P1.04/P1.05）
```

验证清单：
1. RTT 日志出现 "Bluetooth initialized"、"Advertising successfully started"、LED2 秒闪。
2. 手机 nRF Connect 扫描到 "WalkEEG"，连接后 MTU 协商 ≥ 500，NUS Notify 使能后收到 ECG 帧
   （帧头 0xA5 01 + seq + N + flags，CH0 = ADC 值）。
3. AD8232 接 P1.11(AIN4)，导联脱落后 flags 位 0/1 变化。
4. VCOM 串口 115200 可看到 "UART heartbeat"（每 30 s）与 BLE 连接横幅。

## 第 6 步 · 性能 / 功耗调优（后续）

- 吞吐：连接参数（`CONFIG_BT_PERIPHERAL_PREF_*` 已是 7.5–15 ms）若不够再调。
- 功耗：nPM1300 + 电流测量脚；流式传输时保持 2M PHY + DLE；空闲时考虑 `CONFIG_PM`（默认未开，保持与 52840 一致）。
- RRAM 设置存储（ZMS）已启用，验证 `settings_load()` 正常。

## 风险与待决策清单（汇总）

| # | 事项 | 类型 | 说明 |
|---|---|---|---|
| 1 | ADC gain/ref/分辨率 | 硬件确认 | 查 PS；不行就换 `ADC_GAIN_1_4` |
| 2 | AIN4=P1.11 接线 | 硬件确认 | AD8232 OUTPUT → P1.11；LO+/LO-/SDN 占用 SW0/LED3 或 UART RTS/CTS |
| 3 | SW0 被占 → 配对按键缺一个 | 用户决策 | 接受 / 换脚 / 关闭安全配对（`CONFIG_BT_NUS_SECURITY_ENABLED=n`） |
| 4 | 是否要 nRF52833 支持 | 用户决策 | 仓库无此目标 |
| 5 | 实机编译/烧录 | 待验证 | 本机无 NCS 工具链 |
| 6 | 2M PHY/DLE 吞吐 | 待验证 | 预期 ≥ 52840 |
