import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { QuotasService } from './quotas.service';

/** Counts every partner API call against the merchant's monthly quota. */
@Injectable()
export class QuotaGuard implements CanActivate {
  constructor(private readonly quotas: QuotasService) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<{ principal?: { tenantId: string } }>();
    if (req.principal) await this.quotas.consume(req.principal.tenantId);
    return true;
  }
}
