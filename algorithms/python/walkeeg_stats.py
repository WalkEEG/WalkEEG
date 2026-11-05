"""WalkEEG signal statistics — platform-neutral, standard library only.

Contracts live in ``docs/algorithms/``. This module implements them.

Design rules:
  * Inputs are voltages in **microvolts (uV)**, never raw LSB counts.
    Callers convert once, at the boundary, using a recorded ``lsb_uv``.
  * Functions are pure: no globals, no I/O, no hidden state.
  * Bad input raises ``ValueError`` — never a silent default. A wrong
    sample rate quietly produces wrong numbers, which is worse than a crash.

Status: framework. Signatures, validation and error handling are final;
the numeric bodies raise ``NotImplementedError`` until fixtures exist.
"""

from __future__ import annotations

import math
from typing import Iterable, Sequence

__all__ = [
    "band_powers",
    "beta_alpha_ratio",
    "rms",
    "envelope",
    "median_frequency",
    "BANDS",
]

#: Frequency band edges in Hz, inclusive lower / exclusive upper.
#: See docs/algorithms/eeg-pipeline.md section 4.1.
BANDS: dict[str, tuple[float, float]] = {
    "theta": (4.0, 7.0),
    "alpha": (8.0, 12.0),
    "beta": (13.0, 30.0),
}


# --------------------------------------------------------------------------
# Validation
# --------------------------------------------------------------------------


def _validate(
    samples: Sequence[float],
    sample_rate: float,
    *,
    min_samples: int = 1,
) -> list[float]:
    """Check a sample array and return it as a list of floats.

    Raises:
        ValueError: on empty input, non-finite values, or an unusable rate.
    """
    if sample_rate <= 0:
        raise ValueError(f"sample_rate must be positive, got {sample_rate!r}")

    if isinstance(samples, (str, bytes)) or not isinstance(samples, Iterable):
        raise ValueError(
            f"samples must be a sequence of numbers, got {type(samples).__name__}"
        )

    values = [float(x) for x in samples]

    if len(values) < min_samples:
        raise ValueError(
            f"need at least {min_samples} samples, got {len(values)}"
        )

    for i, v in enumerate(values):
        if not math.isfinite(v):
            raise ValueError(f"sample[{i}] is not finite: {v!r}")

    return values


def _require_nyquist(sample_rate: float, cutoff_hz: float, what: str) -> None:
    """Guard against a cutoff above the Nyquist frequency.

    An upper cutoff past Nyquist has no meaningful coefficient set; silently
    running it is exactly the bug described in docs/algorithms/emg-pipeline.md
    section 3, where 450 Hz filtering was configured against 500 Hz data.
    """
    nyquist = sample_rate / 2.0
    if cutoff_hz >= nyquist:
        raise ValueError(
            f"{what} cutoff {cutoff_hz} Hz is at or above Nyquist "
            f"({nyquist} Hz for {sample_rate} Hz sampling). "
            "Check that the sample rate matches the data."
        )


# --------------------------------------------------------------------------
# EEG — frequency domain
# --------------------------------------------------------------------------


def band_powers(
    samples: Sequence[float],
    sample_rate: float,
    *,
    window: str = "hann",
) -> dict[str, float]:
    """Band power for theta / alpha / beta, in uV^2.

    Args:
        samples: single-channel voltage in uV. Window length sets the
            frequency resolution as ``sample_rate / len(samples)``.
        sample_rate: sampling rate in Hz.
        window: window function; ``"hann"`` per the spec. Gain must be
            compensated so absolute values are comparable across windows.

    Returns:
        ``{'theta': uV^2, 'alpha': uV^2, 'beta': uV^2}``

    See docs/algorithms/eeg-pipeline.md sections 2 and 4.1.
    """
    _validate(samples, sample_rate)

    # Nyquist must clear the highest band edge, or "beta power" is meaningless.
    _require_nyquist(sample_rate, max(hi for _, hi in BANDS.values()), "EEG band")

    raise NotImplementedError(
        "Implement per docs/algorithms/eeg-pipeline.md: Hann window with "
        "coherent-gain compensation, sum |X(f)|^2 over each band's bins."
    )


def beta_alpha_ratio(powers: dict[str, float]) -> float:
    """Beta/alpha ratio — dimensionless arousal index.

    Args:
        powers: output of :func:`band_powers`.

    Returns:
        ``beta / alpha``.

    Raises:
        ValueError: if a band is missing, or if alpha power is not positive
            (a zero alpha makes the ratio undefined rather than infinite).

    See docs/algorithms/eeg-pipeline.md section 4.2.
    """
    for band in ("alpha", "beta"):
        if band not in powers:
            raise ValueError(f"missing '{band}' in powers: {sorted(powers)}")

    alpha = powers["alpha"]
    if not math.isfinite(alpha):
        raise ValueError(f"alpha power is not finite: {alpha!r}")
    if alpha <= 0:
        raise ValueError(
            f"alpha power must be positive to form a ratio, got {alpha!r}"
        )

    beta = powers["beta"]
    if not math.isfinite(beta):
        raise ValueError(f"beta power is not finite: {beta!r}")

    return beta / alpha


# --------------------------------------------------------------------------
# EMG — time domain
# --------------------------------------------------------------------------


def rms(samples: Sequence[float], *, window_samples: int | None = None) -> float:
    """Root mean square amplitude, in uV.

    Args:
        samples: rectified or raw voltage in uV; squaring makes the sign moot.
        window_samples: if given, analyse only the trailing window.

    Returns:
        RMS in uV.

    See docs/algorithms/emg-pipeline.md section 4.1.
    """
    _validate(samples, sample_rate=1.0)  # rate irrelevant here

    raise NotImplementedError(
        "Implement per docs/algorithms/emg-pipeline.md section 4.1: "
        "sqrt(mean(x^2)) over the window."
    )


def envelope(
    samples: Sequence[float],
    sample_rate: float,
    *,
    highpass_hz: float = 20.0,
    lowpass_hz: float = 450.0,
    envelope_hz: float = 5.0,
) -> list[float]:
    """EMG envelope: bandpass, rectify, low-pass.

    Args:
        samples: raw voltage in uV.
        sample_rate: sampling rate in Hz — determines every coefficient.
        highpass_hz: removes drift and movement artifact.
        lowpass_hz: upper band limit; must sit below Nyquist.
        envelope_hz: smoothing cutoff for the envelope.

    Returns:
        Envelope array, same length as input, in uV.

    Raises:
        ValueError: if ``lowpass_hz`` is at or above Nyquist — the failure
            mode that produced garbage whenever 450 Hz filtering was run
            against 500 Hz data.

    See docs/algorithms/emg-pipeline.md sections 2 and 3.
    """
    _validate(samples, sample_rate)
    _require_nyquist(sample_rate, lowpass_hz, "EMG lowpass")

    raise NotImplementedError(
        "Implement per docs/algorithms/emg-pipeline.md section 2: "
        "one-pole IIR a=exp(-2*pi*fc/fs), rectify, then envelope low-pass."
    )


def median_frequency(
    samples: Sequence[float],
    sample_rate: float,
    *,
    window_samples: int = 256,
) -> float:
    """Median frequency (MDF) in Hz — fatigue indicator.

    MDF drops as a muscle fatigues; the spec requires >= 10% over a 30 s
    sustained contraction.

    Args:
        samples: single-channel voltage in uV.
        sample_rate: sampling rate in Hz.
        window_samples: analysis window; >= 256 for usable resolution.

    Returns:
        Median frequency in Hz.

    See docs/algorithms/emg-pipeline.md section 4.2.
    """
    _validate(samples, sample_rate, min_samples=window_samples)

    if window_samples < 256:
        raise ValueError(
            f"window_samples must be >= 256 for usable frequency resolution, "
            f"got {window_samples}"
        )

    raise NotImplementedError(
        "Implement per docs/algorithms/emg-pipeline.md section 4.2: "
        "power spectrum, cumulative sum to half of total, interpolate the "
        "crossing frequency."
    )
