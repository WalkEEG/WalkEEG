# WalkEEG 信号处理规范

> 跨平台算法契约：数据格式、算法定义、输入输出约定。
> 目的：任何实现（Flutter / Python / Node / MATLAB）只要遵守本文档，产出的数值可互相校验。

## 为什么需要这个目录

同一套算法目前分散在多个实现里：

| 位置 | 语言 | 内容 |
|---|---|---|
| `05-Flutter program/lib/dsp/emg_analyzer.dart` | Dart | EMG 包络、RMS、激活度 |
| `05-Flutter program/lib/dsp/eeg_analyzer.dart` | Dart | EEG θ/α/β、β/α 比值 |
| `08-realtime/server.js` | Node | 实时转发与显示 |
| `07-backend/src/handlers/process.js` | Node | 批处理骨架（TODO） |
| `03-PC program` / `04-MATLAB program` | C# / MATLAB | 早期分析 |

问题不在于"代码放了几个地方"，而在于**没有唯一的事实来源**：实现之间参数不一致、修正不回流、换平台就要重写。

本目录只定义**契约**，不规定实现位置：

- **实时**算法仍在设备侧（App / 本机 relay）——500 Hz × 8 通道的延迟要求决定它不能上云。
- **离线**算法可在 `07-backend` 的 Lambda 批处理，也可在 PC 脚本里跑。
- 两边都必须对着**同一份规范**实现，并用同一组基准向量验收。

## 文档索引

| 文档 | 内容 | 状态 |
|---|---|---|
| [data-format.md](data-format.md) | CSV / BLE 帧 / 单位与量纲 | 待编写 |
| [emg-pipeline.md](emg-pipeline.md) | EMG：带通 → 整流 → 包络 → RMS / MDF | 待编写 |
| [eeg-pipeline.md](eeg-pipeline.md) | EEG：θ/α/β 频段能量、β/α 比值 | 待编写 |
| [conformance.md](conformance.md) | 基准向量与跨实现一致性测试 | 待编写 |

## 三条硬性约定

1. **单位统一**：所有规范中的幅度一律用 **µV**（输入换算系数单独定义），时间一律用 **秒**，频率一律用 **Hz**。代码内部可用 LSB，但跨越模块边界必须标注单位。
2. **算法必须可复现**：每条算法都要给出滤波器类型、阶数、系数推导方式或参考实现，禁止只写"做带通滤波"。
3. **伪迹必须显式**：无法消除的伪迹只能标记或整窗丢弃，且必须出现在输出字段里，不能静默混入结果。

## 与现有文档的关系

- 硬件与前端选型：`06-website/wiki/hardware.md`、`docs/ads1293/README.md`
- 需求与验收：`docs/eeg-alpha-beta-ratio.md`、`docs/emg-channel-requirement.md`
- 服务端部署：`07-backend/README.md`

本目录是**算法语义**的唯一出处；需求文档负责"要什么"，本目录负责"算什么、怎么算"。
