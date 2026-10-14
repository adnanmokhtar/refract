import { Injectable } from '@nestjs/common';
import { Readable } from 'node:stream';
import {
  CompleteMultipartUploadCommand,
  CreateMultipartUploadCommand,
  S3Client,
  UploadPartCommand,
} from '@aws-sdk/client-s3';

@Injectable()
export class StorageService {
  private readonly s3 = new S3Client({});
  private readonly bucket = 'lumen-docs';

  async put(key: string, body: Readable): Promise<string> {
    const { UploadId } = await this.s3.send(new CreateMultipartUploadCommand({ Bucket: this.bucket, Key: key }));
    const parts: { ETag?: string; PartNumber: number }[] = [];
    try {
      let n = 1;
      for await (const chunk of body) {
        const { ETag } = await this.s3.send(new UploadPartCommand({ Bucket: this.bucket, Key: key, UploadId, PartNumber: n, Body: chunk }));
        parts.push({ ETag, PartNumber: n++ });
      }
    } finally {
      await this.s3.send(new CompleteMultipartUploadCommand({ Bucket: this.bucket, Key: key, UploadId, MultipartUpload: { Parts: parts } }));
    }
    return key;
  }
}
