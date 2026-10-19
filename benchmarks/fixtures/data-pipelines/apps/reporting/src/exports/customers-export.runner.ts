import type { Knex } from 'knex';
import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import { stringify } from 'csv-stringify/sync';

const PAGE = 1000;

/** Nightly customer list for the merchant, written to the partner-exports bucket. */
export class CustomersExportRunner {
  constructor(private readonly knex: Knex, private readonly s3: S3Client) {}

  async run(merchantId: string): Promise<string> {
    const rows: Record<string, unknown>[] = [];
    for (let offset = 0; ; offset += PAGE) {
      const page = await this.knex('customers')
        .where({ merchant_id: merchantId })
        .orderBy('created_at', 'desc')
        .offset(offset)
        .limit(PAGE);
      rows.push(...page);
      if (page.length < PAGE) break;
    }
    const key = `customers/${merchantId}/${Date.now()}.csv`;
    await this.s3.send(new PutObjectCommand({ Bucket: 'larkmoor-partner-exports', Key: key, Body: stringify(rows, { header: true }) }));
    return key;
  }
}
