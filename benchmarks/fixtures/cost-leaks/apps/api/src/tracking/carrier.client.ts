import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';
import { carrierCalls } from '../metrics/metrics';
import { SpendGuard } from '../spend/spend-guard';

export interface CarrierScan {
  trackingNumber: string;
  code: string;
  occurredAt: string;
  raw: Record<string, unknown>;
}

export interface LabelJob {
  status: 'queued' | 'rendering' | 'done' | 'failed';
  result?: { pdfUrl: string; trackingNumber: string };
  error?: string;
}

/**
 * ParcelNet REST API (CARRIER_API_BASE_URL). Every request is billed, including tracking reads.
 * ParcelNet can also push scans to us (POST /v1/subscriptions); we have not subscribed yet.
 */
@Injectable()
export class CarrierClient {
  constructor(private readonly config: AppConfig, private readonly guard: SpendGuard) {}

  async trackBatch(trackingNumbers: string[]): Promise<CarrierScan[]> {
    return this.call('track', `/v1/tracking?numbers=${trackingNumbers.join(',')}`);
  }

  async createLabelJob(shipmentId: string, service: string): Promise<string> {
    const job = await this.call<{ id: string }>('label-create', '/v1/labels/jobs', { reference: shipmentId, service });
    return job.id;
  }

  async getLabelJob(jobId: string): Promise<LabelJob> {
    return this.call('label-job', `/v1/labels/jobs/${encodeURIComponent(jobId)}`);
  }

  private async call<T>(endpoint: string, path: string, body?: unknown): Promise<T> {
    await this.guard.reserve('carrier');
    const res = await fetch(`${this.config.carrierApiBaseUrl}${path}`, {
      method: body ? 'POST' : 'GET',
      headers: { 'x-api-key': this.config.carrierApiKey, 'content-type': 'application/json' },
      body: body ? JSON.stringify(body) : undefined,
      signal: AbortSignal.timeout(10_000),
    });
    carrierCalls.inc({ endpoint, outcome: res.ok ? 'ok' : String(res.status) });
    if (!res.ok) {
      throw new Error(`carrier ${endpoint} ${res.status}`);
    }
    return (await res.json()) as T;
  }
}
