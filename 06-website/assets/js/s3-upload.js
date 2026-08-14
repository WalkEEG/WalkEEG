/**
 * S3 direct upload using Cognito Identity temporary credentials.
 */
import { S3Client, PutObjectCommand } from 'https://cdn.jsdelivr.net/npm/@aws-sdk/client-s3@3.700.0/+esm';

async function uploadFile(credentials, region, bucket, key, file, onProgress) {
  const client = new S3Client({
    region,
    credentials: {
      accessKeyId: credentials.AccessKeyId,
      secretAccessKey: credentials.SecretKey,
      sessionToken: credentials.SessionToken,
    },
  });

  const body = file instanceof Blob ? file : new Blob([file]);
  const total = body.size;
  let loaded = 0;

  const stream = body.stream();
  const reader = stream.getReader();
  const chunks = [];

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    chunks.push(value);
    loaded += value.length;
    if (onProgress && total > 0) {
      onProgress(Math.min(99, Math.round((loaded / total) * 100)));
    }
  }

  const merged = new Uint8Array(loaded);
  let offset = 0;
  for (const chunk of chunks) {
    merged.set(chunk, offset);
    offset += chunk.length;
  }

  await client.send(
    new PutObjectCommand({
      Bucket: bucket,
      Key: key,
      Body: merged,
      ContentType: file.type || 'text/csv',
    }),
  );

  if (onProgress) onProgress(100);
}

window.WalkEEGS3 = { uploadFile };
