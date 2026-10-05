import { Module } from '@nestjs/common';
import { RefundsModule } from '../refunds/refunds.module';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [RefundsModule],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
