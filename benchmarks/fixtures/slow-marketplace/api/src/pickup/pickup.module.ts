import { Module } from '@nestjs/common';
import { PickupSlotsService } from './pickup-slots.service';

@Module({
  providers: [PickupSlotsService],
  exports: [PickupSlotsService],
})
export class PickupModule {}
