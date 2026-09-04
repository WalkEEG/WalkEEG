# 原理图绘制指南（中英双语）/ Schematic Design Guide (Bilingual)

> 排版约定：每节先中文、后英文，一一对照。
> Layout convention: Chinese first, then English, in each section.
>
> 核心理念 / Core idea：**原理图是给人看的，不是给机器看的。** 机器只关心网表对不对；人还关心能不能一眼看懂、会不会改错。
> **A schematic is for people, not just for machines.** Machines only care whether the netlist is correct; people also need to understand it at a glance and modify it without making mistakes.

---

## 1. 好原理图的标准 / What Makes a Good Schematic

按优先级排序 / In priority order：

1. **正确性 / Correctness** — ERC 无错误，网表与设计意图一致，与 PCB 一一对应。/ No ERC errors; netlist matches the design intent and the PCB one-to-one.
2. **可读性 / Readability** — 信号流向清晰、模块边界清楚，不用看图例也能读。/ Clear signal flow and module boundaries; readable without a legend.
3. **可维护性 / Maintainability** — 别人（或三个月后的自己）能改、敢改、改不错。/ Others (or you, three months later) can modify it safely and correctly.
4. **可复用性 / Reusability** — 子电路能整体复制到下一个项目。/ Sub-circuits can be reused in the next project.
5. **可评审性 / Reviewability** — 审图人知道该重点看哪里；有版本、有变更记录。/ Reviewers know what to focus on; versioning and change records exist.

原理图服务于所有下游动作：**评审、仿真、出 BOM、指导 PCB 布局、修板对照**。/ A schematic serves every downstream activity: **review, simulation, BOM generation, PCB layout guidance, and board bring-up/debugging.**

---

## 2. 画图之前 / Before You Draw

### 2.1 符号库 / Symbol Library

最容易被低估的一步，符号库质量直接决定原理图质量。/ The most underestimated step — symbol quality determines schematic quality.

| 原则 / Principle | 说明 / Explanation |
|---|---|
| **引脚按功能分组 / Group pins by function** | 电源在上、地在下面、高速信号一组、控制信号一组；不要照抄封装引脚顺序（分立器件除外）。封装是物理的，符号是逻辑的。/ Power on top, ground at bottom, high-speed signals grouped, control signals grouped; do not copy the package pin order (except discrete parts). The footprint is physical; the symbol is logical. |
| **引脚命名规范 / Proper pin naming** | 与数据手册一致且无歧义，如 `D+/D-`、`SBU1/SBU2`、`CC1/CC2`、`VBUS/GND`。不要用 `PIN1 PIN2`。/ Consistent with the datasheet and unambiguous, e.g. `D+/D-`, `SBU1/SBU2`, `CC1/CC2`, `VBUS/GND`. Never use `PIN1 PIN2`. |
| **引脚号不可错 / Pin numbers must be correct** | 符号引脚号 = 封装引脚号（经 Footprint 映射）。这是原理图→PCB 的命根子。/ Symbol pin number = footprint pin number (mapped via the footprint). This is the lifeline from schematic to PCB. |
| **隐藏引脚要谨慎 / Hidden pins: be careful** | 隐藏电源/地引脚虽省空间，但容易让读图人漏看供电关系。连接器类建议全部显示。/ Hidden power/ground pins save space but make supply connections easy to miss. For connectors, show all pins. |
| **方向一致 / Consistent orientation** | 输入端在左、输出端在右；电源脚朝上、地脚朝下。/ Inputs on the left, outputs on the right; power pins up, ground pins down. |
| **比例协调 / Balanced proportions** | 符号大小统一，文字不互相压叠，画完缩放检查。/ Consistent size, no overlapping text; zoom out and check when finished. |
| **多 Part 器件 / Multi-part components** | 确认每个 Gate 引脚分配正确，隐藏引脚只在其中一个 Part 上。/ Verify pin assignments per gate; hidden pins appear on only one part. |

> **连接器符号（如 USB Type-C）专项检查 / Connector symbols (e.g. USB Type-C) checklist**：CC1/CC2 与上下拉（Rd/Ra）关系、D+/D- 正反面位置（A6/A7 vs B6/B7）、SBU/VCONN 是否齐全、屏蔽地（Shell/GND）是否遗漏。/ Check: CC1/CC2 pull-up/pull-down (Rd/Ra), D+/D- pin position on both sides (A6/A7 vs B6/B7), SBU/VCONN presence, and that the shield (Shell/GND) pins are not missing.

### 2.2 模板与图纸 / Templates and Sheets

- 用**统一模板**：图框、标题栏、项目名、版本、日期、设计人、审阅人、页码 `Sheet X of Y`。/ Use a **unified template**: frame, title block, project name, revision, date, designer, reviewer, and page numbers `Sheet X of Y`.
- 图内预先放好**版本历史表**和**修订记录**。/ Include a **revision history table** in the template.
- 图纸尺寸与方向统一（A3/A4 横向为主），屏幕与打印都友好。/ Keep sheet size and orientation consistent (A3/A4 landscape preferred) for both screen and print.

### 2.3 栅格 / Grid

- 符号绘制用细栅格（约 0.1mm / 10mil），图纸连线用粗栅格（0.5mm / 50mil 或 100mil）。/ Fine grid for symbol drawing (≈0.1mm / 10mil); coarse grid for wiring (0.5mm / 50mil or 100mil).
- **所有引脚端点必须落在栅格点上**，否则连线无法对齐，出现"看似相连实际没连"的坑。/ **All pin ends must sit on grid points**, otherwise wires cannot align and you get "looks connected but is not" traps.
- 开启导线吸附（snap to grid）。/ Enable wire snapping (magnet).

### 2.4 命名约定 / Naming Conventions

团队项目先约定再画图。/ Agree on conventions before drawing (essential for teams):

- 网络名 / Net names：`3V3_A`、`5V_USB`、`I2C_SCL`、`SPI_MOSI`、`UART1_TX`
- 位号前缀 / Reference designator prefixes：U（IC）、R、C、L、Q、D、J（连接器 / connector）、F、SW、Y（晶振 / crystal）、TP（测试点 / test point）
- 信号后缀 / Signal suffixes：`_N` 低有效 / active-low（`RESET_N`）；`_A`/`_D` 模拟/数字 / analog/digital；`_H`/`_L` 电平含义 / logic level

---

## 3. 布局排版 / Layout & Placement

### 3.1 信号流向 / Signal Flow

- **主信号流：左 → 右**；反馈与回读：右 → 左。/ **Main signal flow: left → right**; feedback/return paths: right → left.
- 输入接口放最左，输出接口放最右。/ Input interfaces on the far left, outputs on the far right.
- **电源从上往下流，地在下**——整页像"瀑布"：顶层电源树，底层地。/ **Power flows top-down, ground at the bottom** — the page reads like a waterfall: power tree on top, ground at the bottom.
- 核心 IC 放页面中央，周边电路围绕展开；不要放在角落让线绕一大圈。/ Put the main IC in the center with support circuitry around it; don't corner it and route wires in a big loop.

### 3.2 模块化与分页 / Modularity & Multi-sheet

- **按功能分页**：电源页、MCU 页、接口页、模拟前端页……/ **Split by function**: power, MCU, interfaces, analog front-end, etc.
- 每页一个主题，页内放简单功能框图注释。/ One topic per sheet, with a simple functional block diagram as a text note.
- 跨页信号用**离图连接符 / 跨页连接符**并标注页码。/ Use **off-sheet connectors** for cross-page signals, annotated with the target page number.
- 大型项目用**层次化设计**：顶层是框图（方块 + 端口），底层每块一张子图。/ For large designs use **hierarchical design**: top sheet is a block diagram (sheet symbols + ports); each block expands to a child sheet.

### 3.3 器件摆放 / Component Placement

- **去耦电容紧挨所服务的芯片电源引脚**，别堆在图纸角落。/ Place **decoupling caps next to the power pins they serve**, not in a corner.
- 晶振、匹配电阻、ESD 器件、共模电感**就近摆放**——原理图位置暗示 PCB 布局优先级。/ Keep crystals, termination resistors, ESD devices, and common-mode chokes **close to their pins** — schematic position hints at PCB placement priority.
- 同功能器件（如 8 个下拉电阻）画成**整齐阵列**，不要散落。/ Arrange same-function parts (e.g. eight pulldowns) as **neat arrays**, not scattered.
- 留白合理：器件间留出走线和标注空间，别画成"毛线团"。/ Keep reasonable whitespace for wires and labels; avoid a "spaghetti" look.

### 3.4 分块框线 / Grouping Boxes

用虚线框圈出功能块并命名（`Power Section`、`USB 3.0`），标注电压与注意事项，读图速度翻倍。/ Use dashed boxes to group and name functional blocks (`Power Section`, `USB 3.0`) with voltage/notes — this roughly doubles reading speed.

---

## 4. 连线与网络 / Wiring & Nets

### 4.1 连线 / Wiring Rules

- 走**正交线**（水平/垂直），不画斜线；必要时用 45°。/ Route **orthogonal** wires (H/V); no arbitrary diagonals except 45°.
- 线间距均匀、不拥挤、不打结。/ Even spacing, no congestion, no knots.
- **不要在器件引脚上直接分叉**，T 形连接从引脚外引出。/ Do **not branch directly at a component pin**; take T-connections off the pin.
- 十字交叉默认**不相连**；相连必须画**结点（Junction）**。/ Crossing wires do **not** connect by default; always add a **junction dot** where they do.
- **禁止跨页飞线和超长绕线**，用网络标号断线。/ No cross-page fly wires or very long routes — break long nets with net labels.

### 4.2 网络标号 / Net Labels

- 同名 Net Label = 电气相连。**好的标号可以替代 60% 的连线**。/ Same-name net labels are electrically connected. **Good labeling can replace ~60% of wires.**
- 标号放在线的端点/引脚旁，不要悬空。/ Place labels at wire ends or next to pins — never floating in space.
- 网络名要有信息量：`I2C1_SCL` 远好于 `NET123`。/ Make net names meaningful: `I2C1_SCL` beats `NET123`.
- 电源/地用**专用电源符号（Power Port）**，不用普通文字标号。/ Use **dedicated power symbols (power ports)** for supplies and ground, not plain text labels.

### 4.3 总线 / Buses

- 数据/地址总线等成组信号用总线画法；**只在真正成群时使用**。/ Use bus notation for grouped signals (data/address); **only when they really are a group**.
- 总线进出要有明确的成员标注（`D[0..7]` 可展开为 D0…D7）。/ Bus entry/exit must clearly show members (`D[0..7]` expands to D0…D7).

### 4.4 电源与地 / Power & Ground（重中之重 / top priority）

- 不同电源域用不同符号/颜色/形状：`+3V3`、`+5V`、`VIN`。/ Use distinct symbols/colors/shapes per supply domain: `+3V3`, `+5V`, `VIN`.
- **地要区分**：`GND`、`AGND`、`DGND`、`PGND`（功率地 / power）、`SGND`（屏蔽/机壳地 / shield-chassis）、`GND_PWR`。不要统一画成 GND——否则 PCB 分割地时网表已经糊了。/ **Distinguish grounds**: `GND`, `AGND`, `DGND`, `PGND` (power), `SGND` (shield/chassis). Don't draw them all as one GND symbol, or the netlist is already corrupted before PCB ground splitting.
- 电源路径标注**来源与去向**（如 `3V3 ← U2 LDO`），复杂系统单独一页画电源树。/ Label each supply path with **source and destination** (e.g. `3V3 ← U2 LDO`); draw a power-tree sheet for complex systems.
- 每颗 IC 的电源引脚旁**明示去耦**（或注明见第 X 页）。/ Show **decoupling** next to each IC power pin (or note "see page X").

### 4.5 差分与高速信号 / Differential & High-Speed Signals

- 差分对（USB D+/D-、以太网、HDMI 等）**成对并排画**，命名成对并设置差分对属性，直接传给 PCB。/ Draw differential pairs (USB D+/D-, Ethernet, HDMI, etc.) **side by side as pairs**, name them as pairs, and set the differential-pair property for the PCB.
- 标注阻抗要求、串阻/共模电感位置（源端还是接收端）。/ Note impedance requirements and where series resistors/CM chokes sit (source or receiver side).

---

## 5. 标注 / Annotation

### 5.1 属性标注 / Component Attributes

- 每个器件：**位号 + 值/型号**（`R1 10kΩ`、`C3 0.1µF`、`U2 STM32F103C8T6`），字号统一、不遮挡引脚和线。/ Every part: **designator + value/part number**, uniform font size, nothing overlapping pins or wires.
- 关键参数写进值里：`100nF 50V X7R`。/ Put key parameters in the value: `100nF 50V X7R`.
- 关键器件写**订购型号全称**（含封装），方便直接转 BOM。/ For critical parts, write the **full orderable part number** (with package) so BOM generation is direct.
- 极性器件（电解电容、二极管、LED）极性标记清晰，方向与封装一致。/ Polarity marks on polarized parts (electrolytic caps, diodes, LEDs) must be clear and match the footprint.

### 5.2 说明性文字 / Notes & Callouts（不要吝啬 / be generous）

- 跳线/拨码默认状态：`JP1 默认 1-2 短接` / `JP1 default: 1-2 shorted`.
- 不贴件与选项：`R12 NC（不贴）`、`R13 0Ω 默认贴`。/ Population options: `R12 NC`, `R13 0Ω fitted by default`.
- 测试点：`TP1 测 VBUS`，可标注预期电压/波形。/ Test points: `TP1: measure VBUS`, optionally with expected voltage/waveform.
- 每个模块上方一行标题说明功能，如 "USB Type-C 接口 + ESD 保护"。/ One-line title above each module, e.g. "USB Type-C Interface + ESD Protection".

### 5.3 评审工具 / Review Tools

- 用标注/评论功能留评审意见（Altium Markers 等）。/ Use markers/comments for review feedback (e.g. Altium Markers).
- 预留 **Design Notes** 框，记录关键设计决策（为什么用这个拓扑、为什么这个值）。/ Keep a **Design Notes** block recording key decisions (why this topology, why this value).

---

## 6. 电源树与上电时序 / Power Tree & Power Sequencing

- 复杂系统单独一页 **Power Tree**：每个电压轨的来源（LDO/DCDC/外部输入）、电压/电流能力、去向。/ Complex systems get a dedicated **Power Tree** sheet: source of each rail (LDO/DCDC/external input), voltage/current capability, and loads.
- 多电压系统标注**上电顺序**要求与热插拔是否允许。/ For multi-rail systems, note **power-up sequencing** requirements and hot-plug policy.
- DCDC 电路按手册典型电路画，输入输出电容、电感、反馈分压标注齐全，注明参考手册章节。/ Draw DC-DC circuits per the datasheet typical application with input/output caps, inductor, and feedback divider fully specified, citing the app-note reference.

---

## 7. ERC 与交付前检查 / ERC & Pre-Release Checks

### 7.1 ERC（电气规则检查 / Electrical Rules Check）

- 跑完 **0 Error** 才允许进入下一步；Warning 逐条看，能消则消，不能消的写明原因。/ Reach **0 errors** before moving on; review every warning — fix or document why it is acceptable.
- 常见检查项：单端网络（漏连）、引脚悬空、输出对输出冲突、电源短路、总线位宽不匹配。/ Typical checks: single-pin nets (missing connections), unconnected pins, output-to-output conflicts, power shorts, bus width mismatches.

### 7.2 人工检查清单 / Manual Checklist

- [ ] 所有网络有头有尾：标号两端真实存在 / All nets have both ends; label endpoints exist
- [ ] 所有器件引脚有归属：连线/标号/电源符号/明确 NC / Every pin is assigned: wire, label, power symbol, or explicit NC
- [ ] NC 引脚明确标注，而非留空 / NC pins marked, not left blank
- [ ] 位号无重复、与 BOM 对应 / No duplicate designators; matches BOM
- [ ] 电源/地符号种类正确（AGND 没用成 GND）/ Correct power/ground symbol types (AGND not drawn as GND)
- [ ] 连接器引脚号与封装/线序一致 / Connector pin numbers match footprint/wiring order
- [ ] 极性器件方向统一且与封装一致 / Polarized parts oriented consistently with footprints
- [ ] 每页有页码、标题、版本 / Every sheet has page number, title, revision
- [ ] 跨页连接符页码与实际相符 / Off-sheet connector page numbers are correct
- [ ] 时钟、复位、使能等关键网络符合手册要求 / Clock, reset, enable nets follow the datasheet
- [ ] 原理图与 PCB 网表比对（ECO/Compare）干净 / Schematic-to-PCB netlist comparison (ECO/Compare) is clean

### 7.3 让别人审 / Get a Second Reader

自查永远有盲区。找一个不熟悉这块电路的人看 15 分钟，他看不懂的地方就是你要改的地方。/ Self-review always has blind spots. Ask someone unfamiliar with the circuit to read it for 15 minutes — wherever they get confused is where you need to improve.

---

## 8. 版本管理 / Version Control

- 标题栏维护**版本历史**：`V1.0 初始设计 → V1.1 修改 USB 上拉电阻`，写清谁、何时、改了什么、为什么。/ Maintain a **revision history** in the title block: `V1.0 initial → V1.1 changed USB pull-ups`, with who/when/what/why.
- 大改走修订流程，不要覆盖存档；用 VCS（Git/SVN）管理工程。/ Major changes follow a revision process; don't overwrite archives; manage projects in a VCS (Git/SVN).
- 发布前导出 **PDF 归档**（带交叉引用），评审、生产、维修统一用 PDF。/ Export a **PDF archive** (with cross-references) before release — use it for review, manufacturing, and repair so people don't edit the source freely.

---

## 9. EDA 工具速查 / EDA Tool Quick Reference

### Altium Designer

- 快捷键 / Hotkeys：`P W` 连线 / wire，`P N` 网络标号 / net label，`P O` 电源端口 / power port，`P J` 结点 / junction，`P T` 文字 / text
- `Tools → Annotation` 统一编号 / renumber；跨页连接符自动标注页码 / off-sheet connectors auto-annotate page numbers
- `Project → Compile` 即 ERC；`Report → Bill of Materials` 出 BOM
- 用 **Snippets（片段库）** 存常用子电路（USB 接口、电源、复位），新项目拖出即用 / Use **Snippets** for common sub-circuits (USB interface, power, reset) for instant reuse
- 符号画完核对引脚号与封装映射 / After drawing a symbol, verify pin numbers against the footprint mapping

### KiCad

- 连线 / Wire `W`；网络标签 / Label `L`；电源符号 / Power symbol `Ctrl+L`
- `ERC` 按钮跑检查；`Annotations` 菜单自动重排位号 / Run ERC; auto-renumber via Annotations
- 符号引脚画在 50mil 栅格上 / Draw symbol pins on a 50mil grid
- 自建库放独立目录随工程走，或用官方库 + PCM 插件 / Keep custom libraries in a project-local directory; use official libraries + PCM

---

## 10. 十条最终检查 / Ten Final Checks（贴显示器上 / pin this to your monitor）

1. 信号左进右出，电源上流下汇，地在下。/ Signals in from the left, out to the right; power from the top; ground at the bottom.
2. 能写明白的地方别让人猜：模块框、网络名、注释。/ Wherever it can be written down, write it down: block boxes, net names, notes.
3. 网络标号替代长连线；结点只在真连接处。/ Net labels replace long wires; junction dots only where real connections are.
4. 电源/地分域画清楚：AGND ≠ DGND ≠ GND。/ Keep power/ground domains separate: AGND ≠ DGND ≠ GND.
5. 去耦电容画在芯片电源脚旁边。/ Decoupling caps sit next to the IC power pins.
6. 位号、值、极性、方向样样齐全且不遮挡。/ Designators, values, polarity, and orientation complete and unobstructed.
7. 一个功能一页纸，跨页连接标注页码。/ One function per sheet; cross-sheet links show page numbers.
8. ERC 0 错误，Warning 条条有解释。/ ERC: 0 errors; every warning explained.
9. 版本、日期、审阅人写在标题栏。/ Revision, date, and reviewer in the title block.
10. **想象你是三个月后拿到这张图的人——它够清楚吗？** / **Imagine you are the person receiving this schematic three months from now — is it clear enough?**

---

*整理日期 / Date: 2026-09-04*
*说明：本文基于电子设计工程实践整理，可随团队习惯持续增补（位号规则、模板路径、符号库规范等）。/ Note: compiled from electronics design engineering practice; extend it with your team's own conventions (designator rules, template paths, symbol library standards, etc.).*

---

## 许可协议 / License

**MIT License**

Copyright (c) 2026 walkeeg 团队 / walkeeg Team（www.walkeeg.com）

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

中文简述 / Summary (中文): 本指南采用 MIT 协议开源（© 2026 walkeeg 团队，www.walkeeg.com），允许自由使用、复制、修改与分发（含商业用途），但须保留上述版权与许可声明；作者不对使用后果承担任何担保与责任。完整文本见同目录 LICENSE.md。/ This guide is released under the MIT License (© 2026 walkeeg Team, www.walkeeg.com): free to use, copy, modify and distribute, including commercially, provided the copyright and permission notice above is retained. No warranty of any kind is provided. Full text: LICENSE.md in the same directory.
