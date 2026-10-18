import { Controller, Get, HttpCode, Param, ParseIntPipe, Post } from '@nestjs/common';
import { AdjustWalletBody, type AdjustWalletBodyT, CreditLimitBody, InstallmentsBody, type InstallmentsBodyT } from '@norrow/contracts';
import { type AuthUser, CurrentUser } from '../common/current-user.decorator';
import { Permissions } from '../common/permissions.decorator';
import { ZodBody } from '../common/zod';
import { splitInstallments } from './installments';
import { WalletsService } from './wallets.service';

@Controller('wallets')
export class WalletsController {
  constructor(private readonly wallets: WalletsService) {}

  @Get(':id')
  @Permissions('wallets:view')
  get(@Param('id', ParseIntPipe) id: number) {
    return this.wallets.get(id);
  }

  @Get(':id/statement')
  @Permissions('wallets:view')
  statement(@Param('id', ParseIntPipe) id: number) {
    return this.wallets.statement(id);
  }

  @Post(':id/adjust')
  @HttpCode(201)
  adjust(@Param('id', ParseIntPipe) id: number, @ZodBody(AdjustWalletBody) body: AdjustWalletBodyT, @CurrentUser() user: AuthUser) {
    return this.wallets.adjust(id, body, user);
  }

  @Post(':id/installments')
  @Permissions('wallets:view')
  @HttpCode(200)
  installments(@ZodBody(InstallmentsBody) body: InstallmentsBodyT) {
    return { data: splitInstallments(body.total, body.count) };
  }

  @Post(':id/credit-limit')
  @Permissions('wallets:adjust')
  @HttpCode(200)
  creditLimit(@Param('id', ParseIntPipe) id: number, @ZodBody(CreditLimitBody) body: { credit_limit_minor: number }) {
    return this.wallets.setCreditLimit(id, body.credit_limit_minor);
  }
}
