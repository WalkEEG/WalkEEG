import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import {
  DynamoDBDocumentClient,
  PutCommand,
  GetCommand,
  QueryCommand,
  DeleteCommand,
  UpdateCommand,
} from '@aws-sdk/lib-dynamodb';
import { S3Client, DeleteObjectCommand, GetObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { randomUUID } from 'crypto';

const ddb = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const s3 = new S3Client({});

const TABLE = process.env.SIGNALS_TABLE;
const BUCKET = process.env.DATA_BUCKET;

export async function createSignal(userId, data) {
  const signalId = randomUUID();
  const now = new Date().toISOString();
  const item = {
    userId,
    signalId,
    name: data.name,
    description: data.description || '',
    s3Key: data.s3Key,
    fileName: data.fileName || data.s3Key.split('/').pop(),
    fileSize: data.fileSize || 0,
    status: data.status || 'uploaded',
    createdAt: now,
    updatedAt: now,
    channels: data.channels || '8',
    sampleRate: data.sampleRate || '2000 Hz',
    duration: data.duration || '—',
    segments: data.segments || [],
  };

  await ddb.send(new PutCommand({ TableName: TABLE, Item: item }));
  return item;
}

export async function listSignals(userId) {
  const result = await ddb.send(
    new QueryCommand({
      TableName: TABLE,
      KeyConditionExpression: 'userId = :uid',
      ExpressionAttributeValues: { ':uid': userId },
      ScanIndexForward: false,
    }),
  );
  return result.Items || [];
}

export async function getSignal(userId, signalId) {
  const result = await ddb.send(
    new GetCommand({
      TableName: TABLE,
      Key: { userId, signalId },
    }),
  );
  return result.Item || null;
}

export async function deleteSignal(userId, signalId) {
  const item = await getSignal(userId, signalId);
  if (!item) return null;

  // Delete S3 object(s)
  const keysToDelete = item.segments?.length
    ? item.segments.map((s) => s.s3Key)
  : [item.s3Key];

  for (const key of keysToDelete) {
    if (key) {
      try {
        await s3.send(new DeleteObjectCommand({ Bucket: BUCKET, Key: key }));
      } catch (err) {
        console.warn(`Failed to delete S3 object ${key}:`, err.message);
      }
    }
  }

  await ddb.send(
    new DeleteCommand({
      TableName: TABLE,
      Key: { userId, signalId },
    }),
  );
  return item;
}

export async function updateSignalStatus(userId, signalId, status, extra = {}) {
  const expr = ['#status = :status', '#updatedAt = :updatedAt'];
  const names = { '#status': 'status', '#updatedAt': 'updatedAt' };
  const values = { ':status': status, ':updatedAt': new Date().toISOString() };

  for (const [k, v] of Object.entries(extra)) {
    expr.push(`#${k} = :${k}`);
    names[`#${k}`] = k;
    values[`:${k}`] = v;
  }

  await ddb.send(
    new UpdateCommand({
      TableName: TABLE,
      Key: { userId, signalId },
      UpdateExpression: `SET ${expr.join(', ')}`,
      ExpressionAttributeNames: names,
      ExpressionAttributeValues: values,
    }),
  );
}

export async function getDownloadUrl(s3Key, expiresIn = 3600) {
  const command = new GetObjectCommand({ Bucket: BUCKET, Key: s3Key });
  return getSignedUrl(s3, command, { expiresIn });
}

export function toPublicSignal(item) {
  if (!item) return null;
  const { userId, ...rest } = item;
  return { id: rest.signalId, ...rest };
}
