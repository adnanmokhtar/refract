import { SetMetadata } from '@nestjs/common';

export const MERCHANT_CRON_METADATA = 'acme:merchant-cron';
export const MerchantCron = (expression: string): MethodDecorator => SetMetadata(MERCHANT_CRON_METADATA, expression);
