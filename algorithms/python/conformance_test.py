"""Conformance tests for walkeeg_stats.

Run from the repository root:

    python3 algorithms/python/conformance_test.py

Two layers:
  1. Contract tests — validation and error handling. These run now and
     enforce the rules in docs/algorithms/ that prevent silent wrong answers.
  2. Numeric tests — compare against fixtures/. Skipped with a clear message
     until fixtures exist, so a missing baseline never looks like a pass.
"""

from __future__ import annotations

import json
import math
import sys
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))

import walkeeg_stats as ws  # noqa: E402

FIXTURES = HERE.parent / "fixtures"


class TestValidation(unittest.TestCase):
    """Contract rules — these must hold regardless of what the math does."""

    def test_rejects_empty(self):
        with self.assertRaises(ValueError):
            ws.band_powers([], sample_rate=500)

    def test_rejects_non_positive_rate(self):
        with self.assertRaises(ValueError):
            ws.band_powers([1.0, 2.0], sample_rate=0)

    def test_rejects_non_finite(self):
        for bad in (math.nan, math.inf, -math.inf):
            with self.subTest(bad=bad):
                with self.assertRaises(ValueError):
                    ws.rms([1.0, bad, 2.0])

    def test_rejects_string_input(self):
        with self.assertRaises(ValueError):
            ws.rms("12345")

    def test_lowpass_above_nyquist_raises(self):
        """The 450 Hz-on-500 Hz-data bug must fail loudly, not silently."""
        with self.assertRaises(ValueError) as ctx:
            ws.envelope([0.0] * 100, sample_rate=500, lowpass_hz=450)
        self.assertIn("Nyquist", str(ctx.exception))

    def test_lowpass_at_2000hz_is_accepted(self):
        """Same config is valid once the sample rate actually supports it."""
        try:
            ws.envelope([0.0] * 100, sample_rate=2000, lowpass_hz=450)
        except NotImplementedError:
            pass  # expected — body not written yet
        except ValueError as exc:  # pragma: no cover
            self.fail(f"2 kHz sampling should accept a 450 Hz cutoff: {exc}")

    def test_ratio_rejects_zero_alpha(self):
        with self.assertRaises(ValueError):
            ws.beta_alpha_ratio({"alpha": 0.0, "beta": 10.0})

    def test_ratio_rejects_missing_band(self):
        with self.assertRaises(ValueError):
            ws.beta_alpha_ratio({"alpha": 10.0})

    def test_ratio_computes_when_inputs_valid(self):
        # Pure arithmetic — no DSP involved, so this is testable now.
        self.assertAlmostEqual(
            ws.beta_alpha_ratio({"alpha": 10.0, "beta": 25.0}), 2.5
        )


class TestNumericAgainstFixtures(unittest.TestCase):
    """Compare results to fixtures/expected.json."""

    def setUp(self):
        self.expected_path = FIXTURES / "expected.json"
        if not self.expected_path.exists():
            self.skipTest(
                f"no baseline at {self.expected_path} — generate fixtures first "
                "(see docs/algorithms/conformance.md section 2)"
            )

    def test_alpha_power(self):
        expected = json.loads(self.expected_path.read_text())
        rows = (FIXTURES / "synthetic_alpha.csv").read_text().splitlines()[1:]
        samples = [float(r.split(",")[1]) for r in rows]
        got = ws.band_powers(samples, sample_rate=500)
        want = expected["synthetic_alpha"]["band_powers"]

        for band in ws.BANDS:
            with self.subTest(band=band):
                rel = abs(got[band] - want[band]) / max(abs(want[band]), 1e-12)
                self.assertLessEqual(rel, 0.01, f"{band} off by {rel:.3%}")


class TestNotImplementedIsExplicit(unittest.TestCase):
    """Framework stage: bodies raise, rather than returning a plausible zero.

    Returning 0.0 for an unwritten algorithm would be silently wrong data.
    """

    def test_eeg_body_pending(self):
        with self.assertRaises(NotImplementedError):
            ws.band_powers([0.0] * 1000, sample_rate=500)

    def test_rms_body_pending(self):
        with self.assertRaises(NotImplementedError):
            ws.rms([1.0, 2.0, 3.0])

    def test_mdf_body_pending(self):
        with self.assertRaises(NotImplementedError):
            ws.median_frequency([0.0] * 512, sample_rate=2000)


if __name__ == "__main__":
    unittest.main(verbosity=2)
