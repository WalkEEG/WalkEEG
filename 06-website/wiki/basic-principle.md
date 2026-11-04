# Basic Principle

How the body produces an electrical signal, how electrodes pick it up, and what each of the three modalities reveals.

---

## Why the body is electrical

Every living cell maintains a voltage across its membrane. Ion pumps push sodium out and potassium in; the membrane's selective permeability then leaves the inside roughly **−70 mV** relative to the outside. That is the **resting potential**.

When a cell is excited, ion channels open, the membrane depolarises and an **action potential** travels along the cell. One neuron produces a signal far too small to see from the skin — on the order of microvolts at the surface. But when **millions fire together**, their postsynaptic potentials sum. That summed field is what surface electrodes measure.

Three tissues do this at very different scales and frequencies:

| | EEG | ECG | EMG |
|---|---|---|---|
| Tissue | Cortex | Cardiac muscle | Skeletal muscle |
| Amplitude at skin | 10 – 100 µV | 0.5 – 5 mV | 10 – 1000 µV |
| Bandwidth | 0.5 – 100 Hz | 0.05 – 150 Hz | 20 – 500 Hz |
| Rhythm | Spontaneous, continuous | Periodic, ~1 Hz | Bursty, task-driven |

The front end must span all of them — which is the reason WalkEEG specifies its noise floor against the weakest signal (EEG) while keeping headroom for the strongest (EMG).

---

## EEG — Electroencephalography

> *Electroencephalography is a method to record an electrogram of the spontaneous electrical activity of the brain. The biosignals detected by EEG represent the postsynaptic potentials of pyramidal neurons in the neocortex and allocortex.*

### What you are measuring

The cortex is a folded sheet of neurons, and most of it is organised in columns: pyramidal cells aligned in parallel, all pointing the same way. When a population of these cells receives synaptic input simultaneously, the individual potentials sum into a field that projects through the skull to the scalp.

Two consequences follow:

1. **Only synchronous activity is visible.** Random firing cancels out. EEG measures *rhythms*, not individual neurons.
2. **The skull blurs everything.** Bone and tissue are conductors of mediocre quality; high spatial frequencies are smeared out. Surface EEG has a spatial resolution measured in centimetres, not millimetres.

### Rhythms

EEG is conventionally decomposed into frequency bands. They are descriptive labels rather than hard boundaries, and they are what most analysis is built on:

| Band | Range | Where it shows up |
|---|---|---|
| **Delta** | 0.5 – 4 Hz | Deep sleep |
| **Theta** | 4 – 8 Hz | Drowsiness, some memory tasks |
| **Alpha** | 8 – 13 Hz | Relaxed wakefulness with eyes closed; strongest over occipital sites |
| **Beta** | 13 – 30 Hz | Active thinking, motor planning |
| **Gamma** | 30 – 100 Hz | Cross-region binding; low amplitude, easily drowned by muscle artifact |

Alpha is the easiest to observe: close your eyes and a roughly 10 Hz rhythm appears over the back of the head within a second or two. Open them and it mostly vanishes. That response is one of the simplest demonstrations that the signal is genuinely cortical.

### Electrode placement

The **International 10–20 system** is the standard method for describing scalp electrode positions. Landmarks (nasion, inion, pre-auricular points) define a coordinate grid; electrodes sit at 10 % and 20 % intervals along lines between them. Names encode location: `Fp` = frontal pole, `F` = frontal, `C` = central, `P` = parietal, `O` = occipital, `T` = temporal — with odd numbers on the left hemisphere and even on the right, `z` on the midline.

Consistent naming matters because it lets a recording be compared against another one made in a different lab with different equipment.

### Clinical and research use

EEG is a mature clinical tool, particularly for **epilepsy** — interictal spikes and seizure onset show up distinctly even through the skull. In sleep medicine it grades sleep stages. In research it underpins much of brain–computer interfacing: motor imagery produces measurable, classifiable changes over sensorimotor cortex.

**Intracranial EEG** (electrocorticography) places electrodes directly on the cortex. It gives much higher signal quality and is used in pre-surgical planning — but it requires surgery, which is the entire reason non-invasive EEG remains interesting.

### Practical notes for this platform

EEG is the most demanding target for a wireless front end:

- **Amplitude is tiny.** 10 µV of signal against millivolts of electrode offset and mains hum means CMRR and electrode impedance dominate the design.
- **Bandwidth is modest.** 100 Hz is enough — 500 Hz sampling leaves generous headroom and a margin for gamma.
- **Artifacts are everywhere.** Eye blinks produce large, slow frontal deflections; jaw and neck muscles contribute broadband EMG that overlaps the gamma band entirely.

---

**Further reading** — [Electroencephalography](https://en.wikipedia.org/wiki/Electroencephalography) · [Neural oscillation](https://en.wikipedia.org/wiki/Neural_oscillation) · [10–20 system](https://en.wikipedia.org/wiki/10%E2%80%9320_system_%28EEG%29) · [Brain–computer interface](https://en.wikipedia.org/wiki/Brain%E2%80%93computer_interface)

## ECG — Electrocardiography

> *Electrocardiography produces an electrocardiogram: a graph of voltage versus time of the heart's electrical activity, recorded with electrodes placed on the skin. Those electrodes detect the small electrical changes that are a consequence of cardiac muscle depolarisation followed by repolarisation during each cardiac cycle.*

### What you are measuring

The heart is a specialised muscle that depolarises in a coordinated wave, and the body is a volume conductor. Put two electrodes anywhere on the torso or limbs and you capture the projection of that wave along their axis.

A single cardiac cycle produces a repeating waveform with distinct features:

| Feature | What it represents | Typical size |
|---|---|---|
| **P wave** | Atrial depolarisation | 0.1 – 0.2 mV |
| **QRS complex** | Ventricular depolarisation — fast, sharp | 1 – 3 mV |
| **T wave** | Ventricular repolarisation — slower, broader | 0.2 – 0.3 mV |

The **R peak** — the tallest point of the QRS complex — is the marker nearly every heart-rate algorithm latches onto. It is large, sharp and unambiguous, which makes ECG by far the easiest of the three signals to detect reliably.

### Leads

The standard 12-lead ECG views the heart along twelve different axes simultaneously. Three useful groups:

- **Limb leads I, II, III** — bipolar, between arm and leg electrodes
- **Augmented leads aVR, aVL, aVF** — derived from the same electrodes
- **Precordial leads V1–V6** — across the chest

WalkEEG's single-lead path (AD8232) measures roughly what **Lead I** sees: the potential difference between left and right arms. That is enough for rhythm, heart rate and QRS timing. It is *not* enough for ischemia localisation, which needs the full set.

### What the trace tells you

| Measurement | Derived from | Why it matters |
|---|---|---|
| **Heart rate** | R–R interval | Baseline rhythm |
| **HRV** (SDNN, RMSSD) | Variation in R–R intervals | Autonomic balance, stress, recovery |
| **Rhythm** | R–R regularity | Arrhythmia screening |
| **ST segment** | Level between QRS and T | Ischemia — needs a multi-lead setup |
| **QRS width** | Duration of the complex | Conduction abnormality |

### Practical notes for this platform

- **Amplitude is comfortable.** 1 mV is a thousand times larger than EEG, so noise is far less of a problem.
- **But DC offset is not.** The **half-cell potential** at the electrode–skin interface can reach **±300 mV** — three hundred times the signal you want. A high-pass filter or a part that tolerates it is mandatory. The AD8232 explicitly accepts ±300 mV for exactly this reason.
- **Motion matters.** Moving the cable moves the electrode–skin interface, which produces a step change far larger than the signal.

---

**Further reading** — [Electrocardiography](https://en.wikipedia.org/wiki/Electrocardiography) · [Electrocardiogram](https://en.wikipedia.org/wiki/Electrocardiography#Electrocardiogram) · [Heart rate variability](https://en.wikipedia.org/wiki/Heart_rate_variability) · [QRS complex](https://en.wikipedia.org/wiki/QRS_complex)

## EMG — Electromyography

> *Electromyography is a technique for evaluating and recording the electrical activity produced by skeletal muscles. An electromyograph detects the electric potential generated by muscle cells when they are electrically or neurologically activated.*

### What you are measuring

Skeletal muscle is organised into **motor units**: one motor neuron and the muscle fibres it innervates. When a motor unit fires, the action potentials of all its fibres sum into a brief spike. A contraction recruits an increasing *number* of motor units and increases their *firing rate*.

Crucially, EMG is **interference-like**. Every motor unit contributes at a slightly different time and phase, so the surface signal is a dense, noisy-looking burst rather than a clean repeating waveform. Unlike ECG, there is no single feature you can point at.

| Property | Behaviour |
|---|---|
| Amplitude | Scales with contraction force — roughly 10 µV at rest up to 1 mV+ in a strong contraction |
| Frequency content | Broadband, centred around 50 – 150 Hz, energy extending to 500 Hz |
| Behaviour | Silent at rest, bursts on activation |

### What the trace tells you

- **Activation timing** — when a muscle turns on and off, resolved to tens of milliseconds
- **Relative force** — integrated or RMS amplitude over a window tracks contraction effort
- **Fatigue** — as a contraction is sustained, the median frequency of the spectrum *drops*; that downward shift is a reliable fatigue marker
- **Recruitment** — how many motor units are active, inferred from amplitude steps

### Surface vs. needle

**Needle EMG** inserts a fine electrode through the skin into the muscle. It records from very few motor units and is used clinically by neurologists to diagnose nerve and muscle disorders — it is an electrodiagnostic procedure, not a wearable measurement.

**Surface EMG (sEMG)** places electrodes on the skin over the muscle belly. It sums activity from a large volume, so it is far less specific — but completely non-invasive, and the basis for every consumer device, prosthetic controller and gesture interface. WalkEEG's front end is a surface configuration.

### Practical notes for this platform

- **Bandwidth drives the design.** An ECG-band front end — the AD8232 defaults to roughly 0.5 – 16 Hz — will *remove almost all EMG energy*. The on-board filter must be reworked for EMG: high-pass around 10 Hz, low-pass around 450 Hz. This is a documented modification in `docs/walkemg-frontend-A.md`.
- **Sampling rate matters.** Nyquist requires at least 2 × 500 Hz; 1000 – 2000 Hz is a practical minimum, which is why the firmware offers 2000 and 4000 Hz.
- **Crosstalk is inherent.** Nearby muscles always contribute. Separating them means careful electrode placement, not filtering.
- **EMG contaminates EEG.** Jaw and forehead muscle activity sits directly in the gamma band. Any EEG recording made near a clenched jaw should be treated with suspicion.

---

**Further reading** — [Electromyography](https://en.wikipedia.org/wiki/Electromyography) · [Motor unit](https://en.wikipedia.org/wiki/Motor_unit) · [Surface EMG](https://en.wikipedia.org/wiki/Electromyography#Surface_EMG) · [Muscle fatigue](https://en.wikipedia.org/wiki/Muscle_fatigue)

## Further reading

- **Wikipedia:** [Electroencephalography](https://en.wikipedia.org/wiki/Electroencephalography) · [Electrocardiography](https://en.wikipedia.org/wiki/Electrocardiography) · [Electromyography](https://en.wikipedia.org/wiki/Electromyography)
- **EEG electrode placement:** [10–20 system](https://en.wikipedia.org/wiki/10%E2%80%9320_system_%28EEG%29)
- **Datasheets:** [AD8232](https://www.analog.com/en/products/ad8232.html) · [ADS1292/ADS1293](https://www.ti.com/product/ADS1293)
- **Hardware specifics for this board:** [Hardware](hardware.md)
