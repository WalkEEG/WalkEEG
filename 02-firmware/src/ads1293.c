/*
 * WalkEEG TI ADS1293 3-channel ECG AFE driver (SPI).
 *
 * Config: 3-lead ECG (Lead I/II/III), 533 sps.
 *   fS = 102.4 kHz (AFE_RES FS_HIGH=0), R1=4, R2=4, R3=12
 *   ODR = 102400 / (4 * 4 * 12) = 533.3 Hz, BW ~105 Hz
 *
 * SPI: mode 0 (CPOL=0/CPHA=0), MSB first, 8-bit words.
 * Every access = 8-bit command (bit7 R/WB, bits6-0 addr) + data byte(s).
 * Data readback uses streaming mode via DATA_LOOP (0x50): one command
 * byte + N data bytes with CS held (auto-increment, stops at 0x4F).
 *
 * DRDYB: active-low; asserted when new data is ready; deasserted on the
 * 14th rising SCLK edge of an ECG/PACE read. Data must be read before
 * the next DRDYB assertion or it is lost.
 */

#include "ads1293.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/drivers/spi.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(walkeeg_ads1293, LOG_LEVEL_INF);

#define ADS1293_NODE DT_NODELABEL(ads1293)

#if DT_NODE_EXISTS(ADS1293_NODE)

/* ---- Register map (SNAS602C) ---- */
#define REG_CONF         0x00 /* [2] PWR_DOWN [1] STANDBY [0] START_CON */
#define REG_FLEX_CH1_CN  0x01 /* [7:6] TST1 [5:3] POS1 [2:0] NEG1 */
#define REG_FLEX_CH2_CN  0x02 /* [7:6] TST2 [5:3] POS2 [2:0] NEG2 */
#define REG_FLEX_CH3_CN  0x03 /* [7:6] TST3 [5:3] POS3 [2:0] NEG3 */
#define REG_LOD_CN       0x06 /* lead-off control (default 0x08 = shutdown) */
#define REG_LOD_EN       0x07 /* lead-off detect enable */
#define REG_CMDET_EN     0x0A /* common-mode detect enable */
#define REG_RLD_CN       0x0C /* right-leg drive control */
#define REG_REF_CN       0x11 /* internal 2.4V ref control */
#define REG_OSC_CN       0x12 /* [2] STRTCLK [1] SHDN_OSC [0] EN_CLKOUT */
#define REG_AFE_RES      0x13 /* [5:3] FS_HIGH_CHx [2:0] EN_HIRES_CHx */
#define REG_AFE_SHDN_CN  0x14 /* shutdown SDM/INA per channel */
#define REG_AFE_PACE_CN  0x17 /* pace channel routing/shutdown */
#define REG_ERROR_LOD    0x18 /* lead-off error status (RO) */
#define REG_R2_RATE      0x21 /* 0001=4 0010=5 0100=6 1000=8 */
#define REG_R3_RATE_CH1  0x22 /* 0001=4 0010=6 0100=8 1000=12 ... */
#define REG_R3_RATE_CH2  0x23
#define REG_R3_RATE_CH3  0x24
#define REG_R1_RATE      0x25 /* [2:0] per-channel R1=2 (double pace) */
#define REG_DRDYB_SRC    0x27 /* 000001..100000 = CH1pace..CH3ECG */
#define REG_CH_CNFG      0x2F /* loop read-back enables */
#define REG_DATA_LOOP    0x50 /* streaming read-back address */

/* CONFIG */
#define CONF_START_CON   0x01

/* DRDYB_SRC values */
#define DRDYB_SRC_CH1_ECG 0x08

/* CH_CNFG: enable ECG data for loop read-back (E3|E2|E1) */
#define CH_CNFG_ECG_ALL   0x70

static const struct device *spi_dev;

static struct spi_cs_control spi_cs = SPI_CS_CONTROL_INIT(ADS1293_NODE, 0);

static struct spi_config spi_cfg = {
	.frequency = 4000000, /* well below 20 MHz max */
	.operation = SPI_OP_MODE_MASTER | SPI_WORD_SET(8) | SPI_TRANSFER_MSB,
	.cs = &spi_cs,
};

/* DRDYB: active-low data-ready interrupt */
static struct gpio_callback drdy_cb_data;
static K_SEM_DEFINE(drdy_sem, 0, 4);

static void drdy_cb(const struct device *dev, struct gpio_callback *cb,
		    gpio_port_pins_t pins)
{
	k_sem_give(&drdy_sem);
}

static int ads1293_reg_write(uint8_t addr, uint8_t val)
{
	uint8_t tx[2] = { addr, val };
	struct spi_buf buf = { .buf = tx, .len = sizeof(tx) };
	struct spi_buf_set set = { .buffers = &buf, .count = 1 };

	return spi_write(spi_dev, &spi_cfg, &set);
}

static int ads1293_reg_read(uint8_t addr, uint8_t *val)
{
	uint8_t tx[2] = { (uint8_t)(addr | 0x80), 0 };
	uint8_t rx[2] = { 0, 0 };
	struct spi_buf tbuf = { .buf = tx, .len = sizeof(tx) };
	struct spi_buf rbuf = { .buf = rx, .len = sizeof(rx) };
	struct spi_buf_set tset = { .buffers = &tbuf, .count = 1 };
	struct spi_buf_set rset = { .buffers = &rbuf, .count = 1 };
	int err = spi_transceive(spi_dev, &spi_cfg, &tset, &rset);

	if (err == 0) {
		*val = rx[1];
	}

	return err;
}

int walkeeg_ads1293_wait(int32_t timeout_ms)
{
	return k_sem_take(&drdy_sem, K_MSEC(timeout_ms)) == 0 ? 0 : -EAGAIN;
}

int walkeeg_ads1293_read(struct ads1293_sample *s)
{
	/* Streaming read: cmd (0x80|0x50) + 9 bytes (3 ch x 24-bit, MSB first) */
	uint8_t tx[10] = { REG_DATA_LOOP | 0x80, 0, 0, 0, 0, 0, 0, 0, 0, 0 };
	uint8_t rx[10] = { 0 };
	struct spi_buf tbuf = { .buf = tx, .len = sizeof(tx) };
	struct spi_buf rbuf = { .buf = rx, .len = sizeof(rx) };
	struct spi_buf_set tset = { .buffers = &tbuf, .count = 1 };
	struct spi_buf_set rset = { .buffers = &rbuf, .count = 1 };
	uint8_t lod = 0;
	int err;
	int c;

	err = spi_transceive(spi_dev, &spi_cfg, &tset, &rset);
	if (err) {
		return err;
	}

	for (c = 0; c < ADS1293_NUM_CH; c++) {
		const uint8_t *p = &rx[1 + c * 3];

		/* Offset-binary 24-bit code: 0V differential input = 0x400000
		 * (ADCOUT = ADCMAX/2 for 0V, ADCMAX = 0x800000 for this filter
		 * configuration). Keep the raw unsigned code; the caller may
		 * center it: signed = (int32_t)(raw - 0x400000).
		 */
		s->ch[c] = ((uint32_t)p[0] << 16) | ((uint32_t)p[1] << 8) | p[2];
	}

	/* Lead-off status (bit0=IN1 .. bit5=IN6, 1 = lead off) */
	err = ads1293_reg_read(REG_ERROR_LOD, &lod);
	s->lod = (err == 0) ? lod : 0;

	return 0;
}

int walkeeg_ads1293_init(void)
{
	const struct gpio_dt_spec drdy =
		GPIO_DT_SPEC_GET(ADS1293_NODE, drdy_gpios);
	const struct gpio_dt_spec reset =
		GPIO_DT_SPEC_GET_OR(ADS1293_NODE, reset_gpios, { 0 });
	struct ads1293_sample dummy;
	int err;
	int i;

	spi_dev = DEVICE_DT_GET(DT_BUS(ADS1293_NODE));
	if (!device_is_ready(spi_dev)) {
		LOG_ERR("SPI device not ready");
		return -ENODEV;
	}

	if (!gpio_is_ready_dt(&drdy)) {
		LOG_ERR("DRDY GPIO not ready");
		return -ENODEV;
	}

	/* Hardware reset (active low) if wired */
	if (reset.port != NULL) {
		err = gpio_pin_configure_dt(&reset, GPIO_OUTPUT_ACTIVE);
		if (err) {
			LOG_ERR("RESET config failed: %d", err);
			return err;
		}
		k_sleep(K_MSEC(2));
		gpio_pin_set_dt(&reset, 0); /* release reset */
		k_sleep(K_MSEC(2));
	}

	/* DRDYB falling edge -> semaphore */
	gpio_init_callback(&drdy_cb_data, drdy_cb, BIT(drdy.pin));
	err = gpio_pin_configure_dt(&drdy, GPIO_INPUT);
	if (err) {
		LOG_ERR("DRDY config failed: %d", err);
		return err;
	}
	err = gpio_pin_interrupt_configure_dt(&drdy, GPIO_INT_EDGE_TO_ACTIVE);
	if (err) {
		LOG_ERR("DRDY interrupt config failed: %d", err);
		return err;
	}
	gpio_add_callback(drdy.port, &drdy_cb_data);

	/* ---- Register programming (3-lead ECG, 533 sps) ----
	 * Order matters: registers 0x11/0x12/0x13/0x21-0x29 are locked
	 * once START_CON=1, so program everything before starting.
	 */
	err  = ads1293_reg_write(REG_CONF, 0x00);          /* exit standby */
	err |= ads1293_reg_write(REG_FLEX_CH1_CN, 0x11);   /* Lead I:  IN2-IN1 (LA-RA) */
	err |= ads1293_reg_write(REG_FLEX_CH2_CN, 0x19);   /* Lead II: IN3-IN1 (LL-RA) */
	err |= ads1293_reg_write(REG_FLEX_CH3_CN, 0x1A);   /* Lead III:IN3-IN2 (LL-LA) */
	err |= ads1293_reg_write(REG_CMDET_EN, 0x07);      /* CMDET on IN1/IN2/IN3 */
	err |= ads1293_reg_write(REG_RLD_CN, 0x04);        /* RLD amp out -> IN4 */
	err |= ads1293_reg_write(REG_REF_CN, 0x00);        /* internal 2.4V ref on */
	err |= ads1293_reg_write(REG_OSC_CN, 0x00);        /* osc on, clock gated */
	if (err) {
		LOG_ERR("ADS1293 config failed (pre-OSC): %d", err);
		return err;
	}

	k_sleep(K_MSEC(20)); /* crystal start-up ~15 ms */

	err  = ads1293_reg_write(REG_OSC_CN, 0x04);        /* STRTCLK=1 */
	err |= ads1293_reg_write(REG_AFE_RES, 0x00);       /* FS=102.4kHz, low-power */
	err |= ads1293_reg_write(REG_AFE_SHDN_CN, 0x00);   /* all channels on */
	err |= ads1293_reg_write(REG_R2_RATE, 0x01);       /* R2=4 */
	err |= ads1293_reg_write(REG_R3_RATE_CH1, 0x08);   /* R3=12 */
	err |= ads1293_reg_write(REG_R3_RATE_CH2, 0x08);
	err |= ads1293_reg_write(REG_R3_RATE_CH3, 0x08);
	err |= ads1293_reg_write(REG_R1_RATE, 0x00);       /* R1=4 (standard) */
	err |= ads1293_reg_write(REG_DRDYB_SRC, DRDYB_SRC_CH1_ECG);
	err |= ads1293_reg_write(REG_CH_CNFG, CH_CNFG_ECG_ALL);
	if (err) {
		LOG_ERR("ADS1293 config failed: %d", err);
		return err;
	}

	/* Verify SPI comms: REVID (0x40) reads back 0x01 */
	{
		uint8_t revid = 0;

		err = ads1293_reg_read(0x40, &revid);
		if (err) {
			LOG_WRN("REVID read failed: %d", err);
		} else if (revid != 0x01) {
			LOG_WRN("Unexpected REVID 0x%02x (SPI wiring?)", revid);
		} else {
			LOG_INF("ADS1293 REVID=0x%02x (SPI OK)", revid);
		}
	}

	/* Start conversion (locks 0x11/0x12/0x13/0x21-0x29) */
	err = ads1293_reg_write(REG_CONF, CONF_START_CON);
	if (err) {
		LOG_ERR("ADS1293 start failed: %d", err);
		return err;
	}

	/* DRDYB is masked for the first 6 ECG samples; drain them */
	for (i = 0; i < 8; i++) {
		if (k_sem_take(&drdy_sem, K_MSEC(50)) == 0) {
			walkeeg_ads1293_read(&dummy);
		}
	}

	LOG_INF("ADS1293 init OK (3-lead ECG, 533 sps, DRDY P1.%u)",
		drdy.pin);
	return 0;
}

#endif /* DT_NODE_EXISTS(ADS1293_NODE) */
