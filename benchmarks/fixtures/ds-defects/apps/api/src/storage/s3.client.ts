import { Injectable } from '@nestjs/common';
import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';

/** Label and manifest PDFs. The SDK's standard retry mode classifies throttling and transient errors itself. */
@Injectable()
export class LabelStore {
  private readonly s3 = new S3Client({ region: process.env.AWS_REGION, retryMode: 'standard', maxAttempts: 3 });

  async put(key: string, pdf: Buffer): Promise<void> {
    await this.s3.send(new PutObjectCommand({ Bucket: process.env.LABELS_BUCKET, Key: key, Body: pdf, ContentType: 'application/pdf' }));
  }

  async get(key: string): Promise<Uint8Array | undefined> {
    const out = await this.s3.send(new GetObjectCommand({ Bucket: process.env.LABELS_BUCKET, Key: key }));
    return out.Body?.transformToByteArray();
  }
}
