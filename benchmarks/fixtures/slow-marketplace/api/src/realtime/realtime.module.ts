import { Module } from '@nestjs/common';
import { PriceFeed, StockFeed } from './feeds';
import { ProductLiveGateway } from './price.gateway';

@Module({
  providers: [PriceFeed, StockFeed, ProductLiveGateway],
})
export class RealtimeModule {}
