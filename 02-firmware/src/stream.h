/*
 * WalkEEG AD8232 ECG stream over NUS.
 *  - 8-channel frame layout (App-compatible): CH0 = AD8232 ADC, CH1..7 = 0
 *  - 500 Hz sample rate
 *  - lead-off flags in frame header
 */
#ifndef WALKEEG_STREAM_H_
#define WALKEEG_STREAM_H_

#include <zephyr/bluetooth/conn.h>
#include <stdbool.h>

#define WALKEEG_NUM_CH        8
#define WALKEEG_SAMPLE_HZ     500
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

#endif /* WALKEEG_STREAM_H_ */
