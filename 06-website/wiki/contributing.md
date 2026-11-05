# Contributing

This is an open project — hardware, firmware and software all live in one repository, and improvements to any layer are welcome.

---

## Ways to help

| Area | What's useful |
|---|---|
| **Firmware** | Test on boards we don't have (nRF5340, nRF54L15). Report build results. |
| **Hardware** | Review schematics, propose filter changes, contribute a layout variant. |
| **Software** | Parser tests, UI polish, additional export formats. |
| **Docs** | Anything that took you more than ten minutes to figure out belongs here. |
| **Bug reports** | Especially *reproducible* ones with logs. |

---

## Before you open a pull request

1. **Rebuild from clean.** Zephyr caches devicetree and Kconfig aggressively — a stale build directory will make you chase ghosts.
   ```bash
   rm -rf /tmp/build-walkeeg
   ```

2. **Note your toolchain.** In the PR description, state the NCS version and Zephyr SDK version you built with. "It compiles" is only useful with that context.

3. **Hardware changes ship with a PDF.** If you touch a `.kicad_sch` or `.kicad_pcb`, export a PDF in the same commit. Reviewers shouldn't need KiCad installed to read your change.

4. **Protocol changes update the docs.** A frame format change means `docs/` and the [Protocol](protocol.md) page change in the same commit.

5. **Run the tests.**
   ```bash
   cd "05-Flutter program" && flutter test
   ```

---

## Code style

**Firmware** — follow Zephyr's conventions. `west build` must be warning-clean on the `nrf52840dk/nrf52840` target.

**Dart** — `flutter analyze` should pass with no new issues.

**Commits** — a short imperative subject line, then a body explaining *why*:
```
fix(firmware): select AD8232 path by default

The ADS1293 Kconfig option defaulted to y, so boards carrying an AD8232
faulted during front-end init and reset every ~85 s. Explicitly disable
the SPI path for the on-board AFE.
```

---

## Reporting a bug

Include, at minimum:

- Board and revision
- NCS / Zephyr SDK versions
- What you expected vs. what happened
- RTT log if the firmware is involved

The [Troubleshooting](firmware/troubleshooting.md) page covers the failures we've already hit — check it first, and if your case isn't there, that's exactly the kind of report worth filing.

---

## Licence

Contributions are accepted under the [MIT licence](https://github.com/WalkEEG/WalkEEG/blob/master/LICENSE).
