import { Module, Type } from '@nestjs/common';
import { globSync } from 'glob';
import { join } from 'node:path';

// Every *.job.ts in this folder is a scheduled job; they are discovered, never imported by name.
const jobProviders: Type[] = globSync(join(__dirname, '*.job.{ts,js}')).map(
  // eslint-disable-next-line @typescript-eslint/no-require-imports -- dynamic discovery of job classes by file pattern
  (file) => Object.values(require(file))[0] as Type,
);

@Module({ providers: jobProviders })
export class JobsModule {}
