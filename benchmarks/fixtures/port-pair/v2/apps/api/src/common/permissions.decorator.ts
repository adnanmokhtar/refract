import { SetMetadata } from '@nestjs/common';

export const PERMISSIONS = 'permissions';
// V1 spatie names use dots (`orders.view`); V2 uses colons (`orders:view`). pair-map.tsv folds them.
export const Permissions = (...permissions: string[]) => SetMetadata(PERMISSIONS, permissions);
