/*
 * WalkEEG AD8232 ECG sampling over SAADC (nRF52840).
 */

#include "adc_sample.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/logging/log.h>
#include <nrfx_saadc.h>
#include <string.h>

LOG_MODULE_REGISTER(walkeeg_adc, LOG_LEVEL_INF);

/* ---- Pin map (青风 nRF52840 board, P13 header) ----
 *  OUTPUT  P13 pin 8  -> P0.02  (AIN0)
 *  LO+     P13 pin 4  -> P1.13
 *  LO-     P13 pin 6  -> P1.15
 *  SDN     P13 pin 5  -> P1.14
 */

#define AIN0_NODE  DT_NODELABEL(adc)
#define ADC_RES   12

#define LO_PLUS_PIN  13
#define LO_MINUS_PIN 15
#define SDN_PIN      14

/* GPIO port for P1.x (second GPIO controller) */
#define GPIO1_NODE  DT_NODELABEL(gpio1)

static const struct device *adc_dev;
static const struct device *gpio1_dev;

/* ADC channel: AIN0 = P0.02, gain 1/6, internal 0.6 V ref (see overlay) */
static const struct adc_channel_cfg adc_cfg = {
	.gain             = ADC_GAIN_1_6,
	.reference        = ADC_REF_INTERNAL,
	.acquisition_time = ADC_ACQ_TIME_DEFAULT,
	.channel_id       = 0,
	.input_positive   = NRF_SAADC_INPUT_AIN0,
};

static int16_t adc_buf;
static struct adc_sequence adc_seq = {
	.channels    = BIT(0),
	.buffer      = &adc_buf,
	.buffer_size = sizeof(adc_buf),
	.resolution  = ADC_RES,
	.oversampling = 4,   /* average 16 samples -> less noise */
};

int walkeeg_adc_init(void)
{
	int err;

	adc_dev = DEVICE_DT_GET(AIN0_NODE);
	if (!device_is_ready(adc_dev)) {
		LOG_ERR("ADC device not ready");
		return -ENODEV;
	}

	err = adc_channel_setup(adc_dev, &adc_cfg);
	if (err) {
		LOG_ERR("adc_channel_setup failed: %d", err);
		return err;
	}

	/* GPIO1 for P1.13 / P1.14 / P1.15 */
	gpio1_dev = DEVICE_DT_GET(GPIO1_NODE);
	if (!device_is_ready(gpio1_dev)) {
		LOG_ERR("gpio1 not ready");
		return -ENODEV;
	}

	/* SDN: output high -> AD8232 enabled */
	err = gpio_pin_configure(gpio1_dev, SDN_PIN, GPIO_OUTPUT_ACTIVE);
	if (err) {
		LOG_ERR("SDN config failed: %d", err);
		return err;
	}

	/* LO+/LO-: inputs with pull-up (AD8232 drives low when lead off) */
	err = gpio_pin_configure(gpio1_dev, LO_PLUS_PIN, GPIO_INPUT | GPIO_PULL_UP);
	if (err) {
		LOG_ERR("LO+ config failed: %d", err);
		return err;
	}

	err = gpio_pin_configure(gpio1_dev, LO_MINUS_PIN, GPIO_INPUT | GPIO_PULL_UP);
	if (err) {
		LOG_ERR("LO- config failed: %d", err);
		return err;
	}

	LOG_INF("WalkEEG ADC init OK (AIN0, LO+ P1.13, LO- P1.15, SDN P1.14)");
	return 0;
}

int walkeeg_adc_read(struct walkeeg_adc_sample *s)
{
	int err;

	if (!adc_dev) {
		return -ENODEV;
	}

	err = adc_read(adc_dev, &adc_seq);
	if (err) {
		return err;
	}

	s->value = adc_buf;
	s->lo_plus  = gpio_pin_get(gpio1_dev, LO_PLUS_PIN) > 0;
	s->lo_minus = gpio_pin_get(gpio1_dev, LO_MINUS_PIN) > 0;

	return 0;
}
