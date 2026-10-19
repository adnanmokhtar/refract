import { BadRequestException } from '@nestjs/common';

/**
 * The route planner shows how many ways a batch can be split into legs of one or two stops
 * ("34 possible plans"), so the dispatcher sees how much room the optimiser has.
 */
const legPlans = (n: number): number => (n < 2 ? 1 : legPlans(n - 1) + legPlans(n - 2));

export interface PlanSummary {
  stops: number;
  possiblePlans: number;
}

export function summarisePlan(stopIds: string[]): PlanSummary {
  if (stopIds.length === 0) {
    throw new BadRequestException('a plan needs at least one stop');
  }
  return { stops: stopIds.length, possiblePlans: legPlans(stopIds.length) };
}
