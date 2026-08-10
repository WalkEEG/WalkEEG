/*
 * WalkEEG 50 Hz mains notch filter (2nd-order IIR biquad).
 *
 * Sampling rate : 500 Hz  (WALKEEG_SAMPLE_HZ)
 * Notch freq    : 50 Hz   (China mains, coupled into ECG via body)
 * Pole radius   : 0.99    -> ~1.6 Hz notch bandwidth (Q ~ 30)
 *
 * Unity gain at DC and everywhere except a narrow band around 50 Hz,
 * so the 12-bit raw value range (0..4095) is preserved.
 *
 * Call notch_reset() when a streaming session starts.
 */
#ifndef WALKEEG_NOTCH_H_
#define WALKEEG_NOTCH_H_

#include <stdint.h>

/** Reset filter state (call on stream start / reconnect). */
void notch_reset(void);

/** Run one raw ADC sample through the 50 Hz notch filter. */
int16_t notch_50hz(int16_t x);

#endif /* WALKEEG_NOTCH_H_ */
