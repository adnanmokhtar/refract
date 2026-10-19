import { Body, Controller, Get, GoneException, Param, Post } from '@nestjs/common';
import { InvitesService } from './invites.service';

@Controller('team/invites')
export class InvitesController {
  constructor(private readonly invites: InvitesService) {}

  @Get()
  list() {
    return this.invites.pending();
  }

  @Post()
  create(@Body() dto: { email: string; role: 'admin' | 'staff' }) {
    return this.invites.invite(dto.email, dto.role);
  }

  @Post(':token/accept')
  async accept(@Param('token') token: string) {
    const invite = await this.invites.byToken(token);
    if (!invite) throw new GoneException('This invite is no longer valid');
    return this.invites.accept(invite);
  }
}
