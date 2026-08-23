/*
 * WalkEEG TI ADS1293 3-channel ECG AFE driver (SPI).
 *
 * Hardware notes (nRF52840, SPI1):
 *   - SCLK  P1.00  (SPIM1 SCK)
 *   - MOSI  P1.01  (SPIM1 MOSI -> ADS1293 SDI)
 *   - MISO  P1.02  (SPIM1 MISO <- ADS1293 SDO)
 *   - CS    P1.03  (GPIO, active low)
 *   - DRDY  P1.04  (GPIO input, active-low data-ready interrupt)
 *   - RESET P1.05  (GPIO output, active low, optional)
 *
 * These pins do NOT overlap the AD8232 interface:
 *   AD8232: AIN0=P0.02, LO+=P1.13, LO-=P1.15, SDN=P1.14
 *   UART:   RX=P0.12, TX=P0.13
 */
#ifndef WALKEEG_ADS1293_H_
#define WALKEEG_ADS1293_H_

#include <stdint.h>
#include <zephyr/devicetree.h>

/* Available only when enabled in Kconfig AND the board overlay defines
 * an ads1293 SPI node (nrf52840dk does). Other boards fall back to the
 * AD8232 SAADC path automatically. */
#if defined(CONFIG_WALKEEG_USE_ADS1293) && DT_NODE_EXISTS(DT_NODELABEL(ads1293))
#define WALKEEG_ADS1293_AVAILABLE 1
#else
#define WALKEEG_ADS1293_AVAILABLE 0
#endif

#define ADS1293_NUM_CH   3

/** One ADS1293 acquisition: 3 ECG channels + lead-off flags. */
struct ads1293_sample {
	uint32_t ch[ADS1293_NUM_CH]; /* raw 24-bit offset-binary code (0..0xFFFFFF) */
	uint8_t lod;                /* ERROR_LOD: bit0=IN1 ... bit5=IN6 (1 = lead off) */
};

/** Configure SPI/GPIO and program the ADS1293 registers. Call once at boot. */
int walkeeg_ads1293_init(void);

/** Wait for the next DRDY assertion (data ready). Returns 0 on success. */
int walkeeg_ads1293_wait(int32_t timeout_ms);

/** Blocking read of the latest 3-channel sample. Returns 0 on success. */
int walkeeg_ads1293_read(struct ads1293_sample *s);

#endif /* WALKEEG_ADS1293_H_ */
