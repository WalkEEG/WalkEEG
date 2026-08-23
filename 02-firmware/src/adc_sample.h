/*
 * WalkEEG AD8232 ECG sampling over the nRF SAADC-compatible ADC.
 *
 * Pin map is defined in the board overlay (walkeeg,ecg-pins node):
 *
 *   nRF52840 (青风 board, P13 header):
 *     - AIN0  (P0.02)  : AD8232 OUTPUT  (ECG analog)
 *     - P1.13 (LO+)    : lead-off detect input
 *     - P1.15 (LO-)    : lead-off detect input
 *     - P1.14 (SDN)    : shutdown control (high = running)
 *     ECG signal rides on REFOUT (~VDD/2 = 1.65 V), so single-ended
 *     SAADC with gain 1/6 (0..3.6 V full scale) maps it comfortably.
 *
 *   nRF54L15-DK (expansion header PORT P1) — proposal, verify on HW:
 *     - AIN4  (P1.11)  : AD8232 OUTPUT
 *     - P1.12 (LO+)    : lead-off detect input
 *     - P1.14 (LO-, LED3) : lead-off detect input
 *     - P1.13 (SDN, SW0)  : shutdown control
 *     ADC gain 1/4 + internal reference (~3.6 V full scale if ref = 0.9 V).
 */
#ifndef WALKEEG_ADC_SAMPLE_H_
#define WALKEEG_ADC_SAMPLE_H_

#include <stdbool.h>
#include <stdint.h>

#define WALKEEG_ADC_HZ   500   /* per-channel sample rate */
#define WALKEEG_ADC_GAIN_NUM   1
#define WALKEEG_ADC_GAIN_DEN   6
#define WALKEEG_ADC_REF_MV     600  /* internal 0.6 V reference (nRF52) */

/** One ADC sample + lead-off flags. */
struct walkeeg_adc_sample {
	int16_t value;   /* raw 12-bit ADC (0..4095) */
	bool    lo_plus; /* true when LO+ high (lead attached) */
	bool    lo_minus;
};

/** Initialize GPIO (SDN high) and ADC channel. Call once at boot. */
int walkeeg_adc_init(void);

/** Blocking single conversion; returns 0 on success. */
int walkeeg_adc_read(struct walkeeg_adc_sample *s);

/** Sample timer callback hook (from stream module), 500 Hz. */
void walkeeg_adc_tick(void);

#endif /* WALKEEG_ADC_SAMPLE_H_ */
