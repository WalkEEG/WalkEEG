/*
 * WalkEEG AD8232 ECG stream over NUS.
 *  - 8-channel frame layout (App-compatible)
 *      default:          CH0 = AD8232, CH1 = sawtooth test, CH2..7 = 0
 *      ADS1293 only:     CH0..2 = Lead I/II/III
 *      CONFIG_WALKEEG_DUAL_FRONTEND: CH0 = AD8232, CH1/CH2 = ADS1293 ECG1/2
 *  - 500 Hz sample rate
 *  - lead-off flags in frame header
 */
#ifndef WALKEEG_STREAM_H_
#define WALKEEG_STREAM_H_

#include <zephyr/bluetooth/conn.h>
#include <stdbool.h>

#define WALKEEG_NUM_CH        8
#define WALKEEG_DEFAULT_SAMPLE_HZ 2000
#define WALKEEG_MAGIC         0xA5
#define WALKEEG_VERSION       0x01
#define WALKEEG_HDR_LEN       6
#define WALKEEG_DEFAULT_N     20
#define WALKEEG_MAX_N         30

/** Start sample timer + TX thread (call after BLE/NUS init). */
void walkeeg_stream_init(void);

/** BLE connected — request MTU/DLE and arm streaming when Notify enabled. */
void walkeeg_stream_on_connected(struct bt_conn *conn);

/** BLE disconnected — stop TX and reset ring. */
void walkeeg_stream_on_disconnected(void);

/** NUS TX CCCD changed (notifications enabled/disabled). */
void walkeeg_stream_set_notify(bool enabled);

/** Runtime sample rate: 500/1000/2000/4000 Hz. Returns 0 or -EINVAL. */
int walkeeg_stream_set_rate(uint16_t hz);
uint16_t walkeeg_stream_get_rate(void);

#endif /* WALKEEG_STREAM_H_ */
