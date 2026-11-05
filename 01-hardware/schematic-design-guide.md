# Schematic Design Guide

> Core idea: **a schematic is for people, not just for machines.** Machines only care whether the netlist is correct; people also need to understand it at a glance and modify it without making mistakes.

---

## 1. What Makes a Good Schematic

In priority order:

1. **Correctness** — no ERC errors; the netlist matches the design intent and the PCB one-to-one.
2. **Readability** — clear signal flow and module boundaries; readable without a legend.
3. **Maintainability** — others (or you, three months later) can modify it safely and correctly.
4. **Reusability** — sub-circuits can be reused in the next project.
5. **Reviewability** — reviewers know what to focus on; versioning and change records exist.

A schematic serves every downstream activity: **review, simulation, BOM generation, PCB layout guidance, and board bring-up/debugging.**

---

## 2. Before You Draw

### 2.1 Symbol Library

The most underestimated step — symbol quality determines schematic quality.

| Principle | Explanation |
|---|---|
| **Group pins by function** | Power on top, ground at the bottom, high-speed signals grouped, control signals grouped; do not copy the package pin order (except discrete parts). The footprint is physical; the symbol is logical. |
| **Proper pin naming** | Consistent with the datasheet and unambiguous, e.g. `D+/D-`, `SBU1/SBU2`, `CC1/CC2`, `VBUS/GND`. Never use `PIN1 PIN2`. |
| **Pin numbers must be correct** | Symbol pin number = footprint pin number (mapped via the footprint). This is the lifeline from schematic to PCB. |
| **Hidden pins: be careful** | Hidden power/ground pins save space but make supply connections easy to miss. For connectors, show all pins. |
| **Consistent orientation** | Inputs on the left, outputs on the right; power pins up, ground pins down. |
| **Balanced proportions** | Consistent size, no overlapping text; zoom out and check when finished. |
| **Multi-part components** | Verify pin assignments per gate; hidden pins appear on only one part. |

> **Connector symbols (e.g. USB Type-C) checklist**: CC1/CC2 pull-up/pull-down (Rd/Ra), D+/D- pin position on both sides (A6/A7 vs B6/B7), SBU/VCONN presence, and that the shield (Shell/GND) pins are not missing.

### 2.2 Templates and Sheets

- Use a **unified template**: frame, title block, project name, revision, date, designer, reviewer, and page numbers `Sheet X of Y`.
- Include a **revision history table** in the template.
- Keep sheet size and orientation consistent (A3/A4 landscape preferred) for both screen and print.

### 2.3 Grid

- Fine grid for symbol drawing (≈0.1mm / 10mil); coarse grid for wiring (0.5mm / 50mil or 100mil).
- **All pin ends must sit on grid points**, otherwise wires cannot align and you get "looks connected but is not" traps.
- Enable wire snapping (magnet).

### 2.4 Naming Conventions

Agree on conventions before drawing (essential for team projects):

- Net names: `3V3_A`, `5V_USB`, `I2C_SCL`, `SPI_MOSI`, `UART1_TX`
- Reference designator prefixes: U (IC), R, C, L, Q, D, J (connector), F, SW, Y (crystal), TP (test point)
- Signal suffixes: `_N` active-low (`RESET_N`); `_A`/`_D` analog/digital; `_H`/`_L` logic level

---

## 3. Layout & Placement

### 3.1 Signal Flow

- **Main signal flow: left → right**; feedback/return paths: right → left.
- Input interfaces on the far left, outputs on the far right.
- **Power flows top-down, ground at the bottom** — the page reads like a waterfall: power tree on top, ground at the bottom.
- Put the main IC in the center with support circuitry around it; don't corner it and route wires in a big loop.

### 3.2 Modularity & Multi-sheet

- **Split by function**: power, MCU, interfaces, analog front-end, etc.
- One topic per sheet, with a simple functional block diagram as a text note.
- Use **off-sheet connectors** for cross-page signals, annotated with the target page number.
- For large designs use **hierarchical design**: top sheet is a block diagram (sheet symbols + ports); each block expands to a child sheet.

### 3.3 Component Placement

- Place **decoupling caps next to the power pins they serve**, not in a corner.
- Keep crystals, termination resistors, ESD devices, and common-mode chokes **close to their pins** — schematic position hints at PCB placement priority.
- Arrange same-function parts (e.g. eight pulldowns) as **neat arrays**, not scattered.
- Keep reasonable whitespace for wires and labels; avoid a "spaghetti" look.

### 3.4 Grouping Boxes

Use dashed boxes to group and name functional blocks (`Power Section`, `USB 3.0`) with voltage/notes — this roughly doubles reading speed.

---

## 4. Wiring & Nets

### 4.1 Wiring Rules

- Route **orthogonal** wires (H/V); no arbitrary diagonals except 45°.
- Even spacing, no congestion, no knots.
- Do **not branch directly at a component pin**; take T-connections off the pin.
- Crossing wires do **not** connect by default; always add a **junction dot** where they do.
- No cross-page fly wires or very long routes — break long nets with net labels.

### 4.2 Net Labels

- Same-name net labels are electrically connected. **Good labeling can replace ~60% of wires.**
- Place labels at wire ends or next to pins — never floating in space.
- Make net names meaningful: `I2C1_SCL` beats `NET123`.
- Use **dedicated power symbols (power ports)** for supplies and ground, not plain text labels.

### 4.3 Buses

- Use bus notation for grouped signals (data/address); **only when they really are a group**.
- Bus entry/exit must clearly show members (`D[0..7]` expands to D0…D7).

### 4.4 Power & Ground (top priority)

- Use distinct symbols/colors/shapes per supply domain: `+3V3`, `+5V`, `VIN`.
- **Distinguish grounds**: `GND`, `AGND`, `DGND`, `PGND` (power), `SGND` (shield/chassis), `GND_PWR`. Don't draw them all as one GND symbol, or the netlist is already corrupted before PCB ground splitting.
- Label each supply path with **source and destination** (e.g. `3V3 ← U2 LDO`); draw a power-tree sheet for complex systems.
- Show **decoupling** next to each IC power pin (or note "see page X").

### 4.5 Differential & High-Speed Signals

- Draw differential pairs (USB D+/D-, Ethernet, HDMI, etc.) **side by side as pairs**, name them as pairs, and set the differential-pair property for the PCB.
- Note impedance requirements and where series resistors/CM chokes sit (source or receiver side).

---

## 5. Annotation

### 5.1 Component Attributes

- Every part: **designator + value/part number** (`R1 10kΩ`, `C3 0.1µF`, `U2 STM32F103C8T6`), uniform font size, nothing overlapping pins or wires.
- Put key parameters in the value: `100nF 50V X7R`.
- For critical parts, write the **full orderable part number** (with package) so BOM generation is direct.
- Polarity marks on polarized parts (electrolytic caps, diodes, LEDs) must be clear and match the footprint.

### 5.2 Notes & Callouts (be generous)

- Jumper/switch default state: `JP1 default: 1-2 shorted`.
- Population options: `R12 NC`, `R13 0Ω fitted by default`.
- Test points: `TP1: measure VBUS`, optionally with expected voltage/waveform.
- One-line title above each module, e.g. "USB Type-C Interface + ESD Protection".

### 5.3 Review Tools

- Use markers/comments for review feedback (e.g. Altium Markers).
- Keep a **Design Notes** block recording key decisions (why this topology, why this value).

---

## 6. Power Tree & Power Sequencing

- Complex systems get a dedicated **Power Tree** sheet: source of each rail (LDO/DCDC/external input), voltage/current capability, and loads.
- For multi-rail systems, note **power-up sequencing** requirements and hot-plug policy.
- Draw DC-DC circuits per the datasheet typical application with input/output caps, inductor, and feedback divider fully specified, citing the app-note reference.

---

## 7. ERC & Pre-Release Checks

### 7.1 ERC (Electrical Rules Check)

- Reach **0 errors** before moving on; review every warning — fix it or document why it is acceptable.
- Typical checks: single-pin nets (missing connections), unconnected pins, output-to-output conflicts, power shorts, bus width mismatches.

### 7.2 Manual Checklist

- [ ] All nets have both ends; label endpoints exist
- [ ] Every pin is assigned: wire, label, power symbol, or explicit NC
- [ ] NC pins marked, not left blank
- [ ] No duplicate designators; matches BOM
- [ ] Correct power/ground symbol types (AGND not drawn as GND)
- [ ] Connector pin numbers match footprint/wiring order
- [ ] Polarized parts oriented consistently with footprints
- [ ] Every sheet has page number, title, revision
- [ ] Off-sheet connector page numbers are correct
- [ ] Clock, reset, enable nets follow the datasheet
- [ ] Schematic-to-PCB netlist comparison (ECO/Compare) is clean

### 7.3 Get a Second Reader

Self-review always has blind spots. Ask someone unfamiliar with the circuit to read it for 15 minutes — wherever they get confused is where you need to improve.

---

## 8. Version Control

- Maintain a **revision history** in the title block: `V1.0 initial → V1.1 changed USB pull-ups`, with who/when/what/why.
- Major changes follow a revision process; don't overwrite archives; manage projects in a VCS (Git/SVN).
- Export a **PDF archive** (with cross-references) before release — use it for review, manufacturing, and repair so people don't edit the source freely.

---

## 9. EDA Tool Quick Reference

### Altium Designer

- Hotkeys: `P W` wire, `P N` net label, `P O` power port, `P J` junction, `P T` text
- `Tools → Annotation` to renumber; off-sheet connectors auto-annotate page numbers
- `Project → Compile` runs ERC; `Report → Bill of Materials` generates the BOM
- Use **Snippets** for common sub-circuits (USB interface, power, reset) for instant reuse
- After drawing a symbol, verify pin numbers against the footprint mapping

### KiCad

- Wire `W`; label `L`; power symbol `Ctrl+L`
- Run `ERC` to check; auto-renumber via the `Annotations` menu
- Draw symbol pins on a 50mil grid
- Keep custom libraries in a project-local directory; use official libraries + PCM

---

## 10. Ten Final Checks (pin this to your monitor)

1. Signals in from the left, out to the right; power from the top; ground at the bottom.
2. Wherever it can be written down, write it down: block boxes, net names, notes.
3. Net labels replace long wires; junction dots only where real connections are.
4. Keep power/ground domains separate: AGND ≠ DGND ≠ GND.
5. Decoupling caps sit next to the IC power pins.
6. Designators, values, polarity, and orientation complete and unobstructed.
7. One function per sheet; cross-sheet links show page numbers.
8. ERC: 0 errors; every warning explained.
9. Revision, date, and reviewer in the title block.
10. **Imagine you are the person receiving this schematic three months from now — is it clear enough?**

---

## 11. Practical Layout Rules (post-review, 2026-09-05 BALANX2 power page)

> From comparing generated vs hand-polished blocks.

1. **Rotate parts to serve routing** (0/90/180/270°) so wires stay short and straight; e.g. a resistor lying across two stubs, or a cap flipped 180° to park its text in empty space.
2. **Ref & value follow the part**: rotate with it and use justification to hug the outside edge; never let text overlap wires or bodies — mind long values such as `10uF_16V_10%`.
3. **Pace**: left-in/right-out flow, ≥1.27–2.54mm spacing, place the backbone first and fill gaps after.
4. **Labels are a last resort**: wire physically when possible; name nets once and deliberately (e.g. `CHG_EN`); delete dead wires and stale notes.
5. **Self-check by eye**: zoom each placement for text/wire collisions and readability, not just netlist correctness.
6. Keep one-line titles above each block (per §5.2).

---

*Date: 2026-09-04*
*Note: compiled from electronics design engineering practice; extend it with your team's own conventions (designator rules, template paths, symbol library standards, etc.).*

---

## License

**MIT License**

Copyright (c) 2026 walkeeg Team (www.walkeeg.com)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Summary: this guide is released under the MIT License (© 2026 walkeeg Team, www.walkeeg.com) — free to use, copy, modify and distribute, including commercially, provided the copyright and permission notice above is retained. No warranty of any kind is provided. Full text: LICENSE.md in the same directory.
