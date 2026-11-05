# Key Technology

How the signal gets from an electrode to a number — and how to read what comes out.

---

## ADC — Analog-to-Digital Conversion

> **Two architectures, two different jobs. WalkEEG uses both.**

Every biosignal eventually becomes a number. How that happens — and which converter does it — sets the noise floor, the dynamic range and the power budget of the whole system.

### Why the architecture matters

An ADC's headline spec is usually "how many bits". That number alone is close to meaningless. What matters is:

| Property | What it determines |
|---|---|
| **Architecture** | Speed vs. resolution trade-off, noise shape, latency |
| **Resolution** | Smallest step — but only if the noise floor allows it |
| **ENOB** | *Effective* number of bits after noise and distortion |
| **Input range** | Where the signal must sit to be measurable |
| **Sampling rate** | Highest frequency you can represent (Nyquist) |

WalkEEG's two front ends sit at opposite ends of this table:

| | **nRF52840 SAADC** | **ADS129x** |
|---|---|---|
| Architecture | **SAR** (successive approximation) | **ΔΣ** (delta-sigma) |
| Resolution | 8 / 10 / **12** / 14 bit | **24** bit |
| Channels | 8, multiplexed | 2–3, **simultaneous** |
| Latency | One conversion, µs | Several output periods, ms |
| Power | µA, scales with rate | ~mW, always on |
| Integration | Bare ADC | PGA + reference + RLD + lead-off |

Neither is "better". They are built for different constraints.

---

### SAR ADC — nRF52840 SAADC

#### Confirmed architecture

Nordic's MDK header states it plainly:

```
/* Description: Successive approximation register (SAR) analog-to-digital converter */
```

The nRF52840's **SAADC** is a **successive-approximation register** converter, with selectable resolution of **8, 10, 12 or 14 bits**.

#### How successive approximation works

A SAR ADC is a binary search, done in hardware:

```
1. Sample the input onto a hold capacitor
2. Guess the MSB, output it through a DAC, compare against the input
3. If the DAC output is too low → keep the bit, else clear it
4. Move to the next bit, repeat
5. After N comparisons you have an N-bit result
```

For 12 bits that is **12 comparisons per sample**. Each comparison is a comparator settling event, which is why the sample rate and the resolution are directly coupled: doubling the resolution roughly halves the maximum rate.

**Consequences worth knowing:**

- **Fast.** A conversion takes microseconds — a single sample per comparison chain.
- **Latency is one conversion.** No filter group delay. Good for control loops.
- **Noise is white.** Errors land in the same band as the signal.
- **Resolution is honest but modest.** 12 bits gives 4096 levels; thermal noise usually puts ENOB a bit below that.

#### What the nRF52840 SAADC gives you

| Parameter | nRF52840 SAADC |
|---|---|
| Resolution | 8 / 10 / 12 / 14 bit |
| Channels | 8 single-ended, or 4 differential |
| Input range | 0 – VDD (single-ended), ±VDD/2 (differential) |
| Gain | 1/6, 1/5, 1/4, 1/3, 1/2, 1, 2, 4 |
| Reference | Internal 0.6 V, or VDD/4 |
| Oversampling | Yes — hardware accumulation up to 256× |

**The oversampling feature changes the calculus.** Accumulating 4ⁿ samples and shifting increases ENOB by roughly *n* bits, at the cost of throughput. It is the standard way to trade sample rate for resolution on a SAR part.

#### How WalkEEG uses it

The AD8232 path is a single-ended SAADC measurement:

```ini
CONFIG_ADC=y
＃ CONFIG_ADC_NRFX_SAADC is derived automatically from the devicetree
```

```c
/* src/adc_sample.c — CH0 = AD8232 output on AIN0 = P0.02 */
```

| Aspect | Value |
|---|---|
| Channel | AIN0 (P0.02) |
| Mode | Single-ended |
| Resolution | 12 bit |
| Rate | 500 / 1000 / 2000 / 4000 Hz |
| Gain | configured for the electrode-scaled input |

**Practical note:** the SAADC is single-ended, so the signal is offset around mid-scale. The value `2048` is nominally zero volts — everything is interpreted relative to it. The firmware transmits raw counts and lets the app do the arithmetic.

---

### Delta-Sigma ADC — ADS129x

#### Confirmed architecture

TI's datasheet is explicit:

> *The ADS1291, ADS1292, and ADS1292R are multichannel, simultaneous sampling, **24-bit, delta-sigma (ΔΣ)** analog-to-digital converters (ADCs) with a built-in programmable gain amplifier (PGA), internal reference, and an onboard oscillator.*

#### How delta-sigma works

Rather than one comparison per bit, a ΔΣ converter trades *speed* for *accuracy* by oversampling enormously and shaping the error:

```
input ──▶ [Σ] ──▶ [comparator, 1 bit] ──▶ out
           ▲                               │
           └────── [DAC] ◀── [1-bit] ◀─────┘
                    │
                    └──▶ digital low-pass decimation filter ──▶ N-bit result
```

The comparator only ever outputs **1 bit**, but at a rate many times the signal bandwidth. That single bit is *wildly* inaccurate — and that's the point:

**Noise shaping.** The feedback loop pushes quantisation noise out of the signal band and into the high frequencies, where a digital low-pass filter removes it. The result: an enormous in-band SNR, manufactured from a noisy 1-bit stream.

**Decimation.** After filtering, only every Nth output is kept. That is where the "N bits" come from — you are not measuring with 24 comparators, you are *integrating* your way to 24 bits of precision.

#### What that buys, and what it costs

| | ΔΣ advantage | ΔΣ cost |
|---|---|---|
| Resolution | 24-bit, but more importantly **high ENOB** | — |
| Noise | Shaped away from the signal band | — |
| Latency | — | Filter group delay: several output periods |
| Throughput | — | Lower max rate for a given clock |
| Complexity | — | Needs a decimation filter, more silicon |

**The latency is the real trade-off.** A ΔΣ converter at 500 SPS has a group delay of a few sample periods — a handful of milliseconds. Irrelevant for ECG display, disqualifying for a motor control loop.

#### Practical advantage: everything on one die

The ADS129x family puts the whole signal chain in one package:

```
   electrodes ──▶ [ PGA ] ──▶ [ ΔΣ ADC ] ──▶ SPI
                     │
                     ├── internal reference
                     ├── RLD amplifier  ──▶ reference electrode
                     ├── lead-off detection
                     └── oscillator
```

That integration is why a 3-lead 24-bit front end fits on a small board. Doing the same thing discretely — PGA, reference, RLD, 24-bit converter — takes an order of magnitude more area and more design risk.

#### How WalkEEG uses it

The ADS1293 path (default `CONFIG_WALKEEG_USE_ADS1293=y`):

| Aspect | Value |
|---|---|
| Resolution | 24 bit |
| Channels | 3 (Lead I / II / III) |
| Rate | 533 SPS nominal (configurable) |
| Interface | SPI mode 0, up to 20 MHz |
| Channel mapping | CH0/1/2 = Lead I/II/III, CH3–7 = 0 |

The 24-bit result is truncated to 16 bits in the frame — see [Protocol](protocol.md).

---

#### Choosing between them

| If you need… | Use |
|---|---|
| Cheap, one signal, fast | **SAR** — nRF52840 SAADC, no external parts |
| Simultaneous channels, 24-bit, clinical quality | **ΔΣ** — ADS129x, one chip, more cost |
| Low power at low rates | **SAR** with duty-cycled sampling |
| Integrated RLD and lead-off | **ΔΣ** — ADS129x has it built in |
| Arbitrary filter design | **ΔΣ** — the decimation filter is programmable |

**The engineering rule:** architecture follows the signal. EEG at 10 µV needs the noise floor of a ΔΣ converter. A 500 Hz single-lead ECG does not — a 12-bit SAR with good analog design in front of it is entirely adequate, and costs a fraction as much.

---


## CMRR — Common-Mode Rejection Ratio

> **Why a 1 mV heartbeat is readable at all, when the room is shouting 50 Hz at both electrodes equally.**

### The problem CMRR solves

An electrode pair never sees only the signal you want. Both electrodes also pick up whatever the body is floating at — [mains hum](https://en.wikipedia.org/wiki/Mains_hum) coupled through the air, the power supply of the laptop next to you, the switching noise of an LED driver. That shared, identical voltage is the **common-mode signal**.

The signal you actually want — the potential difference *between* the electrodes — is the **differential signal**.

A real amplifier cannot separate the two perfectly. Part of the common-mode voltage leaks into the output as if it were a genuine differential signal. That leak is an error, and in biosignal recording it is usually the dominant error.

**CMRR** — [common-mode rejection ratio](https://en.wikipedia.org/wiki/Common-mode_rejection_ratio) — quantifies how well the amplifier suppresses it.

### Definition

```
CMRR = 20 · log₁₀ ( A_d / A_cm )   [dB]
```

- `A_d` — differential gain (what you want: ~1000×)
- `A_cm` — common-mode gain (what you don't: ideally 0)

That ratio is the whole reason a [differential amplifier](https://en.wikipedia.org/wiki/Differential_amplifier) or [instrumentation amplifier](https://en.wikipedia.org/wiki/Instrumentation_amplifier) sits at the front of every biosignal chain: it amplifies the difference and, ideally, ignores the shared part.

A CMRR of 80 dB means the differential gain is 10,000 times the common-mode gain. A 100 dB CMRR means 100,000 times. **Every 20 dB is a factor of 10.**

### Why it matters numerically

This is not an abstract figure of merit. Work the numbers:

Assume **1 V** of 50 Hz common-mode interference coupled onto the body — an ordinary, unremarkable situation for someone sitting near a laptop. Assume a differential gain of 1000×, and a 1 mV ECG signal.

| CMRR | Leaked 50 Hz at input | Leaked 50 Hz at output | Verdict |
|---|---|---|---|
| **60 dB** | 1 mV | 1 V | Swamps the 1 mV signal entirely — unusable |
| **80 dB** | 100 µV | 100 mV | Still 10 % of the signal; visible hum on every trace |
| **100 dB** | 10 µV | 10 mV | 1 % for ECG — but still half of a 20 µV EEG signal |
| **120 dB** | 1 µV | 1 mV | 0.1 % — clean |

Now substitute EEG at **20 µV**. At 80 dB the common-mode leak (100 µV) is **five times the signal**. The trace is not merely noisy — the signal is *gone*.

**That single calculation explains why AD8232 stops at 80 dB for single-lead ECG and why the ADS129x family reaches 105–120 dB.**

### How CMRR is specified on a datasheet

Real CMRR is frequency-dependent — it falls as frequency rises, because parasitic capacitance and amplifier finite gain both degrade with frequency. Datasheets therefore quote it **at a condition**:

| Part | CMRR | Condition |
|---|---|---|
| **AD8232** | 80 dB | DC to 60 Hz |
| **ADS1292 / ADS1292R** | 105 dB min, 120 dB typ | f = 50 Hz and 60 Hz, common-mode 0.3 V inside the rails |

> The ADS1292 datasheet footnote reads: *"CMRR is measured with a common-mode signal of AVSS + 0.3 V to AVDD − 0.3 V. The values indicated are the minimum of the two channels."* Always read the conditions — a headline number measured at DC tells you nothing about performance at 50 Hz.

### What actually limits CMRR in a real system

An amplifier's own CMRR is only the starting point. In a built system, the dominant limitation is usually not the chip:

**1. Electrode impedance mismatch — the big one**
[Electrode](https://en.wikipedia.org/wiki/Electrode) impedance mismatch destroys CMRR faster than any other single factor. CMRR of the *whole front end* degrades roughly as:

```
CMRR_system ≈ CMRR_amp + 20·log₁₀( Z_electrode / ΔZ )
```

With 80 dB amplifier CMRR and two electrodes at 10 kΩ that differ by 1 kΩ, you get a 10:1 ratio → +20 dB → **100 dB**. But if they differ by 5 kΩ, the ratio is 2:1 → +6 dB → only **86 dB**.

Electrode mismatch can *destroy* an otherwise excellent amplifier. This is why:

- Skin preparation and conductive gel are not optional
- Electrodes must be same batch, same size, same contact area
- A dry electrode's 1 MΩ impedance will dominate everything else

**2. Right-leg drive**
Passive electrodes rely entirely on the amplifier. An active right-leg drive (RLD) circuit senses the common-mode voltage and drives it back into the body inverted, cancelling it at the source. The ADS1293 includes an RLD amplifier on chip; the AD8232 requires an external op-amp plus a reference electrode. This is often worth more than 20 dB — far more than swapping amplifiers.

**3. Cable and PCB parasitic capacitance**
Any capacitance from the electrode cable to ground converts common-mode voltage into a differential current. Shielding and guarding matter more at high impedance.

**4. Power supply rejection is a different number**
[PSRR](https://en.wikipedia.org/wiki/Power_supply_rejection_ratio) — power supply rejection ratio (typically ~90 dB on ADS129x) — describes sensitivity to supply ripple, not to body-borne common mode. Don't confuse them.

### Practical implications for WalkEEG

| Signal | Amplitude | CMRR needed for a clean trace |
|---|---|---|
| EMG | 100 – 1000 µV | 60–80 dB is often enough |
| [ECG](https://en.wikipedia.org/wiki/Electrocardiography) | 0.5 – 5 mV | 80 dB workable, 100 dB comfortable |
| EEG | 10 – 100 µV | **100 dB+**, and electrode hygiene does as much as the chip |

This is why the website states **80–120 dB** rather than a single number: the AD8232 path (80 dB, single lead, low cost) and the ADS1293 path (24-bit, integrated RLD) sit at opposite ends of the same platform.

**The engineering rule:** fix the electrodes and add right-leg drive before hunting for a better amplifier. At 80 dB, a 1 kΩ impedance mismatch costs you more than any part upgrade will recover.

**Further reading** — [Common-mode rejection ratio](https://en.wikipedia.org/wiki/Common-mode_rejection_ratio) · [Differential amplifier](https://en.wikipedia.org/wiki/Differential_amplifier) · [Instrumentation amplifier](https://en.wikipedia.org/wiki/Instrumentation_amplifier) · [Mains hum](https://en.wikipedia.org/wiki/Mains_hum) · [Power supply rejection ratio](https://en.wikipedia.org/wiki/Power_supply_rejection_ratio)

---

---

## RLD — Right-Leg Drive

> **CMRR alone is passive. Right-leg drive is the active circuit that makes it work.**

### The problem: the body is an antenna

A person is a conductor sitting in an electric field. Mains wiring, fluorescent lamps and switch-mode supplies all couple tens of microamps into the body by capacitive coupling through the air.

An electrode pair sees this as a large, near-identical voltage on both inputs. That's the common-mode signal — and as the [CMRR](#cmrr--common-mode-rejection-ratio) chapter showed, even a good amplifier lets a fraction of it through.

There are two ways to fight it:

| Approach | Mechanism |
|---|---|
| **Passive** (amplifier CMRR only) | Rely entirely on how well the amplifier rejects the shared voltage |
| **Active** (right-leg drive) | Sense the common-mode voltage and *drive it back* into the body, nulling it at the source |

RLD is the second one. It turns the body from an antenna into a node tied to a controlled potential.

### Why it's called "right leg"

Historically, ECG used three limb electrodes: left arm, right arm and **right leg**. The left and right arms carry the differential signal; the right leg was the natural place to attach the reference electrode that drives the body.

The circuit's purpose is to invert the common-mode voltage and apply it to the body through that reference electrode:

```
        common-mode on the body
                 │
                 ▼
      ┌──────────────────────┐
      │  differential amp    │──▶ ECG out (desired)
      │  (electrodes LA, RA) │
      └──────────┬───────────┘
                 │ senses V_cm
                 ▼
      ┌──────────────────────┐
      │   RLD amplifier      │  gain ≈ −A
      │   (inverting)        │
      └──────────┬───────────┘
                 │
                 ▼
             RL electrode  ──▶ driven *into* the body
             (cancels V_cm at the source)
```

If the body is being pushed to +1 V of mains hum, the RLD injects roughly −1 V through the reference electrode. The two largely cancel, and the amplifier now sees a common-mode voltage close to zero.

### Why it helps so much

Two effects stack:

1. **The common-mode voltage at the electrodes shrinks** — often by 30–40 dB, before the amplifier contributes anything
2. **The amplifier is no longer operating near its limit** — the residual common mode now sits well inside its linear range, so CMRR stays closer to the datasheet figure

A system at 80 dB amplifier CMRR plus an effective RLD can behave like 100 dB or better. **This is the single highest-leverage addition to a biosignal front end**, and it costs one op-amp and one electrode.

### The loop, and why it needs care

RLD is a **feedback loop around the human body**, which is why it behaves unusually:

```
V_cm ──▶ [RLD amp] ──▶ [electrode] ──▶ [body impedance] ──▶ back to V_cm
                   ▲                                    │
                   └──────────── feedback ──────────────┘
```

The loop has:

- **Gain** — high enough to cancel, low enough to remain stable
- **Bandwidth** — a low-pass corner typically below ~1 kHz; the loop must not oscillate
- **Phase margin** — electrode impedance and body capacitance add poles that a breadboard won't reveal

**When the loop becomes unstable the symptom is distinctive:** the trace develops a strong oscillation, often in the tens of hertz, that survives every attempt to filter it out. This is a classic sign of too much RLD gain or a badly placed reference electrode.

### Practical design constraints

**The series resistor is not optional.** A resistor (typ. 10 kΩ – 1 MΩ) sits between the RLD amplifier output and the electrode:

- It limits the current injected into a patient during a fault — a safety requirement, not a nicety
- It also stabilises the loop by adding a zero/pole pair

**Placement of the reference electrode matters.** It should be electrically central to the differential pair. With a single-lead ECG on the chest, that means a deliberately placed reference, not a convenient bolt on the cable.

**Do not ground the body.** Driving the body with an active RLD *replaces* grounding it. Doing both creates a current path and defeats the whole point.

### Implementation in this project

| Path | RLD capability |
|---|---|
| **AD8232** | Requires an external op-amp and a dedicated reference electrode |
| **ADS1293** | Integrated RLD amplifier, routed to IN4 — `REG_RLD_CN = 0x04` in the firmware |

The ADS1293 firmware writes:

```c
/* RLD amp out -> IN4 */
err |= ads1293_reg_write(REG_RLD_CN, 0x04);
```

Which means: the right-leg drive signal is brought out on the IN4 pin, so it can be routed to the reference electrode.

**Practical advice:** if your trace looks worse than the datasheet would suggest, and no amount of shielding helps, the reference electrode is the first thing to check — not the amplifier.

---

## Fourier Analysis — From Series to Spectrum

> **A signal in time and a signal in frequency are the same information, viewed from two angles.**

A digitised trace is a long list of numbers. Almost every useful question about it — is alpha present, is that hum at 50 Hz, is this muscle or brain — is answered by looking at its spectrum.

---

### Why the frequency domain

A raw EEG trace is a tangle of overlapping rhythms. Eyeballing it tells you little. But decompose it into how much energy sits at each frequency, and structure appears immediately:

```
  time domain                          frequency domain
  ───────────                          ────────────────
  ~~~~~~~~\___/\___/~~~~~~   ──FFT──▶  ▁▁▂▄█▆▃▁▁▁▁▁▁▁▁
  "it looks wiggly"                    "10 Hz, 45 µV²"
```

The second view answers questions the first cannot: *Is alpha present? Is that a 50 Hz hum or a 48 Hz oscillation? Is this muscle artifact or brain activity?*

---

### Fourier series — the starting point

In 1807 Fourier claimed something that sounded absurd: **any periodic function can be written as a sum of sine and cosine waves.**

```math
f(t) = a₀ + Σ [ aₙ·cos(2πnf₀t) + bₙ·sin(2πnf₀t) ]
       n=1..∞
```

where the **coefficients** say how much of each harmonic is present:

```math
aₙ = (2/T) ∫₀ᵀ f(t)·cos(2πnf₀t) dt
bₙ = (2/T) ∫₀ᵀ f(t)·sin(2πnf₀t) dt
```

That integral is the whole idea in one line: **multiply the signal by a test wave and integrate.** If the signal contains that frequency, the product is mostly positive and the integral is large. If it doesn't, the product oscillates and averages to zero. This is **correlation with a reference**.

**Why harmonics appear.** A square wave has the same fundamental period as a sine, but to build sharp corners you must add its odd multiples. That is what "harmonic structure" means physically — the sharpness of a waveform *is* its high-frequency content.

> **Practical consequence.** A signal with sharp edges has energy far up the spectrum. An ECG QRS complex is a sharp spike — so its energy extends well into the tens of hertz, and any filter that removes those frequencies will round it off.

---

### From series to transform

Fourier series only works for **periodic** signals. A real EEG recording is not periodic — it never repeats.

The extension is conceptually simple: **let the period go to infinity.** As `T → ∞`, the harmonic spacing `f₀ = 1/T → 0`, and the sum becomes an integral over a continuous range of frequencies.

That is the **Fourier transform**:

```math
F(ω) = ∫_{-∞}^{∞} f(t) · e^{-jωt} dt

f(t) = (1/2π) ∫_{-∞}^{∞} F(ω) · e^{jωt} dω
```

Euler's relation `e^{-jωt} = cos(ωt) − j·sin(ωt)` shows it is the same operation as before: multiply by cosines and sines, integrate. The series becomes a **continuous spectrum** rather than a list of discrete harmonics.

`F(ω)` is complex — it carries both **magnitude** and **phase** at every frequency. Most biosignal work looks only at `|F(ω)|²`, the power spectrum, and discards phase.

---

### Reading a spectrum

| Term | Meaning |
|---|---|
| **Fourier transform** | Continuous, `F(ω)`, exact, needs infinite time |
| **Discrete Fourier Transform (DFT)** | `X[k]`, on `N` samples — what you actually compute |
| **FFT** | An algorithm computing the DFT in `O(N log N)` instead of `O(N²)` |
| **Spectrum** | `|X[k]|` — magnitude per frequency bin |
| **Power spectral density** | Energy per Hz — the right way to compare signals of different length |

**Bin spacing** is `f_s / N`. At 500 Hz with a 2 s window (N = 1000), each bin is **0.5 Hz** wide. To resolve 1 Hz of alpha from 2 Hz of delta you need roughly a 1 s window or longer — **frequency resolution is set by how long you observe, not by the sample rate.**

**Nyquist.** A signal sampled at `f_s` can only represent frequencies up to `f_s/2`. Anything above that **folds back** into the low end as a fake component. This is why analog anti-aliasing filters exist: a 500 Hz sampler cannot distinguish 60 Hz from 440 Hz, and both land in the same bin.

---

### Windowing, and why it matters

The DFT assumes your `N` samples repeat infinitely. Real data does not — the window cuts the waveform mid-cycle, creating a **discontinuity** the transform interprets as broadband energy.

The fix is to taper the window edges:

| Window | Main-lobe width | Sidelobe level | Use |
|---|---|---|---|
| **Rectangular** | narrowest | −13 dB | transient signals, not spectra |
| **Hann** | 2× rectangular | −31 dB | general purpose — the default choice |
| **Hamming** | similar to Hann | −43 dB | when leakage matters more than resolution |
| **Blackman** | widest | −58 dB | very weak signals near strong ones |

**Spectral leakage** is the artifact of not windowing. A pure 10 Hz sine analysed without a window can appear to have energy across several bins — looking like broad-band activity that isn't really there.

---

### How WalkEEG uses frequency analysis

The DSP layer in `05-Flutter program/lib/dsp/` is deliberately lightweight — it runs on a phone in real time.

**EEG band power — Goertzel, not FFT**

`eeg_analyzer.dart` computes theta, alpha and beta power over a 2 s window at 50 % overlap:

```
theta  4–7 Hz      alpha  8–12 Hz      beta  13–30 Hz
```

Rather than a full FFT, it uses the **Goertzel algorithm** — a single-bin DFT. If you only need a handful of frequencies, evaluating the DFT directly at those bins costs far less than computing all 1000 of them.

> This is the practical lesson: **FFT is the right tool when you need the whole spectrum; a targeted transform is right when you need three numbers.**

**Mains notch — a filter, not a spectrum**

`mains_notch_filter.dart` removes 50 Hz with a cascaded biquad (Q = 20, two stages, >80 dB attenuation) rather than by zeroing an FFT bin. A filter runs sample-by-sample in real time and introduces no windowing artifacts; an FFT bin-zero requires a whole block in memory and leaves spectral ghosts.

> **Rule of thumb:** to *remove* a known frequency, filter it. To *measure* a spectrum, transform it.

**EMG envelope — time domain only**

`emg_analyzer.dart` high-passes at 20 Hz, low-passes at 450 Hz, rectifies and smooths to a 5 Hz envelope. No transform at all — for a signal with no narrow-band structure, amplitude in the time domain carries all the information you need.

**Where FFT does appear:** the MATLAB toolchain (`04-MATLAB program/`) uses FFT freely for offline analysis, where computational cost is irrelevant and full-spectrum views are exactly the point.

---

### The summary in one line

Frequency analysis turns an unreadable waveform into a set of numbers you can threshold, filter and classify. It is the bridge between "the signal arrives" and "the signal means something".

---

## The 10–20 System

> **Where you put the electrodes decides what you can measure.** The 10–20 system is how everyone agrees on those positions.

### Why a standard exists

Two labs recording "alpha over the occipital lobe" must be measuring the same location, or their results cannot be compared. Before 10–20, electrode placement was ad hoc — each clinic used its own scheme, and cross-study comparison was impossible.

The **International [10–20 system](https://en.wikipedia.org/wiki/10%E2%80%9320_system_%28EEG%29)** (Jasper, 1958) fixed that. It defines electrode positions as fractions of measurable distances on the skull, so any technician anywhere can reproduce the same montage.

### The geometry

Four anatomical landmarks anchor the grid:

| Landmark | Location |
|---|---|
| **[Nasion](https://en.wikipedia.org/wiki/Nasion)** | Bridge of the nose, between the eyes |
| **Inion** | Bump at the back of the skull |
| **Pre-auricular points** | Just in front of each ear |

Two measurements follow:

- **Nasion → inion** (the midline, front to back) = 100 %
- **Left pre-auricular → right pre-auricular** (coronal) = 100 %

Electrodes sit at **10 %** and **20 %** intervals along these lines — hence the name. The first electrode behind the nasion is at 10 %, the next at a further 20 %, and so on.

### Naming

Every electrode name encodes two things:

```
  F   p  1        ← frontal pole, left
  ─   ─  ─
  │   │  └── number: odd = left, even = right, z = midline
  │   └───── sub-region modifier (p = pole)
  └───────── region: F frontal, C central, P parietal, O occipital, T temporal
```

| Region | Name | Rough position |
|---|---|---|
| Frontal pole | `Fp1` / `Fp2` | Above the eyebrows, left / right |
| Frontal | `F3` / `F4` / `Fz` | Front third of the skull |
| Central | `C3` / `C4` / `Cz` | Across the top, motor cortex |
| Parietal | `P3` / `P4` / `Pz` | Behind central |
| Occipital | `O1` / `O2` | Back of the head, visual cortex |
| Temporal | `T7` / `T8` (older: `T3`/`T4`) | Side of the head |

**Odd numbers are always the left hemisphere. Even numbers are the right. `z` is the midline.** Once you know that, `F3` reads as "frontal, left" without a lookup table.

### What each region sees

| Region | Predominant activity |
|---|---|
| **Occipital** (`O1`, `O2`) | Alpha rhythm — vanishes on eye opening |
| **Central** (`C3`, `C4`) | Mu rhythm; motor imagery produces measurable desynchronisation here |
| **Frontal** (`Fp1`, `Fp2`) | Eye blink artifacts dominate — huge, slow deflections |
| **Temporal** (`T7`, `T8`) | Often contaminated by jaw and neck muscle |

This table is why BCI work usually starts with `C3`/`C4`: motor imagery is strongest there and the artifact load is moderate.

### Beyond 10–20

The 10–20 grid has 21 electrodes. Higher-density research uses the **10–10** (≈ 70 positions) or **10–5** systems, which subdivide the same intervals further and add names like `FC3` (fronto-central) or `CP4`. See the [10–20 system overview](https://en.wikipedia.org/wiki/10%E2%80%9320_system_%28EEG%29#Higher-density_descriptions) for how the finer grids derive from the same landmarks.

More electrodes give better spatial resolution, but each one adds a channel, a wire, and another source of contact noise. WalkEEG's 8-channel front end sits at the sparse end of this spectrum by design — enough for a research montage over the regions that matter, not a full-head cap.

### Practical notes for this board

**Montage matters more than electrode count.** Two differential channels placed well (`C3`−`Cz`, `C4`−`Cz`) give cleaner motor-imagery data than eight placed carelessly.

**Lead-off detection is not optional.** A dry or lifted electrode produces a plausible-looking trace that is entirely artifact. The AD8232's LO+/LO− comparators and the ADS1293's built-in lead-off detection exist to catch this automatically.

**The reference electrode is a design decision.** Every differential measurement needs one. In a classic 10–20 montage it is `Cz` or the linked mastoids; here it is the RLD electrode (see [RLD](#rld--right-leg-drive)). Where you place it changes what the common-mode rejection actually rejects.

**Further reading** — [10–20 system](https://en.wikipedia.org/wiki/10%E2%80%9320_system_%28EEG%29) · [EEG electrode nomenclature](https://en.wikipedia.org/wiki/Electroencephalography#Electrode_placement) · [Nasion](https://en.wikipedia.org/wiki/Nasion) · [Electroencephalography](https://en.wikipedia.org/wiki/Electroencephalography)
