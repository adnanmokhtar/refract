import { Module } from '@nestjs/common';
import { HomeFeedService } from './home-feed.service';
import { RecommendationsClient } from './recommendations.client';

@Module({
  providers: [HomeFeedService, RecommendationsClient],
})
export class StorefrontModule {}
