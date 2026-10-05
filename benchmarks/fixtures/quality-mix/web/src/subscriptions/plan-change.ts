import { PlanChangeSchema, type PlanChange } from '@tollgate/contracts';

// Client side of the plan-change rules: the same schema the API validates with, so the two agree.
export function validatePlanChange(input: unknown): { ok: true; value: PlanChange } | { ok: false; fields: string[] } {
  const parsed = PlanChangeSchema.safeParse(input);
  return parsed.success ? { ok: true, value: parsed.data } : { ok: false, fields: parsed.error.issues.map((i) => i.path.join('.')) };
}
