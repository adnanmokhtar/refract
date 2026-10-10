import { Stack, StackProps, Duration } from 'aws-cdk-lib';
import * as s3 from 'aws-cdk-lib/aws-s3';
import { Construct } from 'constructs';

// Monthly ledger exports, one archive bucket per region the finance team reports on.
const ARCHIVE_REGIONS = ['eu-central-1', 'eu-west-1', 'eu-north-1'];

export class LedgerArchiveStack extends Stack {
  constructor(scope: Construct, id: string, props?: StackProps) {
    super(scope, id, props);

    ARCHIVE_REGIONS.forEach((region, i) => {
      new s3.Bucket(this, `ArchiveBucket${i}`, {
        bucketName: `larder-ledger-archive-${region}`,
        versioned: true,
        lifecycleRules: [{ noncurrentVersionExpiration: Duration.days(365) }],
      });
    });
  }
}
