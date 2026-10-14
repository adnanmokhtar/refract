import { Body } from '@nestjs/common';
import { ZodType } from 'zod';
import { ZodValidationPipe } from './zod-validation.pipe';

/** `@ZodBody(schema)` — a body parsed by a strict zod schema instead of a class DTO. */
export const ZodBody = <T>(schema: ZodType<T>) => Body(new ZodValidationPipe(schema));
