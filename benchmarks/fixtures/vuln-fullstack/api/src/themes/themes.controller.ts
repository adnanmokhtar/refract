import { Body, Controller, ForbiddenException, Get, Post, Req, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { ThemesService } from './themes.service';

@Controller('themes')
@UseGuards(JwtAuthGuard)
export class ThemesController {
  constructor(private readonly themes: ThemesService) {}

  @Get()
  list(@Req() req: { user: AuthUser }) {
    return this.themes.list(req.user.sub);
  }

  @Post('install')
  install(@Req() req: { user: AuthUser }, @Body() body: { repoUrl: string; ref?: string }) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.themes.installFromGit(req.user.sub, body.repoUrl, body.ref);
  }
}
