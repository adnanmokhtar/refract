import { Injectable } from '@nestjs/common';
import { logger } from '../logging/logger';

// Alerts raised by the application itself; the log pipeline turns `alert: true` lines into
// Alertmanager alerts with category="cost" (k8s/monitoring/alertmanager.yaml routes them to #finops).
@Injectable()
export class AlertsService {
  async spendCapReached(dependency: string, cap: number): Promise<void> {
    logger.error('spend cap reached', { alert: true, category: 'cost', dependency, cap });
  }
}
