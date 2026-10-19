import { S3Client } from '@aws-sdk/client-s3';
import { AppConfig } from '../config/app-config';

// The object areas the API writes. Bucket names come from the environment; prefixes are fixed here.
export const AREAS = {
  exports: { bucket: 'exportsBucket', prefix: 'exports/' },
  tmpUploads: { bucket: 'exportsBucket', prefix: 'tmp-uploads/' },
  imports: { bucket: 'importsBucket', prefix: 'imports/' },
  podPhotos: { bucket: 'mediaBucket', prefix: 'pod/' },
} as const;

export type Area = keyof typeof AREAS;

export function bucketFor(config: AppConfig, area: Area): string {
  return config[AREAS[area].bucket];
}

export function s3ClientFor(config: AppConfig): S3Client {
  return new S3Client({
    region: config.region,
    endpoint: config.s3Endpoint,
    forcePathStyle: Boolean(config.s3Endpoint),
  });
}
