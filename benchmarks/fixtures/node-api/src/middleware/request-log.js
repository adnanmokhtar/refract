'use strict';

// Structured request log. One line per request, emitted on finish so the
// status code and duration are known.
function requestLog(req, res, next) {
  const startedAt = Date.now();

  res.on('finish', () => {
    const line = {
      at: new Date().toISOString(),
      method: req.method,
      path: req.path,
      status: res.statusCode,
      durationMs: Date.now() - startedAt,
      actor: req.user ? req.user.id : null,
      tenant: req.user ? req.user.tenantId : null,
      body: req.body,
    };
    process.stdout.write(JSON.stringify(line) + '\n');
  });

  return next();
}

module.exports = { requestLog };
