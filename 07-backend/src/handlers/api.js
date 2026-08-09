import { getUserId, getUserEmail, getUserName, validateS3Key } from '../lib/auth.js';
import {
  createSignal,
  listSignals,
  getSignal,
  deleteSignal,
  getDownloadUrl,
  toPublicSignal,
} from '../lib/signals.js';
import { ok, created, badRequest, notFound, forbidden, serverError } from '../lib/response.js';

/** HTTP API may include stage in rawPath, e.g. `/prod/signals` → `/signals`. */
function normalizePath(event) {
  let path = event.rawPath || event.requestContext?.http?.path || '';
  const stage = event.requestContext?.stage;
  if (stage && stage !== '$default' && path.startsWith(`/${stage}/`)) {
    path = path.slice(stage.length + 1);
  } else if (stage && stage !== '$default' && path === `/${stage}`) {
    path = '/';
  }
  // Fallback when stage is missing from requestContext but URL still has /prod/...
  const knownRoots = ['me', 'signals'];
  const prefixed = path.match(/^\/([^/]+)\/(.+)$/);
  if (prefixed && !knownRoots.includes(prefixed[1])) {
    path = `/${prefixed[2]}`;
  }
  if (path.length > 1 && path.endsWith('/')) path = path.slice(0, -1);
  return path;
}

export async function handler(event) {
  const method = event.requestContext?.http?.method;
  const path = normalizePath(event);

  try {
    const userId = getUserId(event);

    // GET /me
    if (method === 'GET' && path === '/me') {
      return ok({
        id: userId,
        email: getUserEmail(event),
        name: getUserName(event),
      });
    }

    // GET /signals
    if (method === 'GET' && path === '/signals') {
      const items = await listSignals(userId);
      return ok({ signals: items.map(toPublicSignal) });
    }

    // POST /signals
    if (method === 'POST' && path === '/signals') {
      const body = JSON.parse(event.body || '{}');
      if (!body.name || !body.s3Key || !body.identityId) {
        return badRequest('name, s3Key, and identityId are required');
      }
      if (!validateS3Key(body.identityId, body.s3Key)) {
        return forbidden('s3Key must be under your identity prefix');
      }
      const item = await createSignal(userId, body);
      return created(toPublicSignal(item));
    }

    // GET /signals/{id}
    const getMatch = path.match(/^\/signals\/([^/]+)$/);
    if (method === 'GET' && getMatch) {
      const signalId = getMatch[1];
      const item = await getSignal(userId, signalId);
      if (!item) return notFound('Signal not found');
      const pub = toPublicSignal(item);
      pub.downloadUrl = await getDownloadUrl(item.s3Key);
      // Presigned URLs for each segment so the web viewer can stitch multi-part recordings.
      if (Array.isArray(item.segments) && item.segments.length > 0) {
        pub.segmentUrls = await Promise.all(
          item.segments.map(async (seg) => ({
            partIndex: seg.partIndex,
            fileName: seg.fileName,
            s3Key: seg.s3Key,
            downloadUrl: seg.s3Key ? await getDownloadUrl(seg.s3Key) : null,
          })),
        );
      }
      return ok(pub);
    }

    // DELETE /signals/{id}
    const delMatch = path.match(/^\/signals\/([^/]+)$/);
    if (method === 'DELETE' && delMatch) {
      const signalId = delMatch[1];
      const item = await deleteSignal(userId, signalId);
      if (!item) return notFound('Signal not found');
      return ok({ deleted: true, id: signalId });
    }

    console.warn('Route not found', {
      method,
      path,
      rawPath: event.rawPath,
      stage: event.requestContext?.stage,
    });
    return notFound(`Route not found: ${method} ${path}`);
  } catch (err) {
    if (err.message === 'Unauthorized') {
      return { statusCode: 401, body: JSON.stringify({ error: 'Unauthorized' }) };
    }
    return serverError(err);
  }
}
