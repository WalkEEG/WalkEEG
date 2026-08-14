/**
 * Extract Cognito user sub from API Gateway JWT authorizer claims.
 */
export function getUserId(event) {
  const claims = event.requestContext?.authorizer?.jwt?.claims;
  if (!claims?.sub) {
    throw new Error('Unauthorized');
  }
  return claims.sub;
}

export function getUserEmail(event) {
  const claims = event.requestContext?.authorizer?.jwt?.claims;
  return claims?.email || '';
}

export function getUserName(event) {
  const claims = event.requestContext?.authorizer?.jwt?.claims;
  return claims?.name || claims?.email?.split('@')[0] || 'User';
}

/**
 * Validate that an S3 key belongs to the caller's Cognito Identity Pool ID.
 * IAM policy scopes writes to {identityId}/signals/...
 */
export function validateS3Key(identityId, s3Key) {
  if (!identityId || !s3Key) return false;
  const prefix = `${identityId}/signals/`;
  if (!s3Key.startsWith(prefix)) return false;
  if (s3Key.includes('..')) return false;
  return true;
}
