import { PlanChangeSchema, type PlanChange } from '@tollgate/contracts';
import { ValidationError } from '../common/errors';

// Server side of the plan-change rules; the portal runs the same schema from @tollgate/contracts.
export function validatePlanChange(input: unknown): PlanChange {
  const parsed = PlanChangeSchema.safeParse(input);
  if (!parsed.success) throw new ValidationError('invalid plan change', parsed.error.issues.map((i) => i.path.join('.')));
  return parsed.data;
}
