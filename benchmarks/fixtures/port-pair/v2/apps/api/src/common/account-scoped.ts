import { Filter } from '@mikro-orm/core';

// The V2 side of V1's AccountScope global scope: every query on a decorated entity carries
// `account_id = :accountId`, set per request by JwtAuthGuard. Raw SQL does not pass through it.
export const AccountScoped = () =>
  Filter({ name: 'account', cond: ({ accountId }: { accountId: number }) => ({ account: accountId }), default: true });

// The V2 side of V1's SoftDeletes trait: rows with deleted_at set are invisible by default.
export const SoftDeletable = () => Filter({ name: 'live', cond: { deletedAt: null }, default: true });
