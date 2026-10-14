import { Router } from 'express';
import multer from 'multer';

export const importsRouter = Router();
const router = importsRouter;

const csvUpload = multer({ storage: multer.memoryStorage() });

/** Catalogue CSV import for the merchandising team. */
router.post('/catalog-imports', csvUpload.single('csv'), async (req, res) => {
  const text = req.file?.buffer.toString('utf8') ?? '';
  res.status(202).json({ data: { lines: text.split('\n').length } });
});
