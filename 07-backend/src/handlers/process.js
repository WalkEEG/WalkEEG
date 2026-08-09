/**
 * S3 event handler — placeholder for FFT / signal processing pipeline.
 * Triggered when a .csv file is uploaded to walkeeg-data.
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

    // TODO: Run FFT analysis, update metadata with spectral bands
    // For now, mark any matching signal as processed
  }

  return { statusCode: 200, body: 'OK' };
}
