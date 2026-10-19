import { Injectable } from '@nestjs/common';
import { PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { AppConfig } from '../config/app-config';

// Every rendered label is archived for carrier audits (merchant agreement § 9: labels are the merchant's record).
@Injectable()
export class LabelArchiveClient {
  private readonly s3 = new S3Client({ region: 'us-east-1' });

  constructor(private readonly config: AppConfig) {}

  async archive(shipmentId: string, trackingNumber: string, pdf: Buffer): Promise<string> {
    const key = `labels/${trackingNumber.slice(0, 4)}/${trackingNumber}-${shipmentId}.pdf`;
    await this.s3.send(new PutObjectCommand({
      Bucket: this.config.labelArchiveBucket,
      Key: key,
      Body: pdf,
      ContentType: 'application/pdf',
    }));
    return key;
  }
}
