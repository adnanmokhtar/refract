import type { ExtensionSlug } from './modules';

export const PLAN_KEYS = ['starter', 'growth', 'scale'] as const;
export type PlanKey = (typeof PLAN_KEYS)[number];

/** The plan map: the one place a plan becomes the extensions it includes. */
export const PLAN_EXTENSIONS: Record<PlanKey, readonly ExtensionSlug[]> = {
  starter: [],
  growth: ['whatsapp_inbox', 'loyalty_points', 'gift_cards'],
  scale: ['whatsapp_inbox', 'advanced_reports', 'ai_assistant', 'api_access', 'bulk_import', 'loyalty_points', 'gift_cards'],
};
