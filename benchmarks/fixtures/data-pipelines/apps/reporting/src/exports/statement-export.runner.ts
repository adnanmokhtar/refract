import { S3Client, PutObjectCommand } from '@aws-sdk/client-s3';
import type { Knex } from 'knex';
import { renderStatementPdf } from './statement-pdf';

/** Monthly merchant statement: the job row tells the dashboard when the file is ready. */
export class StatementExportRunner {
  constructor(private readonly knex: Knex, private readonly s3: S3Client) {}

  async run(jobId: string, merchantId: string, month: string): Promise<void> {
    const fileUrl = `s3://larkmoor-statements/${merchantId}/${month}.pdf`;
    await this.knex('export_jobs').where({ id: jobId }).update({ status: 'ready', file_url: fileUrl });
    const pdf = await renderStatementPdf(this.knex, merchantId, month);
    await this.s3.send(new PutObjectCommand({ Bucket: 'larkmoor-statements', Key: `${merchantId}/${month}.pdf`, Body: pdf }));
  }
}
