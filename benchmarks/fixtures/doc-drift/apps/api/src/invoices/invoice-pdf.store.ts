import { GetObjectCommand, PutObjectCommand, S3Client } from '@aws-sdk/client-s3';
import { Injectable } from '@nestjs/common';

import { loadConfig } from '../config/config.loader';

// The S3 client uses the default credential chain: the pod's role in the cluster,
// the AWS SDK's own variables on a workstation. Nothing here reads them directly.
const s3 = new S3Client({});

@Injectable()
export class InvoicePdfStore {
  private readonly bucket = loadConfig().INVOICE_BUCKET;

  async write(id: string, body: Uint8Array): Promise<void> {
    await s3.send(new PutObjectCommand({ Bucket: this.bucket, Key: `invoices/${id}.pdf`, Body: body }));
  }

  async read(id: string) {
    const out = await s3.send(new GetObjectCommand({ Bucket: this.bucket, Key: `invoices/${id}.pdf` }));
    return out.Body;
  }
}
