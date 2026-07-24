/*
 * WalkEEG: 0.5 ms ramp test signal + framed NUS Notify stream.
 */

#include "stream.h"

#include <zephyr/kernel.h>
#include <zephyr/sys/atomic.h>
#include <zephyr/sys/byteorder.h>
#include <zephyr/bluetooth/bluetooth.h>
#include <zephyr/bluetooth/conn.h>
#include <zephyr/bluetooth/gatt.h>
#include <zephyr/bluetooth/hci.h>
#include <bluetooth/services/nus.h>
#include <zephyr/logging/log.h>
#include <string.h>

LOG_MODULE_REGISTER(walkeeg_stream, LOG_LEVEL_INF);

#define RING_CAPACITY   512  /* timepoints; ~256 ms @ 2 kHz */
#define STREAM_STACK    2048
#define STREAM_PRIO     5

struct sample_tp {
	int16_t ch[WALKEEG_NUM_CH];
};

static struct sample_tp ring[RING_CAPACITY];
static uint16_t ring_w;
static uint16_t ring_r;
static uint16_t ring_count;
static struct k_mutex ring_mutex;
static struct k_sem samples_sem;

static uint16_t ramp_i;   /* 0..1999 within second */
static uint8_t ramp_sec;  /* 0..31 */

static atomic_t streaming; /* connected && notify enabled */
static atomic_t notify_on;
static struct bt_conn *stream_conn;
static uint16_t frame_seq;

static K_THREAD_STACK_DEFINE(stream_stack, STREAM_STACK);
static struct k_thread stream_thread_data;

static int16_t clamp_i16(int32_t v)
{
	if (v < 0) {
		return 0;
	}
	if (v > 32767) {
		return 32767;
	}
	return (int16_t)v;
}

static void ring_push(const struct sample_tp *tp)
{
	k_mutex_lock(&ring_mutex, K_FOREVER);

	if (ring_count >= RING_CAPACITY) {
		/* Drop oldest */
		ring_r = (ring_r + 1) % RING_CAPACITY;
		ring_count--;
	}

	ring[ring_w] = *tp;
	ring_w = (ring_w + 1) % RING_CAPACITY;
	ring_count++;

	k_mutex_unlock(&ring_mutex);
	k_sem_give(&samples_sem);
}

static bool ring_pop_n(struct sample_tp *out, uint8_t n)
{
	k_mutex_lock(&ring_mutex, K_FOREVER);

	if (ring_count < n) {
		k_mutex_unlock(&ring_mutex);
		return false;
	}

	for (uint8_t i = 0; i < n; i++) {
		out[i] = ring[ring_r];
		ring_r = (ring_r + 1) % RING_CAPACITY;
		ring_count--;
	}

	k_mutex_unlock(&ring_mutex);
	return true;
}

static void ring_reset(void)
{
	k_mutex_lock(&ring_mutex, K_FOREVER);
	ring_w = 0;
	ring_r = 0;
	ring_count = 0;
	k_mutex_unlock(&ring_mutex);

	while (k_sem_take(&samples_sem, K_NO_WAIT) == 0) {
		/* drain */
	}
}

static void sample_timer_handler(struct k_timer *timer)
{
	struct sample_tp tp;
	int32_t base;
	uint8_t ch;

	ARG_UNUSED(timer);

	if (!atomic_get(&streaming)) {
		return;
	}

	base = (int32_t)ramp_sec * 1000 + (int32_t)ramp_i;

	/* Offset each channel by 2000 so CH0..CH7 are visually distinct on a 0..32767 plot. */
	for (ch = 0; ch < WALKEEG_NUM_CH; ch++) {
		tp.ch[ch] = clamp_i16(base + (int32_t)ch * 2000);
	}

	ring_push(&tp);

	ramp_i++;
	if (ramp_i >= WALKEEG_SAMPLE_HZ) {
		ramp_i = 0;
		ramp_sec++;
		if (ramp_sec >= 32) {
			ramp_sec = 0;
		}
	}
}

K_TIMER_DEFINE(sample_timer, sample_timer_handler, NULL);

static uint8_t choose_n(struct bt_conn *conn)
{
	uint32_t mtu = bt_nus_get_mtu(conn);
	uint32_t payload_room;
	uint8_t n;

	/* ATT notify payload max = MTU - 3; frame = 6 + N*16 */
	if (mtu < (WALKEEG_HDR_LEN + 16 + 3)) {
		return 1;
	}

	payload_room = mtu - 3 - WALKEEG_HDR_LEN;
	n = (uint8_t)(payload_room / 16U);

	if (n > WALKEEG_MAX_N) {
		n = WALKEEG_MAX_N;
	}
	if (n > WALKEEG_DEFAULT_N) {
		n = WALKEEG_DEFAULT_N;
	}
	if (n < 1) {
		n = 1;
	}

	return n;
}

static int send_frame(struct bt_conn *conn, const struct sample_tp *tps, uint8_t n)
{
	uint8_t buf[WALKEEG_HDR_LEN + WALKEEG_MAX_N * WALKEEG_NUM_CH * 2];
	uint16_t len = WALKEEG_HDR_LEN + (uint16_t)n * WALKEEG_NUM_CH * 2;
	uint16_t off = WALKEEG_HDR_LEN;
	uint8_t i, ch;
	int err;

	buf[0] = WALKEEG_MAGIC;
	buf[1] = WALKEEG_VERSION;
	sys_put_le16(frame_seq, &buf[2]);
	buf[4] = n;
	buf[5] = 0; /* flags */

	for (i = 0; i < n; i++) {
		for (ch = 0; ch < WALKEEG_NUM_CH; ch++) {
			sys_put_le16((uint16_t)tps[i].ch[ch], &buf[off]);
			off += 2;
		}
	}

	err = bt_nus_send(conn, buf, len);
	if (err) {
		return err;
	}

	frame_seq++;
	return 0;
}

static void update_streaming_flag(void)
{
	bool on = (stream_conn != NULL) && atomic_get(&notify_on);

	atomic_set(&streaming, on ? 1 : 0);

	if (on) {
		ramp_i = 0;
		ramp_sec = 0;
		frame_seq = 0;
		ring_reset();
		k_timer_start(&sample_timer, K_USEC(500), K_USEC(500));
		LOG_INF("WalkEEG stream started");
	} else {
		k_timer_stop(&sample_timer);
		ring_reset();
		LOG_INF("WalkEEG stream stopped");
	}
}

static void mtu_exchange_cb(struct bt_conn *conn, uint8_t err,
			    struct bt_gatt_exchange_params *params)
{
	ARG_UNUSED(params);

	if (err) {
		LOG_WRN("MTU exchange failed (%u)", err);
	} else {
		LOG_INF("MTU exchange done, NUS MTU=%u", bt_nus_get_mtu(conn));
	}
}

static struct bt_gatt_exchange_params mtu_params = {
	.func = mtu_exchange_cb,
};

static uint16_t ring_available(void)
{
	uint16_t c;

	k_mutex_lock(&ring_mutex, K_FOREVER);
	c = ring_count;
	k_mutex_unlock(&ring_mutex);
	return c;
}

static void stream_thread(void *p1, void *p2, void *p3)
{
	struct sample_tp batch[WALKEEG_MAX_N];
	struct bt_conn *conn;
	uint8_t n;
	int err;
	int fail_streak = 0;

	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	for (;;) {
		k_sem_take(&samples_sem, K_FOREVER);

		if (!atomic_get(&streaming) || stream_conn == NULL) {
			continue;
		}

		conn = stream_conn;
		n = choose_n(conn);

		while (atomic_get(&streaming) && stream_conn != NULL &&
		       ring_available() >= n) {
			if (!ring_pop_n(batch, n)) {
				break;
			}

			err = send_frame(conn, batch, n);
			if (err) {
				fail_streak++;
				if ((fail_streak % 50) == 1) {
					LOG_WRN("bt_nus_send err %d (streak %d)",
						err, fail_streak);
				}
				k_msleep(2);
			} else {
				fail_streak = 0;
			}
		}
	}
}

void walkeeg_stream_init(void)
{
	k_mutex_init(&ring_mutex);
	k_sem_init(&samples_sem, 0, RING_CAPACITY);
	atomic_set(&streaming, 0);
	atomic_set(&notify_on, 0);

	k_thread_create(&stream_thread_data, stream_stack,
			K_THREAD_STACK_SIZEOF(stream_stack),
			stream_thread, NULL, NULL, NULL,
			STREAM_PRIO, 0, K_NO_WAIT);
	k_thread_name_set(&stream_thread_data, "walkeeg_tx");

	LOG_INF("WalkEEG stream module ready");
}

void walkeeg_stream_on_connected(struct bt_conn *conn)
{
	int err;

	stream_conn = conn;
	frame_seq = 0;

	err = bt_gatt_exchange_mtu(conn, &mtu_params);
	if (err) {
		LOG_WRN("bt_gatt_exchange_mtu failed (%d)", err);
	}

	err = bt_conn_le_data_len_update(conn, BT_LE_DATA_LEN_PARAM_MAX);
	if (err) {
		LOG_WRN("data len update failed (%d)", err);
	}

	err = bt_conn_le_phy_update(conn, BT_CONN_LE_PHY_PARAM_2M);
	if (err) {
		LOG_WRN("PHY 2M update failed (%d)", err);
	}

	update_streaming_flag();
}

void walkeeg_stream_on_disconnected(void)
{
	stream_conn = NULL;
	atomic_set(&notify_on, 0);
	update_streaming_flag();
}

void walkeeg_stream_set_notify(bool enabled)
{
	atomic_set(&notify_on, enabled ? 1 : 0);
	update_streaming_flag();
}
