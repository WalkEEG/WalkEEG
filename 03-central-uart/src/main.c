/*
 * WalkEEG Central - nRF52832 BLE central that connects to the WalkEEG
 * peripheral (nRF52840), subscribes to NUS notifications, decodes the
 * WalkEEG 8-channel frame and prints decoded values over UART (USB-serial).
 *
 * Frame format (see 02-firmware/src/stream.c):
 *   A5 | 01 | seq(LE16) | n | flags | n x (8 x int16 LE)
 *
 * SPDX-License-Identifier: LicenseRef-Nordic-5-Clause
 */

#include <errno.h>
#include <zephyr/kernel.h>
#include <zephyr/device.h>
#include <zephyr/devicetree.h>
#include <zephyr/sys/byteorder.h>
#include <zephyr/sys/printk.h>

#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/hci.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/uuid.h>
#include <zephyr/bluetooth/gatt.h>

#include <bluetooth/services/nus.h>
#include <bluetooth/services/nus_client.h>
#include <bluetooth/gatt_dm.h>
#include <bluetooth/scan.h>

#include <zephyr/settings/settings.h>

#include <zephyr/drivers/uart.h>

#include <zephyr/logging/log.h>

#define LOG_MODULE_NAME walkeeg_central
LOG_MODULE_REGISTER(LOG_MODULE_NAME);

/* ---------------- WalkEEG frame format ---------------- */
#define WK_MAGIC        0xA5
#define WK_VERSION      0x01
#define WK_NUM_CHANNELS 8

/* ---------------- UART ---------------- */
static const struct device *uart = DEVICE_DT_GET(DT_CHOSEN(nordic_nus_uart));

/* ---------------- BLE state ---------------- */
static struct bt_conn *default_conn;
static struct bt_nus_client nus_client;
static struct k_work scan_work;

#define NUS_WRITE_TIMEOUT K_MSEC(150)

static void uart_send_str(const char *s)
{
	while (*s) {
		uart_poll_out(uart, (uint8_t)*s++);
	}
}

static void uart_send_int(int32_t v)
{
	char buf[16];
	int i = 0;
	bool neg = false;

	if (v < 0) {
		neg = true;
		v = -v;
	}

	if (v == 0) {
		buf[i++] = '0';
	} else {
		while (v > 0 && i < (int)sizeof(buf) - 1) {
			buf[i++] = (char)('0' + (v % 10));
			v /= 10;
		}
	}

	if (neg) {
		buf[i++] = '-';
	}

	while (i > 0) {
		uart_poll_out(uart, (uint8_t)buf[--i]);
	}
}

/*
 * Decode one WalkEEG frame and print each sample as:
 *   seq=<seq> <samp_idx> ch0 ch1 ... ch7  (all int16)
 */
static void decode_and_print(const uint8_t *data, uint16_t len)
{
	uint16_t pos = 0;
	uint16_t seq;
	uint8_t n;
	uint8_t flags;

	if (len < 6) {
		return;
	}

	if (data[0] != WK_MAGIC || data[1] != WK_VERSION) {
		LOG_WRN("Bad frame header: %02x %02x len=%u", data[0], data[1], len);
		return;
	}

	seq = sys_get_le16(&data[2]);
	n = data[4];
	flags = data[5];
	pos = 6;

	if (n == 0 || n > 20) {
		LOG_WRN("Bad sample count: %u", n);
		return;
	}

	if (len < pos + (uint16_t)n * WK_NUM_CHANNELS * 2) {
		LOG_WRN("Frame too short: len=%u need=%u n=%u", len,
			pos + n * WK_NUM_CHANNELS * 2, n);
		return;
	}

	for (uint8_t i = 0; i < n; i++) {
		uart_send_str("seq=");
		uart_send_int(seq);
		uart_send_str(" i=");
		uart_send_int(i);
		uart_send_str(" flags=");
		uart_send_int(flags);

		for (uint8_t ch = 0; ch < WK_NUM_CHANNELS; ch++) {
			int16_t v = (int16_t)sys_get_le16(&data[pos]);
			pos += 2;
			uart_send_str(" ");
			uart_send_int(v);
		}
		uart_send_str("\r\n");
	}
}

static uint8_t ble_data_received(struct bt_nus_client *nus,
				 const uint8_t *data, uint16_t len)
{
	ARG_UNUSED(nus);

	decode_and_print(data, len);

	/* Keep notifications enabled. */
	return BT_GATT_ITER_CONTINUE;
}

static void ble_data_sent(struct bt_nus_client *nus, uint8_t err,
			  const uint8_t *const data, uint16_t len)
{
	ARG_UNUSED(nus);
	ARG_UNUSED(data);
	ARG_UNUSED(len);

	if (err) {
		LOG_WRN("ATT error code: 0x%02X", err);
	}
}

/* ---------------- GATT discovery ---------------- */
static void discovery_complete(struct bt_gatt_dm *dm, void *context)
{
	struct bt_nus_client *nus = context;

	LOG_INF("Service discovery completed");

	bt_nus_handles_assign(dm, nus);
	bt_nus_subscribe_receive(nus);

	bt_gatt_dm_data_release(dm);
}

static void discovery_service_not_found(struct bt_conn *conn, void *context)
{
	LOG_INF("Service not found");
}

static void discovery_error(struct bt_conn *conn, int err, void *context)
{
	LOG_WRN("Error while discovering GATT database: (%d)", err);
}

static struct bt_gatt_dm_cb discovery_cb = {
	.completed         = discovery_complete,
	.service_not_found = discovery_service_not_found,
	.error_found       = discovery_error,
};

static void gatt_discover(struct bt_conn *conn)
{
	int err;

	if (conn != default_conn) {
		return;
	}

	err = bt_gatt_dm_start(conn, BT_UUID_NUS_SERVICE, &discovery_cb, &nus_client);
	if (err) {
		LOG_ERR("could not start the discovery procedure, error code: %d", err);
	}
}

static void exchange_func(struct bt_conn *conn, uint8_t err,
			  struct bt_gatt_exchange_params *params)
{
	if (!err) {
		LOG_INF("MTU exchange done");
	} else {
		LOG_WRN("MTU exchange failed (err %" PRIu8 ")", err);
	}
}

/* ---------------- Connection callbacks ---------------- */
static void connected(struct bt_conn *conn, uint8_t conn_err)
{
	char addr[BT_ADDR_LE_STR_LEN];
	int err;

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	if (conn_err) {
		LOG_INF("Failed to connect to %s, 0x%02x %s", addr, conn_err,
			bt_hci_err_to_str(conn_err));

		if (default_conn == conn) {
			bt_conn_unref(default_conn);
			default_conn = NULL;
			(void)k_work_submit(&scan_work);
		}
		return;
	}

	LOG_INF("Connected: %s", addr);

	static struct bt_gatt_exchange_params exchange_params;

	exchange_params.func = exchange_func;
	err = bt_gatt_exchange_mtu(conn, &exchange_params);
	if (err) {
		LOG_WRN("MTU exchange failed (err %d)", err);
	}

	err = bt_conn_set_security(conn, BT_SECURITY_L2);
	if (err) {
		LOG_WRN("Failed to set security: %d", err);
		gatt_discover(conn);
	}

	err = bt_scan_stop();
	if (err) {
		LOG_ERR("Stop LE scan failed (err %d)", err);
	}
}

static void disconnected(struct bt_conn *conn, uint8_t reason)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	LOG_INF("Disconnected: %s, reason 0x%02x %s", addr, reason,
		bt_hci_err_to_str(reason));

	if (default_conn != conn) {
		return;
	}

	bt_conn_unref(default_conn);
	default_conn = NULL;

	(void)k_work_submit(&scan_work);
}

static void security_changed(struct bt_conn *conn, bt_security_t level,
			     enum bt_security_err err)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	if (!err) {
		LOG_INF("Security changed: %s level %u", addr, level);
	} else {
		LOG_WRN("Security failed: %s level %u err %d %s", addr, level, err,
			bt_security_err_to_str(err));
	}

	gatt_discover(conn);
}

BT_CONN_CB_DEFINE(conn_callbacks) = {
	.connected = connected,
	.disconnected = disconnected,
	.security_changed = security_changed
};

/* ---------------- Scan ---------------- */
static void scan_filter_match(struct bt_scan_device_info *device_info,
			      struct bt_scan_filter_match *filter_match,
			      bool connectable)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(device_info->recv_info->addr, addr, sizeof(addr));

	LOG_INF("Filters matched. Address: %s connectable: %d", addr, connectable);
}

static void scan_connecting_error(struct bt_scan_device_info *device_info)
{
	LOG_WRN("Connecting failed");
}

static void scan_connecting(struct bt_scan_device_info *device_info,
			    struct bt_conn *conn)
{
	default_conn = bt_conn_ref(conn);
}

static int nus_client_init(void)
{
	int err;
	struct bt_nus_client_init_param init = {
		.cb = {
			.received = ble_data_received,
			.sent = ble_data_sent,
		}
	};

	err = bt_nus_client_init(&nus_client, &init);
	if (err) {
		LOG_ERR("NUS Client initialization failed (err %d)", err);
		return err;
	}

	LOG_INF("NUS Client module initialized");
	return err;
}

BT_SCAN_CB_INIT(scan_cb, scan_filter_match, NULL,
		scan_connecting_error, scan_connecting);

static void try_add_address_filter(const struct bt_bond_info *info, void *user_data)
{
	int err;
	char addr[BT_ADDR_LE_STR_LEN];
	uint8_t *filter_mode = user_data;

	bt_addr_le_to_str(&info->addr, addr, sizeof(addr));

	struct bt_conn *conn = bt_conn_lookup_addr_le(BT_ID_DEFAULT, &info->addr);

	if (conn) {
		bt_conn_unref(conn);
		return;
	}

	err = bt_scan_filter_add(BT_SCAN_FILTER_TYPE_ADDR, &info->addr);
	if (err) {
		LOG_ERR("Address filter cannot be added (err %d): %s", err, addr);
		return;
	}

	LOG_INF("Address filter added: %s", addr);
	*filter_mode |= BT_SCAN_ADDR_FILTER;
}

static int scan_start(void)
{
	int err;
	uint8_t filter_mode = 0;

	err = bt_scan_stop();
	if (err) {
		LOG_ERR("Failed to stop scanning (err %d)", err);
		return err;
	}

	bt_scan_filter_remove_all();

	err = bt_scan_filter_add(BT_SCAN_FILTER_TYPE_UUID, BT_UUID_NUS_SERVICE);
	if (err) {
		LOG_ERR("UUID filter cannot be added (err %d", err);
		return err;
	}
	filter_mode |= BT_SCAN_UUID_FILTER;

	bt_foreach_bond(BT_ID_DEFAULT, try_add_address_filter, &filter_mode);

	err = bt_scan_filter_enable(filter_mode, false);
	if (err) {
		LOG_ERR("Filters cannot be turned on (err %d)", err);
		return err;
	}

	err = bt_scan_start(BT_SCAN_TYPE_SCAN_ACTIVE);
	if (err) {
		LOG_ERR("Scanning failed to start (err %d)", err);
		return err;
	}

	LOG_INF("Scan started");
	return 0;
}

static void scan_work_handler(struct k_work *item)
{
	ARG_UNUSED(item);

	(void)scan_start();
}

static void scan_init(void)
{
	struct bt_scan_init_param scan_init = {
		.connect_if_match = true,
	};

	bt_scan_init(&scan_init);
	bt_scan_cb_register(&scan_cb);

	k_work_init(&scan_work, scan_work_handler);
	LOG_INF("Scan module initialized");
}

static void auth_cancel(struct bt_conn *conn)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	LOG_INF("Pairing cancelled: %s", addr);
}

static void pairing_complete(struct bt_conn *conn, bool bonded)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	LOG_INF("Pairing completed: %s, bonded: %d", addr, bonded);
}

static void pairing_failed(struct bt_conn *conn, enum bt_security_err reason)
{
	char addr[BT_ADDR_LE_STR_LEN];

	bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));

	LOG_WRN("Pairing failed conn: %s, reason %d %s", addr, reason,
		bt_security_err_to_str(reason));
}

static struct bt_conn_auth_cb conn_auth_callbacks = {
	.cancel = auth_cancel,
};

static struct bt_conn_auth_info_cb conn_auth_info_callbacks = {
	.pairing_complete = pairing_complete,
	.pairing_failed = pairing_failed
};

int main(void)
{
	int err;

	err = bt_conn_auth_cb_register(&conn_auth_callbacks);
	if (err) {
		LOG_ERR("Failed to register authorization callbacks.");
		return 0;
	}

	err = bt_conn_auth_info_cb_register(&conn_auth_info_callbacks);
	if (err) {
		printk("Failed to register authorization info callbacks.\n");
		return 0;
	}

	err = bt_enable(NULL);
	if (err) {
		LOG_ERR("Bluetooth init failed (err %d)", err);
		return 0;
	}
	LOG_INF("Bluetooth initialized");

	if (IS_ENABLED(CONFIG_SETTINGS)) {
		settings_load();
	}

	uart_send_str("\r\nWalkEEG Central (nRF52832) ready\r\n");
	LOG_INF("UART ready");

	err = nus_client_init();
	if (err != 0) {
		LOG_ERR("nus_client_init failed (err %d)", err);
		return 0;
	}

	scan_init();
	err = scan_start();
	if (err) {
		return 0;
	}

	printk("Starting WalkEEG Central\n");

	for (;;) {
		k_sleep(K_SECONDS(1));
	}
}
