import { Injectable } from '@nestjs/common';
import { MerchantCron } from './merchant-cron.decorator';
import { RequestExport } from '../exports/request-export.usecase';

@Injectable()
export class MerchantExportsSchedule {
  constructor(private readonly exportsUseCase: RequestExport) {}

  /** Nightly shipment export for every merchant with exports enabled. */
  @MerchantCron('0 0 1 * * *')
  async nightlyShipmentExports(): Promise<void> {
    await this.exportsUseCase.execute('*', 'shipments');
  }
}
