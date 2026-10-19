import { Injectable } from '@nestjs/common';
import { PutObjectCommand } from '@aws-sdk/client-s3';
import { AppConfig } from '../config/app-config';
import { bucketFor, s3ClientFor } from '../storage/object-store';

/**
 * Proof-of-delivery photos sent by couriers. They are the merchant's evidence in carrier claims and are
 * kept for the life of the merchant account (docs/compliance/retention.md).
 */
@Injectable()
export class PodPhotosService {
  private readonly s3 = s3ClientFor(this.config);

  constructor(private readonly config: AppConfig) {}

  keyFor(shipmentId: string, photoId: string): string {
    return `pod/${shipmentId}/${photoId}.jpg`;
  }

  async store(shipmentId: string, photoId: string, jpeg: Buffer): Promise<string> {
    const key = this.keyFor(shipmentId, photoId);
    await this.s3.send(new PutObjectCommand({ Bucket: bucketFor(this.config, 'podPhotos'), Key: key, Body: jpeg, ContentType: 'image/jpeg' }));
    return key;
  }

  /** Thumbnail URL for the public tracking page. */
  publicUrl(key: string): string {
    return `${this.config.publicMediaBaseUrl}/${key}`;
  }
}
