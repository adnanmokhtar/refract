import { Injectable } from '@nestjs/common';
import { AppConfig } from '../config/app-config';

export interface RenderRequest {
  shipmentId: string;
  format: 'pdf-a6' | 'zpl';
  carrierLabelUrl: string;
}

/** Re-brands the carrier's label with the merchant's logo (label-renderer service, port 8080). */
@Injectable()
export class LabelRendererClient {
  constructor(private readonly config: AppConfig) {}

  async render(req: RenderRequest): Promise<Buffer> {
    const res = await fetch(this.config.labelRendererUrl, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(req),
      signal: AbortSignal.timeout(15_000),
    });
    if (!res.ok) {
      throw new Error(`label renderer ${res.status}`);
    }
    return Buffer.from(await res.arrayBuffer());
  }
}
