/*
 * WalkEEG: AD8232 ECG framing + NUS Notify stream.
 *
 * 1 analog channel (SAADC AIN0 = P0.02) sampled at 500 Hz,
 * 50 Hz mains notch filtered (see notch.c);
 * lead-off flags (LO+/LO-) are packed into the frame header flags byte:
 *   bit0 = LO+ (1 = lead attached), bit1 = LO- (1 = lead attached)
 */

#include "stream.h"
#include "adc_sample.h"
#include "notch.h"

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

#define RING_CAPACITY   512  /* timepoints; ~1 s @ 500 Hz */
#define STREAM_STACK    2048
#define STREAM_PRIO     5

struct sample_tp {
	int16_t ch[WALKEEG_NUM_CH];
	uint8_t flags;   /* lead-off bits */
};

static struct sample_tp ring[RING_CAPACITY];
static uint16_t ring_w;
static uint16_t ring_r;
static uint16_t ring_count;
static struct k_mutex ring_mutex;
static struct k_sem samples_sem;

static uint16_t ramp_i;   /* 0..499 within second (CH1 sawtooth) */

static atomic_t streaming; /* connected && notify enabled */
static atomic_t notify_on;
static struct bt_conn *stream_conn;
static uint16_t frame_seq;

/* tick_sem: 500 Hz timer -> sampler thread (one per sample)
 * samples_sem: sampler -> TX thread (one per pushed sample)
 */
static struct k_sem adc_tick_sem;

static K_THREAD_STACK_DEFINE(stream_stack, STREAM_STACK);
static struct k_thread stream_thread_data;

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
	while (k_sem_take(&adc_tick_sem, K_NO_WAIT) == 0) {
		/* drain */
	}
}

/* 500 Hz tick: only wakes the sampler thread (no blocking work in timer ctx). */
static void sample_timer_handler(struct k_timer *timer)
{
	ARG_UNUSED(timer);

	if (atomic_get(&streaming)) {
		k_sem_give(&adc_tick_sem);
	}
}

K_TIMER_DEFINE(sample_timer, sample_timer_handler, NULL);

/* Dedicated sampler thread: ADC read (blocking) + framing + ring push. */
static void sampler_thread(void *p1, void *p2, void *p3)
{
	struct sample_tp tp;
	struct walkeeg_adc_sample s;
	int32_t ramp_val;
	int err;

	ARG_UNUSED(p1);
	ARG_UNUSED(p2);
	ARG_UNUSED(p3);

	for (;;) {
		k_sem_take(&adc_tick_sem, K_FOREVER);

		if (!atomic_get(&streaming)) {
			continue;
		}

		err = walkeeg_adc_read(&s);
		if (err) {
			LOG_WRN("adc_read err %d", err);
			continue;
		}

		/* CH0 = real AD8232 signal: raw 12-bit value (0..4095),
		 * riding on half-scale (~2048) DC bias from REFOUT,
		 * 50 Hz mains notch filtered before framing. */
		memset(tp.ch, 0, sizeof(tp.ch));
		tp.ch[0] = notch_50hz(s.value);

		/* CH1 = sawtooth test signal, 0..4095 over 1 s (same range as 12-bit ADC) */
		ramp_val = (int32_t)ramp_i * 4095 / (WALKEEG_SAMPLE_HZ - 1);
		tp.ch[1] = (int16_t)ramp_val;
		ramp_i++;
		if (ramp_i >= WALKEEG_SAMPLE_HZ) {
			ramp_i = 0;
		}

		/* CH2..7 = 0 (already memset) */
		tp.flags = (s.lo_plus  ? 0x01 : 0) | (s.lo_minus ? 0x02 : 0);

		ring_push(&tp);
	}
}

static K_THREAD_STACK_DEFINE(sampler_stack, 1024);
static struct k_thread sampler_thread_data;

static uint8_t choose_n(struct bt_conn *conn)
{
	uint32_t mtu = bt_nus_get_mtu(conn);
	uint32_t payload_room;
	uint8_t n;

	/* ATT notify payload max = MTU - 3; frame = 6 + N*2 */
	if (mtu < (WALKEEG_HDR_LEN + 2 + 3)) {
		return 1;
	}

	payload_room = mtu - 3 - WALKEEG_HDR_LEN;
	n = (uint8_t)(payload_room / (WALKEEG_NUM_CH * 2U));

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
	buf[5] = 0; /* flags: bit0=LO+ attached, bit1=LO- attached */

	for (i = 0; i < n; i++) {
		buf[5] |= tps[i].flags;
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
		frame_seq = 0;
		notch_reset();
		ring_reset();
		k_timer_start(&sample_timer, K_USEC(1000U * 1000U / WALKEEG_SAMPLE_HZ),
			      K_USEC(1000U * 1000U / WALKEEG_SAMPLE_HZ));
		LOG_INF("WalkEEG ECG stream started (%d Hz)", WALKEEG_SAMPLE_HZ);
	} else {
		k_timer_stop(&sample_timer);
		ring_reset();
		LOG_INF("WalkEEG ECG stream stopped");
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
	k_sem_init(&adc_tick_sem, 0, RING_CAPACITY);
	atomic_set(&streaming, 0);
	atomic_set(&notify_on, 0);

	k_thread_create(&stream_thread_data, stream_stack,
			K_THREAD_STACK_SIZEOF(stream_stack),
			stream_thread, NULL, NULL, NULL,
			STREAM_PRIO, 0, K_NO_WAIT);
	k_thread_name_set(&stream_thread_data, "walkeeg_tx");

	/* Sampler thread: does blocking ADC reads (never in timer ctx) */
	k_thread_create(&sampler_thread_data, sampler_stack,
			K_THREAD_STACK_SIZEOF(sampler_stack),
			sampler_thread, NULL, NULL, NULL,
			STREAM_PRIO + 1, 0, K_NO_WAIT);
	k_thread_name_set(&sampler_thread_data, "walkeeg_adc");

	LOG_INF("WalkEEG ECG stream module ready");
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
