import { Injectable } from '@nestjs/common';
import { createHmac } from 'node:crypto';
import { env } from './env';

// Object storage (S3-compatible). Signed GET links for invoices and exports.
@Injectable()
export class StorageService {
  private readonly bucketUrl = env('STORAGE_BUCKET_URL');

  async signedUrl(key: string, opts: { expiresInSeconds: number }): Promise<string> {
    const expires = Math.floor(Date.now() / 1000) + opts.expiresInSeconds;
    const signature = createHmac('sha256', env('STORAGE_SIGNING_KEY')).update(`${key}:${expires}`).digest('hex');
    return `${this.bucketUrl}/${encodeURIComponent(key)}?expires=${expires}&sig=${signature}`;
  }
}
