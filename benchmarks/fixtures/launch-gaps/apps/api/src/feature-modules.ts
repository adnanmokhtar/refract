import { Module } from '@nestjs/common';
import { OrdersController } from './orders/orders.controller';
import { StoresController } from './stores/stores.controller';
import { StoresService } from './stores/stores.service';
import { ReportsController } from './reports/reports.controller';
import { ExportsController } from './exports/exports.controller';
import { InsightsController } from './insights/insights.controller';
import { InsightsService } from './insights/insights.service';
import { AssistantController } from './assistant/assistant.controller';
import { ApiKeysController } from './api-keys/api-keys.controller';
import { ImportsController } from './imports/imports.controller';
import { LoyaltyController } from './loyalty/loyalty.controller';
import { GiftCardsController } from './gift-cards/gift-cards.controller';
import { GiftCardsService } from './gift-cards/gift-cards.service';
import { InboxController } from './inbox/inbox.controller';
import { BillingController } from './billing/billing.controller';
import { BillingService } from './billing/billing.service';
import { EntitlementSyncService } from './billing/entitlement-sync.service';
import { WebhooksController } from './webhooks/webhooks.controller';
import { HealthController } from './health/health.controller';
import { PublicCatalogController } from './public/public-catalog.controller';
import { ReferralsController } from './referrals/referrals.controller';
import { ReferralsService } from './referrals/referrals.service';
import { TeamController } from './team/team.controller';
import { TeamService } from './team/team.service';
import { AdminJobsController } from './admin/admin-jobs.controller';
import { EventsController } from './events/events.controller';
import { CapiService } from './events/capi';
import { QuotaService } from './usage/quota.service';
import { PosthogProvider } from './analytics/posthog.provider';

@Module({
  controllers: [
    OrdersController, StoresController, ReportsController, ExportsController, InsightsController, AssistantController,
    ApiKeysController, ImportsController, LoyaltyController, GiftCardsController, InboxController, BillingController,
    WebhooksController, HealthController, PublicCatalogController, ReferralsController, TeamController,
    AdminJobsController, EventsController,
  ],
  providers: [
    StoresService, InsightsService, GiftCardsService, BillingService, EntitlementSyncService, ReferralsService,
    TeamService, CapiService, QuotaService, PosthogProvider,
  ],
})
class FeaturesModule {}

export const FeatureModules = [FeaturesModule];
