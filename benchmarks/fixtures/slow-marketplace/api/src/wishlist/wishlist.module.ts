import { Module } from '@nestjs/common';
import { WishlistService } from './wishlist.service';

@Module({
  providers: [WishlistService],
  exports: [WishlistService],
})
export class WishlistModule {}
