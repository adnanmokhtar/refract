import { Controller, Get, Patch } from '@nestjs/common';
import { UpdateAccountBody, type UpdateAccountBodyT } from '@norrow/contracts';
import { type AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Permissions } from '../common/permissions.decorator';
import { ZodBody } from '../common/zod';
import { AccountsService } from './accounts.service';

// No @UseGuards here: the global APP_GUARD (JwtAuthGuard) authenticates every route that is not
// @Public(), which is what V1's auth:sanctum group did for /me.
@Controller()
export class MeController {
  constructor(private readonly accounts: AccountsService) {}

  @Get('me')
  me(@CurrentUser() user: AuthUser) {
    // V1's User::toApi (id, name, email, roles), plus `permissions`, which the SPA's nav reads.
    return { data: { id: user.id, name: user.name, email: user.email, roles: user.roles, permissions: user.permissions } };
  }

  @Patch('account')
  @Permissions('account:update')
  updateAccount(@ZodBody(UpdateAccountBody) body: UpdateAccountBodyT, @CurrentUser() user: AuthUser) {
    return this.accounts.update(user.accountId, body);
  }
}
