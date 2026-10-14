import { Router } from 'express';
import { capturePayment } from '../services/psp-capture.js';

export const pspProxyRouter = Router();
const router = pspProxyRouter;

/** Support agents re-try a failed capture from the console. */
router.post('/payments/:id/recapture', async (req, res) => {
  try {
    const result = await capturePayment(req.params.id);
    res.json({ data: result });
  } catch (err) {
    const e = err as { response?: { status: number } };
    if (e.response) {
      res.status(e.response.status).json({ error: { code: 'PSP_ERROR', message: 'Capture failed' } });
      return;
    }
    res.status(502).json({ error: { code: 'UPSTREAM_UNAVAILABLE', message: 'PSP unreachable' } });
  }
});
