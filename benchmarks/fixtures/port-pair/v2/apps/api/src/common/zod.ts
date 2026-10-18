import { Body, PipeTransform, Query, UnprocessableEntityException } from '@nestjs/common';
import type { ZodTypeAny } from 'zod';

// V1 parity: 422 with Laravel's envelope `{ message, errors: { field: [..] } }`.
export class ZodValidationPipe implements PipeTransform {
  constructor(private readonly schema: ZodTypeAny) {}

  transform(value: unknown): unknown {
    const result = this.schema.safeParse(value);
    if (result.success) {
      return result.data;
    }

    const issues = result.error.issues.slice(0, 1);
    const errors: Record<string, string[]> = {};
    for (const issue of issues) {
      const key = issue.path.join('.');
      (errors[key] ??= []).push(issue.message);
    }

    throw new UnprocessableEntityException({ message: issues[0]?.message ?? 'The given data was invalid.', errors });
  }
}

export const ZodBody = (schema: ZodTypeAny) => Body(new ZodValidationPipe(schema));
export const ZodQuery = (schema: ZodTypeAny) => Query(new ZodValidationPipe(schema));
