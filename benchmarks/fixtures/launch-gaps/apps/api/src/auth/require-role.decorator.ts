import { SetMetadata } from '@nestjs/common';

export const REQUIRED_ROLE = 'required_role';
export const RequireRole = (role: 'platform-admin' | 'owner' | 'manager') => SetMetadata(REQUIRED_ROLE, role);
