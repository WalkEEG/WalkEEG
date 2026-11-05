# WalkEEG Signal Algorithms

平台无关的信号统计算法库。**零第三方依赖，纯 Python 标准库。**

## 这是什么

一组可以直接调用的统计函数：输入采样数组，输出结构化指标。不涉及网络、不涉及云服务、不涉及文件系统。

语义定义在 [`docs/algorithms/`](../docs/algorithms) —— 本目录是**实现**，那份是**契约**。两者必须一致；有冲突时以规范为准，并修正实现。

## 为什么单独成一个目录

算法和部署是两件事。`07-backend/` 是一套具体的 AWS 部署（SAM 模板、Cognito、S3、Lambda 权限），别人不用 AWS 就整目录无关。但算法本身——频段能量、β/α 比值、RMS、包络、MDF——跟跑在哪台服务器上没关系。

放在仓库根，含义就很清楚：**要算法，拿走这一个目录；要部署参考，再看 `07-backend/`。**

## 设计约束

| 约束 | 原因 |
|---|---|
| **仅标准库** | 服务器上没有 pip 也能跑；Lambda、脚本、Notebook 通用 |
| **纯函数** | 无全局状态、无隐式 I/O，输入决定输出，可单元测试 |
| **单位显式** | 输入必须是 µV，函数名和参数都写明；不接受未换算的 LSB |
| **失败要大声** | 采样率不符、元数据缺失时抛异常，不猜默认值 |

## 用法

```python
import sys
sys.path.insert(0, "algorithms/python")

from walkeeg_stats import band_powers, beta_alpha_ratio

# 输入：单通道电压数组（µV），采样率 500 Hz
powers = band_powers(samples, sample_rate=500)
print(powers)          # {'theta': ..., 'alpha': ..., 'beta': ...}

ratio = beta_alpha_ratio(powers)
print(ratio)
```

## 目录结构

```
algorithms/
├── README.md              本文件
├── python/
│   ├── walkeeg_stats.py   算法实现（标准库）
│   └── conformance_test.py 对着基准向量自检
└── fixtures/
    ├── synthetic_alpha.csv  合成 10 Hz，用于验证 α
    ├── synthetic_emg.csv    合成宽带，用于验证 RMS
    └── expected.json        上述文件的期望输出
```

## 当前状态

**框架阶段。** 接口、数据契约、错误处理已定；算法函数体待实现，调用即抛 `NotImplementedError`。

这样做的理由：先把接口和验收方式固定下来，避免实现过程中反复改契约。等 `fixtures/` 建好、基准向量定下来，再填函数体，每个实现都有明确的"通过"标准。

| 模块 | 状态 |
|---|---|
| 数据校验 `_validate` | ✅ 已实现 |
| `band_powers` | ⬜ 待实现 |
| `beta_alpha_ratio` | ⬜ 待实现 |
| `rms` | ⬜ 待实现 |
| `envelope` | ⬜ 待实现 |
| `median_frequency` | ⬜ 待实现 |
| 基准向量 | ⬜ 待生成 |

## 相关文档

- [`docs/algorithms/data-format.md`](../docs/algorithms/data-format.md) — 数据格式与单位
- [`docs/algorithms/eeg-pipeline.md`](../docs/algorithms/eeg-pipeline.md) — EEG 处理链
- [`docs/algorithms/emg-pipeline.md`](../docs/algorithms/emg-pipeline.md) — EMG 处理链
- [`docs/algorithms/conformance.md`](../docs/algorithms/conformance.md) — 一致性判据
