import { z } from 'zod';
export const ENV = z.object({ DATABASE_URL: z.string().url(), PORT: z.coerce.number() });
