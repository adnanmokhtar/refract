import { Controller, HttpCode, Post } from '@nestjs/common';
import { z } from 'zod';
import { ZodBody } from '../common/zod-body.decorator';
import { CurrentUser, Principal } from '../common/current-user.decorator';
import { PostTransferUseCase } from '../ledger/post-transfer.use-case';

export const createTransferSchema = z
  .object({
    fromAccount: z.uuid(),
    toAccount: z.uuid(),
    amount: z.string().regex(/^\d{1,12}\.\d{2}$/),
    currency: z.string().length(3),
  })
  .strict();
export type CreateTransfer = z.infer<typeof createTransferSchema>;

@Controller('transfers')
export class TransfersController {
  constructor(private readonly postTransfer: PostTransferUseCase) {}

  @Post()
  @HttpCode(201)
  async create(@CurrentUser() user: Principal, @ZodBody(createTransferSchema) dto: CreateTransfer): Promise<{ ok: true }> {
    await this.postTransfer.execute(dto.fromAccount, dto.toAccount, dto.amount);
    return { ok: true };
  }
}
