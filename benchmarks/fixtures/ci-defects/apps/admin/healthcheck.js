// Exec-form container health check: no curl or wget in the slim base.
fetch(`http://localhost:${process.env.PORT ?? 3000}/health`)
  .then((r) => process.exit(r.ok ? 0 : 1))
  .catch(() => process.exit(1));
