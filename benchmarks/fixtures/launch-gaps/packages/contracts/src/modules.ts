/**
 * Coarse modules. Every tenant has one row per key in tenant_modules, switched on or off by an
 * admin; ModuleEntitlementGuard judges these keys.
 */
export const MODULE_KEYS = ['inventory', 'orders', 'reports', 'team'] as const;
export type ModuleKey = (typeof MODULE_KEYS)[number];

/**
 * Purchasable extensions, billed per tenant on top of the plan. ExtensionModuleGuard judges these
 * slugs against the tenant's active subscription items.
 */
export const EXTENSION_SLUGS = [
  'whatsapp_inbox',
  'advanced_reports',
  'ai_assistant',
  'api_access',
  'bulk_import',
  'loyalty_points',
  'gift_cards',
] as const;
export type ExtensionSlug = (typeof EXTENSION_SLUGS)[number];
