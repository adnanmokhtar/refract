import { describe } from 'vitest';

// The parity suites drive the pinned V1 checkout (php artisan serve on a scratch copy) and
// compare its answers with V2's. Without V1_REPO_PATH there is nothing to compare against.
export const V1_REPO_PATH = process.env.V1_REPO_PATH;
export const HAS_V1 = Boolean(V1_REPO_PATH);

export const describeV1 = HAS_V1 ? describe : describe.skip;
