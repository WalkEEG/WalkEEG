/**
 * S3 event handler — offline batch entry point.
 *
 * Deliberately thin. Numeric work belongs in ../../algorithms/, which is
 * cloud-agnostic and testable on its own. This handler only does what a
 * Lambda uniquely can: read the uploaded object and persist results.
 *
 * Contracts:
 *   docs/algorithms/eeg-pipeline.md
 *   docs/algorithms/emg-pipeline.md
 *   docs/algorithms/data-format.md  (unit and metadata requirements)
 */
import { updateSignalStatus } from '../lib/signals.js';

export async function handler(event) {
  for (const record of event.Records || []) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    const size = record.s3.object.size;

    console.log(`Processing upload: s3://${bucket}/${key} (${size} bytes)`);

    // Extract userId from key: {userId}/signals/...
    const parts = key.split('/');
    if (parts.length < 3 || parts[1] !== 'signals') {
      console.warn('Unexpected key format, skipping:', key);
      continue;
    }

    const userId = parts[0];

    // TODO: fetch the object, convert LSB -> uV using the recorded lsb_uv,
    // then call the shared statistics module in ../../algorithms/.
    // Refuse to process when sample_rate or lsb_uv is missing rather than
    // assuming defaults — see docs/algorithms/data-format.md section 5.
    // For now, mark any matching signal as processed
  }

  return { statusCode: 200, body: 'OK' };
}
