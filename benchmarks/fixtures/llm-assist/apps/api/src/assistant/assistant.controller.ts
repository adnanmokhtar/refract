import { Body, Controller, Param, Post, Req } from '@nestjs/common';
import { randomUUID } from 'node:crypto';
import { AuthedRequest } from '../common/authed-request';
import { AssistantUseCase } from './assistant.use-case';
import { PromptGuard } from './guard';

class TurnDto {
  text!: string;
  mode?: 'full' | 'read_only';
}

@Controller('conversations')
export class AssistantController {
  constructor(
    private readonly assistant: AssistantUseCase,
    private readonly guard: PromptGuard,
  ) {}

  @Post(':conversationId/turns')
  async turn(@Param('conversationId') conversationId: string, @Body() body: TurnDto, @Req() req: AuthedRequest) {
    await this.guard.screen(body.text);
    const answer = await this.assistant.turn(
      {
        accountId: req.user.accountId,
        tenantId: req.user.tenantId,
        conversationId,
        turnId: randomUUID(),
        text: body.text,
        mode: body.mode ?? 'full',
      },
      req.deadline,
    );
    return { answer };
  }
}
