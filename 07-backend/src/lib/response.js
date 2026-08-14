export function json(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
    },
    body: JSON.stringify(body),
  };
}

export function ok(body) {
  return json(200, body);
}

export function created(body) {
  return json(201, body);
}

export function badRequest(message) {
  return json(400, { error: message });
}

export function notFound(message = 'Not found') {
  return json(404, { error: message });
}

export function forbidden(message = 'Forbidden') {
  return json(403, { error: message });
}

export function serverError(err) {
  console.error(err);
  return json(500, { error: 'Internal server error' });
}
