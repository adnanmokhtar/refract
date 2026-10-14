import { Body, Controller, Post, UseInterceptors } from '@nestjs/common';
import { IsString, MaxLength } from 'class-validator';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { Idempotent, IdempotencyInterceptor } from '../common/idempotency/idempotency.interceptor';

export class OpenSupportTicketDto {
  @IsString()
  @MaxLength(120)
  subject!: string;

  @IsString()
  @MaxLength(5000)
  body!: string;
}

@Controller('support-tickets')
@UseInterceptors(IdempotencyInterceptor)
export class SupportTicketsController {
  @Post()
  @Idempotent()
  async open(@CurrentUser() user: Principal, @Body() dto: OpenSupportTicketDto): Promise<{ id: string; subject: string }> {
    return { id: `${user.tenantId}-${Date.now()}`, subject: dto.subject };
  }
}
