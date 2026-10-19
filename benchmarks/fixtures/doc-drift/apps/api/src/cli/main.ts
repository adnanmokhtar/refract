#!/usr/bin/env node
import { buildCli } from './args';

buildCli().parseAsync(process.argv).catch((error: unknown) => {
  console.error(error);
  process.exitCode = 1;
});
