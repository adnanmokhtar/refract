import { Module } from '@nestjs/common';
import { CheckoutController } from './checkout.controller';
import { CheckoutService } from './checkout.service';
import { LedgerClient } from './ledger.client';

@Module({ controllers: [CheckoutController], providers: [CheckoutService, LedgerClient] })
export class CheckoutModule {}
