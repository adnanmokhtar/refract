import { Injectable } from '@nestjs/common';
import { DeleteObjectCommand } from '@aws-sdk/client-s3';
import { Upload } from '@aws-sdk/lib-storage';
import { randomUUID } from 'node:crypto';
import type { Readable } from 'node:stream';
import { AppConfig } from '../config/app-config';
import { bucketFor, s3ClientFor } from '../storage/object-store';
import { ImportQueue } from './import-queue';

/**
 * Merchants upload shipment CSVs of up to 2 GB from their ERP. The stream goes to S3 in 8 MB parts,
 * the importer reads it from there and deletes the object when the import finishes.
 */
@Injectable()
export class BulkImportService {
  private readonly s3 = s3ClientFor(this.config);

  constructor(private readonly config: AppConfig, private readonly importQueue: ImportQueue) {}

  async accept(tenantId: string, stream: Readable): Promise<string> {
    const key = `imports/${tenantId}/${randomUUID()}.csv`;
    const upload = new Upload({
      client: this.s3,
      params: { Bucket: bucketFor(this.config, 'imports'), Key: key, Body: stream, ContentType: 'text/csv' },
      partSize: 8 * 1024 * 1024,
      queueSize: 4,
    });
    await upload.done();
    await this.importQueue.enqueue(tenantId, key);
    return key;
  }

  async finished(key: string): Promise<void> {
    await this.s3.send(new DeleteObjectCommand({ Bucket: bucketFor(this.config, 'imports'), Key: key }));
  }
}
