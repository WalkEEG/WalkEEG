# 03 · 具体代码改动清单

> 本分支相对 `master` 的全部改动。所有改动保持 nRF52840（及其他既有板卡）行为不变。

## 1. `02-firmware/boards/nrf54l15dk_nrf54l15_cpuapp_ns.overlay`（修改）

在原 RRAM 分区布局基础上**追加**（分区部分未动）：

```dts
/ {
	chosen {
		/* NUS 桥接 UART 指向 DK 的 VCOM（UART20 = P1.04/P1.05）。
		 * 没有该 chosen 时 main.c 会编译报错（#error）。 */
		nordic,nus-uart = &uart20;
	};

	/* AD8232 ECG 引脚（DK 扩展排针 PORT P1）——
	 * 方案 A（默认，占用 SW0/LED3）：
	 *   OUTPUT -> P1.11 (AIN4)，LO+ -> P1.12，LO- -> P1.14 (LED3)，SDN -> P1.13 (SW0)
	 * 方案 B（保留按键/LED）：LO-/SDN 改到 P1.06/P1.07，需在 &uart20 去掉 RTS/CTS
	 * 接线待实机确认。 */
	walkeeg_ecg: walkeeg-ecg {
		compatible = "walkeeg,ecg-pins";
		io-channels = <&adc 0>;
		lo-plus-gpios  = <&gpio1 12 GPIO_PULL_UP>;      /* P1.12 */
		lo-minus-gpios = <&gpio1 14 GPIO_PULL_UP>;      /* P1.14 (LED3) */
		sdn-gpios      = <&gpio1 13 GPIO_ACTIVE_HIGH>;  /* P1.13 (SW0) */
	};
};

&adc {
	status = "okay";   /* nRF54L15 的 adc 节点默认 disabled，必须显式使能 */
	#address-cells = <1>;
	#size-cells = <0>;

	/* AD8232 ECG 通道：AIN4 = P1.11。
	 * gain 1/4 + 内部基准 ≈ 3.6 V 满量程（若内部基准 0.9 V，与 52840 的 0.6V×1/6 相当）；
	 * 若 1/4 不可用或满量程不符，按 PS 校准后修改。 */
	channel@0 {
		reg = <0>;
		zephyr,gain = "ADC_GAIN_1_4";
		zephyr,reference = "ADC_REF_INTERNAL";
		zephyr,acquisition-time = <ADC_ACQ_TIME_DEFAULT>;
		zephyr,input-positive = <NRF_SAADC_AIN4>; /* P1.11 */
	};
};

/* 显式使能 GPIO 口（nRF54L15 默认 disabled；板上 LED/按键/排针都要用） */
&gpio0 { status = "okay"; };
&gpio1 { status = "okay"; };
&gpio2 { status = "okay"; };

/* 被 ECG 占用：LED3 = P1.14（LO-），SW0 = P1.13（SDN） */
&led3 {
	status = "disabled";
};

&button0 {
	status = "disabled";
};
```

> 说明：`&adc` 的 `zephyr,input-positive = <NRF_SAADC_AIN4>` 使用 **AIN 索引**（非引脚号），
> nrfx 在 nRF54L 上自动映射到 P1.11；`adc_sample.c` 通过 `adc_dt_spec` 读取该配置。

## 2. `02-firmware/boards/nrf52840dk_nrf52840.overlay`（修改，行为不变）

追加 walkeeg ECG 引脚节点（青风板实际接线，与旧代码硬编码一致）：

```dts
/ {
	/* AD8232 引脚（青风 nRF52840 板，P13 排针）：
	 * OUTPUT -> P0.02 (AIN0)，LO+ -> P1.13，LO- -> P1.15，SDN -> P1.14 */
	walkeeg_ecg: walkeeg-ecg {
		compatible = "walkeeg,ecg-pins";
		io-channels = <&adc 0>;
		lo-plus-gpios  = <&gpio1 13 GPIO_PULL_UP>;
		lo-minus-gpios = <&gpio1 15 GPIO_PULL_UP>;
		sdn-gpios      = <&gpio1 14 GPIO_ACTIVE_HIGH>;
	};
};
```

原有的 `&adc channel@0`（AIN0/P0.02、gain 1/6）**保留**（adc_dt_spec 会读取它）。

## 3. `02-firmware/dts/bindings/walkeeg/walkeeg,ecg-pins.yaml`（新增）

```yaml
description: WalkEEG AD8232 ECG 连接引脚（ADC 通道 + 导联脱落 GPIO + SDN）

compatible: "walkeeg,ecg-pins"

properties:
  io-channels:
    type: phandle-array
    required: true
    description: 指向 &adc 及其通道序号（channel@N 定义 gain/ref/输入脚）

  lo-plus-gpios:
    type: phandle-array
    required: true
    description: LO+ 导联检测输入（上拉）

  lo-minus-gpios:
    type: phandle-array
    required: true
    description: LO- 导联检测输入（上拉）

  sdn-gpios:
    type: phandle-array
    required: true
    description: SDN 关断控制（输出高 = 使能 AD8232）
```

## 4. `02-firmware/src/adc_sample.c`（修改）

- 删除 `#include <nrfx_saadc.h>`，改为 `#include <zephyr/dt-bindings/adc/nrf-saadc.h>`。
- **优先走 DT 配置**（`walkeeg,ecg-pins` 节点存在时）：
  - `static const struct adc_dt_spec adc_spec = ADC_DT_SPEC_GET(ECG_PINS_NODE);`
  - LO+/LO-/SDN 用 `gpio_dt_spec` + `gpio_pin_configure_dt()`。
  - 采样序列保留：12-bit、oversampling 4、单通道（CH0）。
- **回退路径**（节点不存在，nrf5340dk/thingy53 等未适配板卡）：与旧代码完全一致
  （硬编码 P1.13/P1.15/P1.14 + `NRF_SAADC_AIN0` + gain 1/6 + 内部基准）。
- 对外 API `walkeeg_adc_init()` / `walkeeg_adc_read()` 不变 → `stream.c` / `main.c` 零改动。

关键片段（结构示意，完整代码见文件）：

```c
#if DT_HAS_COMPAT_STATUS_OKAY(walkeeg_ecg_pins)
#define ECG_PINS_NODE DT_COMPAT_GET_OKAY(walkeeg_ecg_pins)
static const struct adc_dt_spec adc_spec = ADC_DT_SPEC_GET(ECG_PINS_NODE);
static const struct gpio_dt_spec lo_plus_gpio  = GPIO_DT_SPEC_GET(ECG_PINS_NODE, lo_plus_gpios);
static const struct gpio_dt_spec lo_minus_gpio = GPIO_DT_SPEC_GET(ECG_PINS_NODE, lo_minus_gpios);
static const struct gpio_dt_spec sdn_gpio      = GPIO_DT_SPEC_GET(ECG_PINS_NODE, sdn_gpios);
/* init: adc_channel_setup_dt(&adc_spec); gpio_pin_configure_dt(...) */
#else
/* 旧回退路径（见上） */
#endif
```

## 5. `02-firmware/src/adc_sample.h`（修改）

仅更新注释（引脚图说明：nRF52840 青风板 vs nRF54L15-DK 方案），API 不变。

## 6. 未改动文件（说明）

- `src/main.c`、`src/stream.c/h`：无需改动（BLE/NUS/流线程逻辑与 SoC 无关）。
- `prj.conf`：无需改动（见 `02-migration-plan.md` 第 2 步）。
- `Kconfig` / `Kconfig.sysbuild`：无需改动。
- `CMakeLists.txt`：无需改动。
- 其他 boards/ 文件：不动。

## 7. 编译验证记录

- 本机（macOS）无 NCS 工具链（`west`/`cmake`/`ninja`/`nrfutil` 均未安装），**未实机构建**。
- 关键符号已对照 NCS v3.2.x 源码交叉核对：
  - `nordic,nus-uart` chosen 解析（`DT_CHOSEN(nordic_nus_uart)`）✓
  - `NRF_SAADC_AINx`（dt-bindings/adc/nrf-saadc.h，索引值）✓
  - `ADC_DT_SPEC_GET` / `adc_channel_setup_dt` / `gpio_dt_spec`（Zephyr ADC/GPIO API）✓
  - nrf54l15dk 板卡节点名（adc/gpio0-2/led3/button0/uart20）✓
- 构建命令与验证清单见 `02-migration-plan.md` 第 5 步。
