import { Body, Controller, ForbiddenException, Get, Patch, Post, Put, Req, UseGuards } from '@nestjs/common';
import { AuthUser } from '../auth/auth.dto';
import { JwtAuthGuard } from '../auth/jwt-auth.guard';
import { DiscountRulesService } from '../pricing/discount-rules.service';
import { CustomDomainService } from './custom-domain.service';
import { StoreSettingsService } from './store-settings.service';

@Controller('settings')
@UseGuards(JwtAuthGuard)
export class SettingsController {
  constructor(
    private readonly settings: StoreSettingsService,
    private readonly discounts: DiscountRulesService,
    private readonly domains: CustomDomainService,
  ) {}

  @Get()
  get(@Req() req: { user: AuthUser }) {
    return this.settings.get(req.user.sub);
  }

  @Patch()
  patch(@Req() req: { user: AuthUser }, @Body() body: Record<string, unknown>) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.settings.patch(req.user.sub, body);
  }

  @Post('discount-rules')
  addRule(
    @Req() req: { user: AuthUser },
    @Body() body: { label: string; condition: string; percentOff: number },
  ) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.discounts.createRule(req.user.sub, body.label, body.condition, Number(body.percentOff));
  }

  @Get('domain')
  domain(@Req() req: { user: AuthUser }) {
    return this.domains.get(req.user.sub);
  }

  @Put('domain')
  setDomain(@Req() req: { user: AuthUser }, @Body() body: { hostname: string }) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.domains.setHostname(req.user.sub, String(body.hostname ?? ''));
  }

  @Post('domain/verify')
  verifyDomain(@Req() req: { user: AuthUser }) {
    if (req.user.role !== 'SELLER') throw new ForbiddenException();
    return this.domains.verify(req.user.sub);
  }

  @Get('domain/dns')
  domainDns(@Req() req: { user: AuthUser }) {
    return this.domains.dnsInstructions(req.user.sub);
  }
}
