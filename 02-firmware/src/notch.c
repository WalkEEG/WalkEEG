/*
 * WalkEEG 50 Hz mains notch filter.
 *
 * Direct-form 2nd-order IIR notch (transfer function):
 *
 *        1 - 2*cos(w0) z^-1 + z^-2
 *   H(z) = --------------------------
 *        1 - 2*r*cos(w0) z^-1 + r^2 z^-2
 *
 *   w0 = 2*pi*F0/FS,  r = pole radius (0.99)
 *
 * Difference equation (b2 = 1, a1 defined POSITIVE):
 *   y[n] = x[n] + b1*x[n-1] + x[n-2] + a1*y[n-1] - a2*y[n-2]
 *   b1 = -2*cos(w0),  a1 = +2*r*cos(w0),  a2 = r^2
 *
 * NOTE: the a1 feedback term must be ADDED (positive feedback
 * keeps the poles at +-w0).  A sign error here moves the poles
 * to pi-w0 (~200 Hz) and turns the notch into a ~160x resonator.
 *
 * Float math runs on the Cortex-M4F FPU — negligible cost at 500 Hz.
 */

#include "notch.h"

#include <math.h>
#include <stdbool.h>

#define NOTCH_FS  500.0f
#define NOTCH_F0  50.0f
#define NOTCH_R   0.99f

static float b1, a1, a2;   /* coefficients (b2 = 1) */
static float x1, x2;       /* past inputs  */
static float y1, y2;       /* past outputs */
static bool  inited;
static bool  primed;       /* warm-up done */

static void notch_coeffs_init(void)
{
	float w0 = 2.0f * 3.14159265358979f * NOTCH_F0 / NOTCH_FS;
	float c  = cosf(w0);

	b1 = -2.0f * c;
	a1 =  2.0f * NOTCH_R * c;
	a2 =  NOTCH_R * NOTCH_R;
}

static void ensure_init(void)
{
	if (!inited) {
		notch_coeffs_init();
		inited = true;
	}
}

void notch_reset(void)
{
	ensure_init();
	x1 = x2 = y1 = y2 = 0.0f;
	primed = false;
}

int16_t notch_50hz(int16_t x)
{
	float xn = (float)x;
	float yn;

	ensure_init();

	if (!primed) {
		/* Warm-up: seed the filter with the first sample so the
		 * ~2.4 V DC baseline is not a step input (avoids start
		 * transient ringing).  With constant input the output
		 * stays ~x (DC gain ~1). */
		x1 = x2 = xn;
		y1 = y2 = xn;
		primed = true;
		return x;
	}

	yn = xn + b1 * x1 + x2 + a1 * y1 - a2 * y2;

	x2 = x1;
	x1 = xn;
	y2 = y1;
	y1 = yn;

	/* Clamp defensively (DC gain ~1, input 0..4095, so never hit). */
	if (yn > 32767.0f) {
		yn = 32767.0f;
	} else if (yn < -32768.0f) {
		yn = -32768.0f;
	}

	return (int16_t)yn;
}
