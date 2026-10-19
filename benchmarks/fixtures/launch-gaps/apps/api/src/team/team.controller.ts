import { Body, Controller, Get, Param, Post, Req } from '@nestjs/common';
import { Public } from '../auth/public.decorator';
import { TeamService } from './team.service';

@Controller('team')
export class TeamController {
  constructor(private readonly team: TeamService) {}

  @Get('members')
  members(@Req() req: { user: { tenantId: string } }) {
    return this.team.members(req.user.tenantId);
  }

  @Post('invites')
  invite(@Req() req: { user: { tenantId: string } }, @Body() body: { email: string; role: 'staff' | 'manager' }) {
    return this.team.invite(req.user.tenantId, body);
  }

  @Public()
  @Post('invites/:token/accept')
  accept(@Param('token') token: string) {
    return this.team.acceptInvite(token);
  }
}
