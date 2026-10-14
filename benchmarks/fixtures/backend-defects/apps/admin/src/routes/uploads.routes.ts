import { Router } from 'express';
import multer from 'multer';
import { pool } from '../lib/db.js';

export const uploadsRouter = Router();
const router = uploadsRouter;

const storage = multer.diskStorage({ destination: '/var/lib/admin/uploads' });

const upload = multer({
  storage,
  limits: { fileSize: 10 * 1024 * 1024, files: 1 },
  fileFilter: (req, file, cb) => {
    const kind = req.body.kind;
    cb(null, kind === 'logo' ? file.mimetype === 'image/png' : file.mimetype === 'application/pdf');
  },
});

/** Merchant branding and KYC documents: multipart with "kind" and "merchantId" fields plus the file. */
router.post('/merchant-files', upload.single('file'), async (req, res) => {
  if (!req.file) {
    res.status(400).json({ error: { code: 'FILE_REQUIRED', message: 'file is required' } });
    return;
  }
  const merchantId = String(req.body.merchantId ?? '');
  if (!/^[0-9a-f-]{36}$/.test(merchantId)) {
    res.status(422).json({ error: { code: 'BAD_MERCHANT', message: 'merchantId must be a UUID' } });
    return;
  }
  await pool.query('insert into merchant_files (merchant_id, path) values ($1, $2)', [merchantId, req.file.path]);
  res.status(201).location(`/admin/merchant-files/${req.file.filename}`).json({ data: { path: req.file.filename } });
});
