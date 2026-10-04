import { Module } from '@nestjs/common';
import { SearchIndexClient } from '../search/search-index.client';
import { StoreMembersService } from './store-members.service';
import { StoreOnboardingService } from './store-onboarding.service';
import { StoreSettingsService } from './store-settings.service';
import { StoreStaffGuard } from './store-staff.guard';

@Module({
  providers: [StoreMembersService, StoreOnboardingService, StoreSettingsService, StoreStaffGuard, SearchIndexClient],
  exports: [StoreStaffGuard],
})
export class StoresModule {}
