import * as aws from '@pulumi/aws';

// Partner reporting portal's own Postgres (holds the partner statements it publishes monthly).
const statements = new aws.rds.Instance('partner-statements', {
  identifier: 'larder-partner-statements',
  engine: 'postgres',
  engineVersion: '17.6',
  instanceClass: 'db.r7g.large',
  allocatedStorage: 100,
  maxAllocatedStorage: 500,
  manageMasterUserPassword: true,
  username: 'statements_admin',
  backupRetentionPeriod: 14,
  deletionProtection: true,
  skipFinalSnapshot: false,
  finalSnapshotIdentifier: 'larder-partner-statements-final',
}, { protect: false });

export const endpoint = statements.endpoint;
