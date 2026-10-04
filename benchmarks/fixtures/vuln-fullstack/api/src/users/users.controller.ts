import { Body, Controller, Get, Param, ParseUUIDPipe, Patch, Req, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { UpdateProfileDto } from './update-profile.dto';
import { UsersService } from './users.service';

@Controller('users')
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Get('me')
  @UseGuards(JwtAuthGuard)
  me(@Req() req: { user: AuthUser }) {
    return this.users.me(req.user.sub);
  }

  @Patch('me')
  @UseGuards(JwtAuthGuard)
  update(@Req() req: { user: AuthUser }, @Body() body: UpdateProfileDto) {
    return this.users.updateProfile(req.user.sub, body);
  }

  // Unauthenticated: seller pages are public.
  @Get(':id')
  profile(@Param('id', ParseUUIDPipe) id: string) {
    return this.users.publicProfile(id);
  }
}
