/*
 * WalkEEG AD8232 ECG sampling over the nRF SAADC-compatible ADC.
 *
 * Board configuration via device tree (see boards/<board>.overlay):
 *   - ADC channel: defined under &adc (channel@0), consumed through the
 *     "walkeeg,ecg-pins" node's io-channels property.
 *       nRF52840 (青风 board) : AIN0 = P0.02, gain 1/6  (0..3.6 V)
 *       nRF54L15-DK (proposal): AIN4 = P1.11, gain 1/4  (~3.6 V)
 *   - LO+/LO-/SDN GPIOs come from the same walkeeg,ecg-pins node.
 *
 * If the walkeeg,ecg-pins node is absent (boards not yet adapted), the
 * module falls back to the legacy hardcoded nRF52840 青风 board pins
 * (LO+ P1.13, LO- P1.15, SDN P1.14, AIN0 = P0.02, gain 1/6) so the
 * previous behaviour is preserved.
 *
 * Note: on nRF54L15 the ADC input must be specified as the AIN index
 * (NRF_SAADC_AINx from <zephyr/dt-bindings/adc/nrf-saadc.h>); the nrfx
 * layer maps it to the P1 pin (AIN0=P1.04 .. AIN4=P1.11 .. AIN7=P1.14).
 */

#include "adc_sample.h"

#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/drivers/adc.h>
#include <zephyr/drivers/gpio.h>
#include <zephyr/dt-bindings/adc/nrf-saadc.h>
#include <zephyr/logging/log.h>
#include <string.h>

LOG_MODULE_REGISTER(walkeeg_adc, LOG_LEVEL_INF);

#define ADC_RES   12

static int16_t adc_buf;
static struct adc_sequence adc_seq = {
	.buffer      = &adc_buf,
	.buffer_size = sizeof(adc_buf),
	.resolution  = ADC_RES,
	.oversampling = 4,   /* average 16 samples -> less noise */
};

#if DT_HAS_COMPAT_STATUS_OKAY(walkeeg_ecg_pins)
/* ------------------------------------------------------------------ *
 * DT-driven configuration (boards with a walkeeg,ecg-pins node).     *
 * ------------------------------------------------------------------ */
#define ECG_PINS_NODE DT_COMPAT_GET_OKAY(walkeeg_ecg_pins)

static const struct adc_dt_spec adc_spec = ADC_DT_SPEC_GET(ECG_PINS_NODE);

static const struct gpio_dt_spec lo_plus_gpio  =
	GPIO_DT_SPEC_GET(ECG_PINS_NODE, lo_plus_gpios);
static const struct gpio_dt_spec lo_minus_gpio =
	GPIO_DT_SPEC_GET(ECG_PINS_NODE, lo_minus_gpios);
static const struct gpio_dt_spec sdn_gpio      =
	GPIO_DT_SPEC_GET(ECG_PINS_NODE, sdn_gpios);

static int ecg_gpio_init(void)
{
	int err;

	/* SDN: output high -> AD8232 enabled */
	err = gpio_pin_configure_dt(&sdn_gpio, GPIO_OUTPUT_ACTIVE);
	if (err) {
		LOG_ERR("SDN config failed: %d", err);
		return err;
	}

	/* LO+/LO-: inputs; pull-up comes from the DT flags */
	err = gpio_pin_configure_dt(&lo_plus_gpio, GPIO_INPUT);
	if (err) {
		LOG_ERR("LO+ config failed: %d", err);
		return err;
	}

	err = gpio_pin_configure_dt(&lo_minus_gpio, GPIO_INPUT);
	if (err) {
		LOG_ERR("LO- config failed: %d", err);
		return err;
	}

	LOG_INF("WalkEEG ECG GPIO init OK (LO+ P1.%u, LO- P1.%u, SDN P1.%u)",
		lo_plus_gpio.pin, lo_minus_gpio.pin, sdn_gpio.pin);
	return 0;
}

static int ecg_adc_init(void)
{
	int err;

	if (!device_is_ready(adc_spec.dev)) {
		LOG_ERR("ADC device not ready");
		return -ENODEV;
	}

	err = adc_channel_setup_dt(&adc_spec);
	if (err) {
		LOG_ERR("adc_channel_setup_dt failed: %d", err);
		return err;
	}

	adc_seq.channels = BIT(adc_spec.channel_id);

	LOG_INF("WalkEEG ADC init OK (ch %u, AIN idx %d, gain %d, ref %d)",
		(unsigned)adc_spec.channel_id, adc_spec.input_positive,
		(int)adc_spec.gain, (int)adc_spec.reference);
	return 0;
}

static int ecg_read(struct walkeeg_adc_sample *s)
{
	int err;

	err = adc_read_dt(&adc_spec, &adc_seq);
	if (err) {
		return err;
	}

	s->value = adc_buf;
	s->lo_plus  = gpio_pin_get_dt(&lo_plus_gpio) > 0;
	s->lo_minus = gpio_pin_get_dt(&lo_minus_gpio) > 0;

	return 0;
}
#else
/* ------------------------------------------------------------------ *
 * Legacy fallback: hardcoded 青风 nRF52840 board pins.                *
 * ------------------------------------------------------------------ */

#define AIN0_NODE  DT_NODELABEL(adc)

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
	.input_positive   = NRF_SAADC_AIN0,
};

static int ecg_gpio_init(void)
{
	/* GPIO1 for P1.13 / P1.14 / P1.15 */
	gpio1_dev = DEVICE_DT_GET(GPIO1_NODE);
	if (!device_is_ready(gpio1_dev)) {
		LOG_ERR("gpio1 not ready");
		return -ENODEV;
	}

	/* SDN: output high -> AD8232 enabled */
	int err = gpio_pin_configure(gpio1_dev, SDN_PIN, GPIO_OUTPUT_ACTIVE);

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

	return 0;
}

static int ecg_adc_init(void)
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

	adc_seq.channels = BIT(adc_cfg.channel_id);

	return 0;
}

static int ecg_read(struct walkeeg_adc_sample *s)
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
#endif /* DT_HAS_COMPAT_STATUS_OKAY(walkeeg_ecg_pins) */

int walkeeg_adc_init(void)
{
	int err;

	err = ecg_adc_init();
	if (err) {
		return err;
	}

	err = ecg_gpio_init();
	if (err) {
		return err;
	}

	LOG_INF("WalkEEG ADC init OK");
	return 0;
}

int walkeeg_adc_read(struct walkeeg_adc_sample *s)
{
	return ecg_read(s);
}
