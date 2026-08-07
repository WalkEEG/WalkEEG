/*
 * WalkEEG debug peripheral for QingFeng nRF52832 board
 *
 * Role: BLE peripheral with NUS service.
 *       Receives commands from a phone app over BLE NUS,
 *       decodes them using the BALANX2-style protocol
 *       (first byte = command type, switch dispatch),
 *       and prints decoded business info over UART0
 *       (CH340 USB-UART bridge -> PC serial console).
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#include <zephyr/types.h>
#include <zephyr/kernel.h>
#include <zephyr/drivers/uart.h>

#include <zephyr/device.h>
#include <zephyr/devicetree.h>

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/hci.h>

#include <bluetooth/services/nus.h>

#include <zephyr/settings/settings.h>

#include <stdio.h>
#include <string.h>

#include <zephyr/logging/log.h>

LOG_MODULE_REGISTER(walkeeg_peripheral);

#define DEVICE_NAME CONFIG_BT_DEVICE_NAME
#define DEVICE_NAME_LEN (sizeof(DEVICE_NAME) - 1)

/* ------------------------------------------------------------------ */
/* BALANX2 protocol constants (from BALANX2_FIRMWARE/src/ble_event.h)  */
/* ------------------------------------------------------------------ */

#define CMD_PREPARE_FINISH            0x00
#define CMD_DEVICE_START              0x01
#define CMD_DEVICE_STOP               0x04
#define CMD_SET_CHANNEL_INTENSITY     0x06
#define CMD_SET_WAVE_MODE             0x07
#define CMD_SET_CHANNEL_FREQUENCY     0x09
#define CMD_SET_INTENSITY_STEP_FIRST5 0x0b
#define CMD_SET_IMPULSE_TIME          0x0c
#define CMD_SET_INTENSITY_STEP_LAST5  0x0d
#define CMD_SET_RELAX_MODE            0x0f
#define CMD_GET_DEVICE_VISION         0x10
#define NOTIFY_BAT_LOW                0x11
#define CMD_GET_ELECTRIC_CHARGE       0x12
#define CMD_SET_TEST_MODE             0x13
#define CMD_LOCK_RUNNING              0x14
#define CMD_GET_TEMP                  0x15
#define CMD_TEMP_HIGH                 0x16
#define CMD_OFFLINE_MODE_ENABLE       0x17
#define CMD_OFFLINE_MODE_DISABLE      0x18
#define CMD_GET_OFFLINE_TIME          0x19
#define CMD_CHECK_OFFLINE_MODE        0x20
#define CMD_DEVICE_PAUSE              0x21
#define CMD_GET_IMPEDANCE             0x22

#define CMD_BOOTLOADER_HEAD           0x1c

#define TRAIN_MODE_IMPULSE  0x01
#define TRAIN_MODE_STEADY   0x02
#define TRAIN_MODE_STOP     0x03

/* ------------------------------------------------------------------ */
/* Decode helpers                                                      */
/* ------------------------------------------------------------------ */

static const char *cmd_name(uint8_t cmd)
{
	switch (cmd) {
	case CMD_PREPARE_FINISH:            return "PREPARE_FINISH";
	case CMD_DEVICE_START:              return "DEVICE_START";
	case CMD_DEVICE_STOP:               return "DEVICE_STOP";
	case CMD_SET_CHANNEL_INTENSITY:     return "SET_CHANNEL_INTENSITY";
	case CMD_SET_WAVE_MODE:             return "SET_WAVE_MODE";
	case CMD_SET_CHANNEL_FREQUENCY:     return "SET_CHANNEL_FREQUENCY";
	case CMD_SET_INTENSITY_STEP_FIRST5: return "SET_INTENSITY_STEP_FIRST5";
	case CMD_SET_IMPULSE_TIME:          return "SET_IMPULSE_TIME";
	case CMD_SET_INTENSITY_STEP_LAST5:  return "SET_INTENSITY_STEP_LAST5";
	case CMD_SET_RELAX_MODE:            return "SET_RELAX_MODE";
	case CMD_GET_DEVICE_VISION:         return "GET_DEVICE_VISION";
	case NOTIFY_BAT_LOW:                return "NOTIFY_BAT_LOW";
	case CMD_GET_ELECTRIC_CHARGE:       return "GET_ELECTRIC_CHARGE";
	case CMD_SET_TEST_MODE:             return "SET_TEST_MODE";
	case CMD_LOCK_RUNNING:              return "LOCK_RUNNING";
	case CMD_GET_TEMP:                  return "GET_TEMP";
	case CMD_TEMP_HIGH:                 return "TEMP_HIGH";
	case CMD_OFFLINE_MODE_ENABLE:       return "OFFLINE_MODE_ENABLE";
	case CMD_OFFLINE_MODE_DISABLE:      return "OFFLINE_MODE_DISABLE";
	case CMD_GET_OFFLINE_TIME:          return "GET_OFFLINE_TIME";
	case CMD_CHECK_OFFLINE_MODE:        return "CHECK_OFFLINE_MODE";
	case CMD_DEVICE_PAUSE:              return "DEVICE_PAUSE";
	case CMD_GET_IMPEDANCE:             return "GET_IMPEDANCE";
	case CMD_BOOTLOADER_HEAD:           return "BOOTLOADER";
	default:                            return "UNKNOWN";
	}
}

static const char *train_mode_name(uint8_t mode)
{
	switch (mode) {
	case TRAIN_MODE_IMPULSE: return "IMPULSE";
	case TRAIN_MODE_STEADY:  return "STEADY";
	case TRAIN_MODE_STOP:    return "STOP";
	default:                 return "?";
	}
}

/* Print a hex dump of the raw frame, then the decoded fields. */
static void decode_and_print(const uint8_t *data, uint16_t len)
{
	uint8_t cmd;
	uint16_t i;

	LOG_INF("==== RX %u bytes ====", len);

	/* Raw hex dump */
	for (i = 0; i < len; i++) {
		LOG_INF("  [%02u] 0x%02X", i, data[i]);
	}

	if (len < 1) {
		LOG_WRN("Empty frame, nothing to decode");
		return;
	}

	cmd = data[0];
	LOG_INF("CMD 0x%02X %s", cmd, cmd_name(cmd));

	switch (cmd) {
	case CMD_PREPARE_FINISH:
		LOG_INF("  prepare finished");
		break;

	case CMD_DEVICE_START:
		if (len >= 2) {
			LOG_INF("  train_mode=0x%02X (%s)",
				data[1], train_mode_name(data[1]));
		}
		break;

	case CMD_DEVICE_STOP:
		if (len >= 2) {
			LOG_INF("  train_mode=0x%02X (%s)",
				data[1], train_mode_name(data[1]));
		}
		break;

	case CMD_DEVICE_PAUSE:
		LOG_INF("  device paused");
		break;

	case CMD_SET_CHANNEL_INTENSITY: {
		/* 10 channels, data[1]..data[10] */
		for (i = 1; i <= 10 && i < len; i++) {
			uint16_t intensity = (data[i] << 8) + (data[i] << 6) +
					     (data[i] << 2) + data[i];
			LOG_INF("  ch%u intensity=0x%02X (%u)",
				i, data[i], intensity);
		}
		break;
	}

	case CMD_SET_WAVE_MODE:
		if (len >= 2) {
			LOG_INF("  wave_mode=0x%02X", data[1]);
		}
		break;

	case CMD_SET_CHANNEL_FREQUENCY:
		if (len >= 3) {
			LOG_INF("  freq_high=0x%02X freq_low=0x%02X",
				data[1], data[2]);
		}
		break;

	case CMD_SET_INTENSITY_STEP_FIRST5: {
		/* channels 1..5, each step is 2 bytes: data[2i-1], data[2i] */
		for (i = 1; i <= 5; i++) {
			uint8_t hi = (2 * i - 1 < len) ? data[2 * i - 1] : 0;
			uint8_t lo = (2 * i < len) ? data[2 * i] : 0;
			LOG_INF("  ch%u step_hi=0x%02X step_lo=0x%02X",
				i, hi, lo);
		}
		break;
	}

	case CMD_SET_INTENSITY_STEP_LAST5: {
		/* channels 6..10, data[1]..data[10] */
		for (i = 1; i <= 10 && i < len; i++) {
			LOG_INF("  ch%u step_hi=0x%02X", i + 5, data[i]);
		}
		break;
	}

	case CMD_SET_IMPULSE_TIME:
		if (len >= 4) {
			uint16_t hold = (data[2] << 11) + (data[2] << 9) -
					(data[2] << 6) + (data[2] << 2);
			uint16_t stop = (data[3] << 9) + (data[3] << 8) +
					(data[3] << 7) + (data[3] << 6) +
					(data[3] << 5) + (data[3] << 3);
			LOG_INF("  hold_time=%u stop_time=%u", hold, stop);
		}
		break;

	case CMD_SET_RELAX_MODE:
		LOG_INF("  relax mode set");
		break;

	case CMD_GET_DEVICE_VISION:
		LOG_INF("  firmware version request");
		break;

	case NOTIFY_BAT_LOW:
		LOG_INF("  battery low notification");
		break;

	case CMD_GET_ELECTRIC_CHARGE:
		LOG_INF("  battery charge request");
		break;

	case CMD_SET_TEST_MODE:
		LOG_INF("  test mode");
		break;

	case CMD_LOCK_RUNNING:
		LOG_INF("  lock running");
		break;

	case CMD_GET_TEMP:
		LOG_INF("  temperature request");
		break;

	case CMD_TEMP_HIGH:
		LOG_INF("  temperature high");
		break;

	case CMD_OFFLINE_MODE_ENABLE:
		if (len >= 3) {
			uint16_t secs = (data[1] << 2) + (data[1] << 3) +
					(data[1] << 4) + (data[1] << 5) +
					data[2];
			LOG_INF("  offline remain=%u s", secs);
		}
		break;

	case CMD_OFFLINE_MODE_DISABLE:
		LOG_INF("  offline mode disabled");
		break;

	case CMD_GET_OFFLINE_TIME:
		LOG_INF("  offline time request");
		break;

	case CMD_CHECK_OFFLINE_MODE:
		LOG_INF("  offline mode check");
		break;

	case CMD_GET_IMPEDANCE:
		LOG_INF("  impedance request");
		break;

	case CMD_BOOTLOADER_HEAD:
		if (len >= 5 && data[1] == 0x1d && data[2] == 0x14 &&
		    data[3] == 0x31 && data[4] == 0x3c) {
			LOG_INF("  [bootloader magic match]");
		} else {
			LOG_INF("  [bootloader header, no magic]");
		}
		break;

	default:
		LOG_INF("  (no field decode for this command)");
		break;
	}

	LOG_INF("==== end ====");
}

/* ------------------------------------------------------------------ */
/* BLE glue                                                            */
/* ------------------------------------------------------------------ */

static struct bt_conn *current_conn;
static struct k_work adv_work;

static const struct bt_data ad[] = {
	BT_DATA_BYTES(BT_DATA_FLAGS, (BT_LE_AD_GENERAL | BT_LE_AD_NO_BREDR)),
	BT_DATA(BT_DATA_NAME_COMPLETE, DEVICE_NAME, DEVICE_NAME_LEN),
};

static const struct bt_data sd[] = {
	BT_DATA_BYTES(BT_DATA_UUID128_ALL, BT_UUID_NUS_VAL),
};

static void adv_work_handler(struct k_work *work)
{
	int err = bt_le_adv_start(BT_LE_ADV_CONN_FAST_2, ad, ARRAY_SIZE(ad),
				  sd, ARRAY_SIZE(sd));

	if (err) {
		LOG_ERR("Advertising failed to start (err %d)", err);
		return;
	}

	LOG_INF("Advertising successfully started");
}

static void advertising_start(void)
{
	k_work_submit(&adv_work);
}

static void connected(struct bt_conn *conn, uint8_t err)
{
	char addr[BT_ADDR_LE_STR_LEN];

	if (err) {
		LOG_ERR("Connection failed, err 0x%02x %s", err,
			bt_hci_err_to_str(err));
		return;
	}

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
	LOG_INF("Connected %s", addr);

	current_conn = bt_conn_ref(conn);
}

static void disconnected(struct bt_conn *conn, uint8_t reason)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
	LOG_INF("Disconnected: %s, reason 0x%02x %s", addr, reason,
		bt_hci_err_to_str(reason));

	if (current_conn) {
		bt_conn_unref(current_conn);
		current_conn = NULL;
	}
}

static void recycled_cb(void)
{
	LOG_INF("Connection object recycled, restart advertising");
	advertising_start();
}

BT_CONN_CB_DEFINE(conn_callbacks) = {
	.connected    = connected,
	.disconnected = disconnected,
	.recycled     = recycled_cb,
};

/* NUS RX: phone app -> board. Decode and print. */
static void bt_receive_cb(struct bt_conn *conn, const uint8_t *const data,
			  uint16_t len)
{
	char addr[BT_ADDR_LE_STR_LEN] = {0};

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, ARRAY_SIZE(addr));
	LOG_INF("RX from %s", addr);

	decode_and_print(data, len);
}

static struct bt_nus_cb nus_cb = {
	.received = bt_receive_cb,
};

void error(void)
{
	LOG_ERR("Fatal error, halting");
	while (true) {
		k_sleep(K_MSEC(1000));
	}
}

int main(void)
{
	int err;

	err = bt_enable(NULL);
	if (err) {
		error();
	}

	LOG_INF("Bluetooth initialized");

	if (IS_ENABLED(CONFIG_SETTINGS)) {
		settings_load();
	}

	err = bt_nus_init(&nus_cb);
	if (err) {
		LOG_ERR("Failed to initialize NUS service (err: %d)", err);
		return 0;
	}

	k_work_init(&adv_work, adv_work_handler);
	advertising_start();

	for (;;) {
		k_sleep(K_MSEC(1000));
	}
}
