import { Body, Controller, ForbiddenException, Post, Req, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { EmailTemplatesService, TemplateDraft } from './email-templates.service';

@Controller('email-templates')
@UseGuards(JwtAuthGuard)
export class EmailTemplatesController {
  constructor(private readonly templates: EmailTemplatesService) {}

  @Post('preview')
  preview(@Req() req: { user: AuthUser }, @Body() body: TemplateDraft) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.templates.preview(req.user.sub, body);
  }

  @Post()
  save(@Req() req: { user: AuthUser }, @Body() body: TemplateDraft) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.templates.save(req.user.sub, body);
  }
}
